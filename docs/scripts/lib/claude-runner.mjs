/**
 * Runs `claude -p` calls concurrently, with retries, and records what each one
 * cost. This is the piece that turns a 23-minute serial AI step into a bounded,
 * observable, parallel one.
 *
 * Three things it fixes about the previous spawnSync loop:
 *
 *  1. CONCURRENCY. spawnSync blocks the event loop, so batches could only ever run
 *     one at a time — wall clock was the SUM of every call. Here calls run through
 *     a bounded pool and wall clock approaches the slowest single call.
 *
 *  2. CACHE WARMING. Anthropic's caching docs are explicit that a cache entry only
 *     becomes available once the first response has begun, so firing N cold calls
 *     simultaneously guarantees N cache misses. The pool therefore runs the first
 *     call alone, then fans out.
 *
 *  3. OBSERVABILITY. --output-format json makes the CLI emit a result envelope with
 *     usage, cost and duration, so every call can be reported instead of vanishing
 *     into an inherited stdout.
 */
import { spawn } from 'node:child_process';

/** Tools the authoring agents may use. No Bash and no network — the context pack
 *  already answers the questions that previously drove shell-outs. */
export const DOC_TOOLS = ['Read', 'Write', 'Edit', 'Grep', 'Glob'];

/** Which binary to invoke. Overridable so a CI image can pin an absolute path, and
 *  so the pipeline's own tests can point at a stub instead of burning real calls. */
export const CLAUDE_BIN = process.env.CLAUDE_CLI_BIN || 'claude';

const RETRYABLE = /rate.?limit|429|overloaded|529|timed? ?out|ECONNRESET|socket hang up|fetch failed/i;

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

/**
 * Total token usage for a call.
 *
 * Prefer the per-model breakdown: an observed run returned all zeros in the
 * top-level `usage` object while `modelUsage` carried the real figures (a call can
 * also span two models when a fallback or a sub-model kicks in, and only
 * `modelUsage` shows that). Fall back to `usage` when the breakdown is absent.
 */
function sumUsage(envelope) {
  const total = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
  const perModel = envelope.modelUsage || {};
  const models = Object.keys(perModel);
  if (models.length) {
    for (const m of models) {
      const u = perModel[m] || {};
      total.input += u.inputTokens || 0;
      total.output += u.outputTokens || 0;
      total.cacheRead += u.cacheReadInputTokens || 0;
      total.cacheWrite += u.cacheCreationInputTokens || 0;
    }
    return total;
  }
  const u = envelope.usage || {};
  return {
    input: u.input_tokens || 0,
    output: u.output_tokens || 0,
    cacheRead: u.cache_read_input_tokens || 0,
    cacheWrite: u.cache_creation_input_tokens || 0,
  };
}

/**
 * Invoke the CLI once and parse its JSON result envelope.
 *
 * `timeoutMs` is a hard wall-clock stop. The CLI has no --max-turns in 2.1.x, so
 * without this a single pathological call could stall the whole workflow; the run
 * we diagnosed had one batch burn 12.7 minutes.
 */
export function runClaude(prompt, opts = {}) {
  const {
    cwd,
    model,
    allowedTools = DOC_TOOLS,
    timeoutMs = 10 * 60 * 1000,
    maxBudgetUsd,
    fallbackModel,
    env = process.env,
  } = opts;

  // The prompt goes in on STDIN, not argv. A context pack for a large feature can
  // run to tens of KB, and argv has hard ceilings that would truncate or fail it —
  // ~128 KB per argument on Linux, and a 32 KB total command line on Windows (8 KB
  // if it goes through cmd.exe). Stdin has no such limit and needs no quoting.
  const args = [
    '-p',
    '--output-format', 'json',
    '--allowedTools', allowedTools.join(','),
    // Grep and Glob are in the allowlist (see DOC_TOOLS) specifically because the
    // previous run's agent kept reaching for search tools that were NOT allowed and
    // burned turns on refusals — one call concluded "this seems to be a permission
    // gate rather than a transient issue" and gave up mid-task. Bash and the network
    // tools stay denied: the context pack already answers what the agent used to
    // shell out for, and this keeps the blast radius small without needing
    // --dangerously-skip-permissions.
    '--disallowedTools', 'Bash,WebFetch,WebSearch,Task,NotebookEdit',
    '--permission-mode', 'acceptEdits',
    // Keeps per-machine details (cwd, git status, env) out of the system prompt so
    // separate CLI processes share one cacheable prefix. Without this, each call's
    // prefix differs — the git snapshot changes as earlier calls write files — and
    // every invocation pays full price for the same preamble.
    '--exclude-dynamic-system-prompt-sections',
    '--strict-mcp-config', // don't load user/project MCP servers in CI
  ];
  if (model) args.push('--model', model);
  if (fallbackModel) args.push('--fallback-model', fallbackModel);
  if (maxBudgetUsd) args.push('--max-budget-usd', String(maxBudgetUsd));

  return new Promise((resolve) => {
    const started = Date.now();
    let stdout = '';
    let stderr = '';
    let timedOut = false;

    // shell:true only on Windows, where `claude` is a .cmd shim that spawn cannot
    // launch directly. Safe now that the prompt is on stdin — the argv here is just
    // short flags.
    const child = spawn(CLAUDE_BIN, args, { cwd, env, stdio: ['pipe', 'pipe', 'pipe'], shell: process.platform === 'win32' });
    const timer = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, timeoutMs);

    child.stdin.on('error', () => { /* the close handler reports the real failure */ });
    child.stdin.end(prompt);

    child.stdout.on('data', (d) => { stdout += d.toString(); });
    child.stderr.on('data', (d) => { stderr += d.toString(); });
    child.on('error', (err) => {
      clearTimeout(timer);
      resolve({ ok: false, error: `failed to launch claude: ${err.message}`, durationMs: Date.now() - started });
    });
    child.on('close', (code) => {
      clearTimeout(timer);
      const durationMs = Date.now() - started;
      if (timedOut) {
        return resolve({ ok: false, error: `timed out after ${Math.round(timeoutMs / 1000)}s`, durationMs, stderr });
      }
      let envelope = null;
      try { envelope = JSON.parse(stdout); } catch (e) { /* non-JSON output below */ }
      if (!envelope) {
        return resolve({
          ok: false,
          error: code === 0 ? 'claude produced no parseable JSON result' : `claude exited ${code}`,
          durationMs,
          stderr: stderr.slice(-2000),
          stdout: stdout.slice(-2000),
        });
      }
      resolve({
        ok: code === 0 && !envelope.is_error,
        error: envelope.is_error
          ? (Array.isArray(envelope.errors) && envelope.errors.length ? envelope.errors.join('; ')
            : envelope.subtype || envelope.result || 'reported is_error')
          : null,
        text: typeof envelope.result === 'string' ? envelope.result : '',
        durationMs: envelope.duration_ms || durationMs,
        turns: envelope.num_turns ?? null,
        costUsd: envelope.total_cost_usd ?? null,
        sessionId: envelope.session_id || null,
        model: Object.keys(envelope.modelUsage || {}).join(', ') || model || null,
        usage: sumUsage(envelope),
        // A non-empty list here means the agent asked for a tool the allowlist
        // refused. That is exactly what stalled the 60-file call in the run we
        // diagnosed, so it is worth surfacing rather than discovering by reading
        // transcripts.
        permissionDenials: (envelope.permission_denials || []).length,
        stderr: stderr.slice(-2000),
      });
    });
  });
}

/** runClaude plus jittered exponential backoff on transient/rate-limit failures. */
export async function runClaudeWithRetry(prompt, opts = {}, { retries = 2, onRetry } = {}) {
  let last;
  for (let attempt = 0; attempt <= retries; attempt++) {
    last = await runClaude(prompt, opts);
    if (last.ok) return { ...last, attempts: attempt + 1 };
    const transient = RETRYABLE.test(`${last.error || ''} ${last.stderr || ''}`);
    if (!transient || attempt === retries) break;
    const backoff = Math.round((2 ** attempt) * 4000 * (0.7 + Math.random() * 0.6));
    if (onRetry) onRetry(attempt + 1, backoff, last.error);
    await sleep(backoff);
  }
  return { ...last, attempts: retries + 1 };
}

/**
 * Bounded-concurrency map that runs the FIRST task alone before fanning out.
 *
 * The warm-up is not politeness: a cache entry is only usable after the first
 * response starts, so launching the whole fleet cold means every worker pays the
 * full uncached preamble. One serial call first lets the rest read that cache.
 */
export async function pool(items, worker, { concurrency = 4, warmFirst = true, onProgress } = {}) {
  const results = new Array(items.length);
  let cursor = 0;
  let done = 0;

  const runOne = async (i) => {
    results[i] = await worker(items[i], i);
    done++;
    if (onProgress) onProgress(done, items.length, results[i], items[i]);
  };

  if (warmFirst && items.length > 1) {
    cursor = 1;
    await runOne(0);
  }

  const runners = Array.from({ length: Math.max(1, Math.min(concurrency, items.length - cursor)) }, async () => {
    while (true) {
      const i = cursor++;
      if (i >= items.length) return;
      await runOne(i);
    }
  });
  await Promise.all(runners);
  return results;
}

/** Pull the first fenced JSON block (or the whole string) out of a model reply. */
export function extractJson(text) {
  if (!text) return null;
  const fenced = text.match(/```(?:json)?\s*\n([\s\S]*?)```/);
  const candidates = [];
  if (fenced) candidates.push(fenced[1]);
  const braced = text.match(/\{[\s\S]*\}/);
  if (braced) candidates.push(braced[0]);
  candidates.push(text);
  for (const c of candidates) {
    try { return JSON.parse(c.trim()); } catch (e) { /* try the next shape */ }
  }
  return null;
}
