#!/usr/bin/env node
/**
 * The one genuinely-AI step in this pipeline. Everything else in docs/scripts is
 * deterministic (regex/graph over force-app); this script is the only place an LLM
 * writes prose, and it is scoped to touch nothing but docs/business/**.
 *
 * Auth: uses a Claude Pro/Max subscription via CLAUDE_CODE_OAUTH_TOKEN (generated
 * once with `claude setup-token`), NOT a pay-per-token ANTHROPIC_API_KEY.
 *
 * ---------------------------------------------------------------------------
 * ARCHITECTURE — why it is shaped like this
 * ---------------------------------------------------------------------------
 * The first real run took 23 minutes for 85 components, and the log showed the
 * shape of the problem precisely: the step was one sequential loop of six calls,
 * one call handled 60 files and took 12.7 minutes on its own (55% of the run), and
 * every call re-derived facts the pipeline had already computed. Nothing else in
 * the pipeline was material — the deterministic steps together take about a second.
 *
 * So the work is now organised in four stages, and the expensive one is parallel:
 *
 *   0. TRIAGE (no model). Drop what can never produce user-facing docs — test
 *      classes, -meta.xml sidecars, non-behavioral config. Then drop anything whose
 *      normalized source hash is unchanged since it was last documented. On a large
 *      org this is where most of the work disappears, and it costs nothing.
 *
 *   1. PLAN (model, parallel). Components are bin-packed into a few planning calls
 *      that return JSON only: which pages to create, update or skip, and which
 *      components belong to each. Small output, so these are fast. The planner
 *      works from a precomputed context pack (call graph, reverse dependencies,
 *      entry points, existing page paths) rather than grepping the repo.
 *
 *   2. WRITE (model, parallel). One call per PAGE — never per batch of files. Each
 *      call owns exactly one file, which is what makes parallelism safe: two
 *      workers can never write the same page. This is also the fix for the 60-file
 *      call, which is now however many pages those 60 files actually map to.
 *
 *   3. VERIFY (no model). Frontmatter parses, required sections present, nothing
 *      written outside docs/business/.
 *
 * Progress is tracked per component, not by a single commit pointer, so a partial
 * failure only re-queues the components that actually failed.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { runClaudeWithRetry, pool, extractJson, DOC_TOOLS, CLAUDE_BIN } from './lib/claude-runner.mjs';

const require = createRequire(import.meta.url);
const { discover } = require('./lib/discover');
const { createContext, buildContextPack, docRelevance, hashFile } = require('./lib/context-pack');
const { RunReport, fmtDuration } = require('./lib/run-report');

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..', '..');
const FORCE_APP = path.join(ROOT, 'force-app', 'main', 'default');
const BUSINESS_DIR = path.join(ROOT, 'docs', 'business');
const TEMPLATE_FILE = path.join(BUSINESS_DIR, 'TEMPLATE.md');
const STATE_FILE = path.join(ROOT, 'docs', '_state', 'progress.json');
const REPORT_FILE = path.join(ROOT, 'docs', '_state', 'run-report.json');
const TECH_DATA_FILE = path.join(ROOT, 'docs', 'technical', 'data.json');

// Bump when the prompts below change materially: it is part of the cache key, so
// editing a prompt correctly invalidates previously-generated pages.
const PROMPT_VERSION = 2;

const CONCURRENCY = Number(process.env.DOCS_AI_CONCURRENCY || 4);
// Planning output is small, so a planning call can cover many components. Writing
// is one page per call — that is the whole point, not a tunable.
const PLAN_BATCH_COMPONENTS = Number(process.env.DOCS_PLAN_BATCH || 40);
const CALL_TIMEOUT_MS = Number(process.env.DOCS_AI_TIMEOUT_MS || 10 * 60 * 1000);
const MAX_PAGES_PER_RUN = Number(process.env.DOCS_MAX_PAGES || 200);

function sh(cmd) {
  try { return execSync(cmd, { cwd: ROOT, stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 * 1024 * 1024 }).toString().trim(); }
  catch (e) { return null; }
}

function loadState() {
  try { return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')); } catch (e) { return {}; }
}

function saveState(patch) {
  const next = { ...loadState(), ...patch };
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(next, null, 2));
}

function warn(msg) {
  if (process.env.GITHUB_ACTIONS) console.log(`::warning::${msg}`);
  console.warn(msg);
}

/** Dirty paths, parsed from UN-trimmed porcelain output (trimming shifts the
 *  status prefix and mangles the first filename). */
function dirtyPaths() {
  let raw;
  try { raw = execSync('git status --porcelain', { cwd: ROOT, stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 * 1024 * 1024 }).toString(); }
  catch (e) { return []; }
  return raw.split('\n').filter(Boolean).map((line) => {
    let p = line.slice(3);
    if (p.includes(' -> ')) p = p.split(' -> ').pop();
    return p.replace(/^"(.*)"$/, '$1').trim();
  }).filter(Boolean);
}

function classifyForceAppPath(repoRelPath) {
  const marker = 'force-app/main/default/';
  const idx = repoRelPath.indexOf(marker);
  if (idx === -1) return null;
  const rel = repoRelPath.slice(idx + marker.length);
  const base = path.basename(rel);
  if (base.endsWith('.cls') && !base.endsWith('.cls-meta.xml')) return { type: 'ApexClass', name: base.replace(/\.cls$/, '') };
  if (base.endsWith('.trigger') && !base.endsWith('.trigger-meta.xml')) return { type: 'ApexTrigger', name: base.replace(/\.trigger$/, '') };
  if (base.endsWith('.object-meta.xml')) return { type: 'CustomObject', name: base.replace(/\.object-meta\.xml$/, '') };
  if (base.endsWith('.field-meta.xml')) return { type: 'CustomField', name: `${path.basename(path.dirname(path.dirname(rel)))}.${base.replace(/\.field-meta\.xml$/, '')}` };
  if (base.endsWith('.flow-meta.xml')) return { type: 'Flow', name: base.replace(/\.flow-meta\.xml$/, '') };
  if (base.endsWith('.js-meta.xml') && rel.includes('lwc/')) return { type: 'LightningComponentBundle', name: path.basename(path.dirname(rel)) };
  return { type: 'metadata', name: base };
}

// ===========================================================================
// Stage 0 — triage (no model)
// ===========================================================================

const state = loadState();
const headSha = sh('git rev-parse HEAD');
if (!headSha) {
  console.log('Not a git repo (or no commits yet) — skipping AI business-doc authorship.');
  process.exit(0);
}

const lastAuthored = state.lastAuthoredCommit || null;
const isBaseline = !lastAuthored || sh(`git cat-file -e ${lastAuthored}`) === null;
const STATUS_LABEL = { A: 'Added', M: 'Modified', D: 'Removed', R: 'Renamed' };

let rawChanges;
if (isBaseline) {
  console.log('No prior authored commit — initial baseline: every discovered component is in scope.');
  rawChanges = discover(FORCE_APP).map((c) => ({
    status: 'Added',
    type: c.type,
    name: c.name,
    path: path.join('force-app', 'main', 'default', c.path).split(path.sep).join('/'),
  }));
} else {
  const nameStatusRaw = sh(`git diff --name-status ${lastAuthored}..${headSha} -- force-app`) || '';
  rawChanges = nameStatusRaw.split('\n').filter(Boolean).map((line) => {
    const [statusRaw, ...pathParts] = line.split('\t');
    const filePath = pathParts[pathParts.length - 1];
    const hit = classifyForceAppPath(filePath.split(path.sep).join('/'));
    return hit ? { status: STATUS_LABEL[statusRaw[0]] || 'Modified', path: filePath.split(path.sep).join('/'), ...hit } : null;
  }).filter(Boolean);
}

if (rawChanges.length === 0) {
  console.log('No force-app changes since the last authored commit — nothing for the AI step to write about.');
  process.exit(0);
}

const ctx = createContext({ repoRoot: ROOT, techDataFile: TECH_DATA_FILE, businessDir: BUSINESS_DIR });
const report = new RunReport({ headSha, baseline: isBaseline, model: process.env.ANTHROPIC_MODEL || 'sonnet', concurrency: CONCURRENCY });
const componentState = state.components || {};

// Filter 1: can this component ever produce a user-facing page?
const relevant = [];
for (const ch of rawChanges) {
  const verdict = docRelevance(ch, ctx.componentsByName.get(ch.name));
  if (verdict.relevant) relevant.push(ch);
  else report.addSkipped(ch.name, verdict.reason);
}

// Filter 2: has anything about this component actually changed since it was last
// documented? Hash the NORMALIZED source (comments and whitespace stripped) plus
// the prompt version, so reformatting does not trigger a rewrite but a prompt
// change does.
const changes = [];
let cachedCount = 0;
for (const ch of relevant) {
  if (ch.status === 'Removed') { changes.push(ch); continue; }
  const hash = `${PROMPT_VERSION}:${hashFile(path.join(ROOT, ch.path))}`;
  const prior = componentState[ch.name];
  if (prior && prior.hash === hash && prior.page && fs.existsSync(path.join(ROOT, prior.page))) {
    cachedCount++;
    continue;
  }
  changes.push({ ...ch, hash });
}
report.meta.cachedPages = cachedCount;

console.log(`Triage: ${rawChanges.length} changed component(s) -> ${relevant.length} doc-relevant -> ${changes.length} needing work ` +
  `(${report.skipped.length} filtered, ${cachedCount} unchanged since last documented).`);

if (changes.length === 0) {
  console.log('Everything already documented and unchanged — no model calls needed.');
  saveState({ lastAuthoredCommit: headSha });
  report.finish(0).write({ jsonFile: REPORT_FILE });
  process.exit(0);
}

// ---- preconditions for actually calling the model -------------------------
const hasClaudeCli = sh(`"${CLAUDE_BIN}" --version`) !== null;
if (!hasClaudeCli) {
  warn('The `claude` CLI is not installed here — SKIPPING AI business-doc authorship. ' +
    `${changes.length} component(s) stay queued (lastAuthoredCommit not advanced).`);
  console.log('Install it with: npm install -g @anthropic-ai/claude-code');
  changes.forEach((c) => console.log(`  - ${c.status}: ${c.path}`));
  process.exit(0);
}
// Hard requirement: this pipeline bills against a Claude Pro/Max SUBSCRIPTION, never
// a pay-per-token API key. The CLI will happily authenticate with ANTHROPIC_API_KEY /
// ANTHROPIC_AUTH_TOKEN if either is present in the environment, which would silently
// move every call in this run onto metered API billing. Refuse to start instead.
const apiKeyVars = ['ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BEDROCK_BASE_URL', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX']
  .filter((v) => process.env[v]);
if (apiKeyVars.length) {
  console.error(`::error::Refusing to run: ${apiKeyVars.join(', ')} is set in the environment. ` +
    'The CLI would authenticate with that instead of the subscription token, putting this run on ' +
    'metered pay-per-token billing. Unset it so CLAUDE_CODE_OAUTH_TOKEN is used.');
  process.exit(1);
}

if (!process.env.CLAUDE_CODE_OAUTH_TOKEN) {
  warn('CLAUDE_CODE_OAUTH_TOKEN is not set — SKIPPING AI business-doc authorship, so docs/business/ will not be updated. ' +
    `${changes.length} component(s) stay queued until a run has the token. ` +
    'In GitHub Actions: add the CLAUDE_CODE_OAUTH_TOKEN repo secret (Settings -> Secrets and variables -> Actions), generated with `claude setup-token`.');
  process.exit(0);
}

const template = fs.existsSync(TEMPLATE_FILE) ? fs.readFileSync(TEMPLATE_FILE, 'utf8') : '';
const runOpts = {
  cwd: ROOT,
  allowedTools: DOC_TOOLS,
  timeoutMs: CALL_TIMEOUT_MS,
  fallbackModel: 'claude-sonnet-4-5',
  env: process.env,
};

// ===========================================================================
// Stage 1 — plan (model, parallel)
// ===========================================================================
//
// PROMPT LAYOUT NOTE: everything fixed across calls (role, rules, output schema)
// comes FIRST and the per-call payload comes LAST. Prompt caching matches on an
// exact prefix, so stable-content-first is what lets the second and later calls
// read the cache instead of paying for the preamble again.

const PLAN_PREAMBLE = `You are triaging Salesforce metadata to decide what BUSINESS documentation should exist.
You are not writing documentation in this step. You are producing a plan, as JSON.

Rules for deciding:
- A page is warranted only when a change is USER-FACING: something a salesperson, ops user, admin or
  external system can observe or trigger. The context pack below lists each component's entry points
  and its production callers; treat that data as authoritative and do NOT search the repository to
  re-derive it.
- Components with no entry point and no production callers are dead code. Plan "skip" for them.
- Pure internal helpers (recursion guards, collection/validation utilities) get no page of their own.
- Related components belong on ONE page. Prefer a small number of substantial, user-shaped pages over
  one page per class. A trigger, its handler and its service class are one feature, not three.
- If a component is already covered by an existing page (the pack says so), plan "update" against that
  exact path rather than creating a new page.

Return ONLY a JSON object in a \`\`\`json fenced block, with this exact shape:

{
  "pages": [
    {
      "action": "create" | "update" | "skip",
      "path": "docs/business/<category-folder>/<slug>.md",
      "title": "Human page title",
      "feature": "Short feature name",
      "category": "Orders",
      "slug": "kebab-case-slug",
      "components": ["ApexClassName", "Object__c.Field__c"],
      "reason": "one sentence"
    }
  ]
}

For "skip", only "action", "components" and "reason" matter.
For "update", "path" MUST be an existing page path given in the pack.
Every component listed in the pack must appear in exactly one entry.`;

function buildPlanPrompt(batch) {
  const existing = ctx.pageIndex.length
    ? ctx.pageIndex.map((p) => `- ${p.path} — "${p.title}" (feature: ${p.feature}, category: ${p.category})`).join('\n')
    : '(none yet — this is the first documentation pass)';

  return `${PLAN_PREAMBLE}

---- EXISTING BUSINESS PAGES ----
${existing}

---- CONTEXT PACK (precomputed and authoritative) ----
${buildContextPack(batch, ctx)}`;
}

/** Bin-pack components into planning calls, keeping each feature intact. */
function planBatches(items) {
  const byFeature = new Map();
  for (const c of items) {
    const f = ctx.featureByComponent.get(c.name) || 'Unmapped';
    if (!byFeature.has(f)) byFeature.set(f, []);
    byFeature.get(f).push(c);
  }
  const batches = [];
  let current = [];
  for (const [, list] of byFeature) {
    for (let i = 0; i < list.length; i += PLAN_BATCH_COMPONENTS) {
      const slice = list.slice(i, i + PLAN_BATCH_COMPONENTS);
      if (current.length && current.length + slice.length > PLAN_BATCH_COMPONENTS) {
        batches.push(current); current = [];
      }
      current = current.concat(slice);
    }
  }
  if (current.length) batches.push(current);
  return batches;
}

const started = Date.now();
const batches = planBatches(changes);
console.log(`\nStage 1 — planning: ${changes.length} component(s) in ${batches.length} call(s), concurrency ${CONCURRENCY}.`);

const planResults = await pool(batches, async (batch, i) => {
  const label = `plan ${i + 1}/${batches.length} (${batch.length} components)`;
  const res = await runClaudeWithRetry(buildPlanPrompt(batch), runOpts, {
    retries: 2,
    onRetry: (n, ms, err) => console.log(`  ${label}: retry ${n} in ${Math.round(ms / 1000)}s after: ${err}`),
  });
  report.addCall('plan', label, res);
  if (!res.ok) { console.error(`  ${label}: FAILED — ${res.error}`); return { batch, plan: null }; }
  const parsed = extractJson(res.text);
  if (!parsed || !Array.isArray(parsed.pages)) {
    console.error(`  ${label}: could not parse a plan from the reply`);
    return { batch, plan: null };
  }
  console.log(`  ${label}: ${fmtDuration(res.durationMs)} — ${parsed.pages.length} planned entr(ies)`);
  return { batch, plan: parsed.pages };
}, {
  concurrency: CONCURRENCY,
  warmFirst: true, // first call alone so the rest can read its cached prefix
});

// Merge plans. Two planning calls can independently target the same page (a shared
// class touching two features); merging by path keeps ONE writer per file, which is
// what makes the write stage safe to parallelise.
const pagesByPath = new Map();
const plannedComponents = new Set();
let planFailures = 0;

for (const r of planResults) {
  if (!r.plan) { planFailures++; continue; }
  for (const entry of r.plan) {
    const comps = Array.isArray(entry.components) ? entry.components : [];
    comps.forEach((c) => plannedComponents.add(c));
    if (entry.action === 'skip') {
      comps.forEach((c) => report.addSkipped(c, `planner: ${entry.reason || 'no user-facing effect'}`));
      continue;
    }
    if (!entry.path) continue;
    const key = entry.path;
    if (pagesByPath.has(key)) {
      const existing = pagesByPath.get(key);
      existing.components = Array.from(new Set(existing.components.concat(comps)));
    } else {
      pagesByPath.set(key, { ...entry, components: comps });
    }
  }
}

let pages = Array.from(pagesByPath.values());
if (pages.length > MAX_PAGES_PER_RUN) {
  warn(`Planner proposed ${pages.length} pages; capping this run at ${MAX_PAGES_PER_RUN}. ` +
    'The remainder stay queued and are picked up by the next run (their components keep no cache entry).');
  pages = pages.slice(0, MAX_PAGES_PER_RUN);
}

if (!pages.length) {
  console.log('\nPlanner produced no pages to write (everything was internal or dead code).');
  if (planFailures === 0) {
    saveState({
      lastAuthoredCommit: headSha,
      components: { ...componentState, ...Object.fromEntries(changes.filter((c) => c.hash).map((c) => [c.name, { hash: c.hash, page: null }])) },
    });
  }
  report.finish(Date.now() - started).write({ jsonFile: REPORT_FILE });
  process.exit(0);
}

// ===========================================================================
// Stage 2 — write (model, parallel, one file per call)
// ===========================================================================

const WRITE_PREAMBLE = `You write BUSINESS/use-case documentation for a Salesforce project, under docs/business/.
You will be given exactly ONE page to produce, and you must write ONLY that file.

Each page is Markdown with YAML frontmatter followed by these sections in order:
Overview, Prerequisites, Steps to Navigate, Use Cases, Validations & Business Rules, Related Features.

---TEMPLATE START---
${template}
---TEMPLATE END---

Frontmatter requirements:
- Include every key the template shows.
- Set "verified: false" — these pages are AI-drafted and reviewed by a human before merge.
- Add a "components:" list naming every force-app component this page documents. The pipeline reads
  this to know which page covers which component, so it must be accurate and complete.

Depth requirements — a page is incomplete without these:
- "Use Cases": give each distinct scenario its own "###" sub-section with numbered steps — the happy
  path, the exception path, the correction/undo path, the bulk path. Derive scenarios from the actual
  branching in the code you read (status transitions, threshold checks, validation failures). Never
  invent behavior the code does not have.
- Diagrams: any record lifecycle or automated decision gets a \`\`\`mermaid block (flowchart for status
  flows and decision trees, sequenceDiagram for multi-system handoffs). Node labels must be
  business-friendly, not raw API names.
- Screenshots: UI steps get \`\`\`screenshot blocks per the template's convention, with declarative
  "actions:" so the capture workflow can replay them.
- Write for the user, not the system: say what a person can do and see, not how the Apex is arranged.

Working rules:
- Read the source files listed for you to see what the code actually does now. The context pack's
  call-graph and entry-point facts are precomputed and authoritative — do not grep to re-derive them.
- If the page already exists, use Edit for targeted changes and preserve everything still accurate.
  Do not rewrite a whole existing page just to touch a few sections.
- Write ONLY your assigned file. Another process is writing the other pages concurrently; touching
  their files will corrupt them.
- Make the edits directly. Do not ask for confirmation. Reply with one short sentence when done.`;

function buildWritePrompt(page) {
  const comps = page.components
    .map((name) => changes.find((c) => c.name === name) || { name, type: ctx.componentsByName.get(name)?.type || 'unknown', status: 'Modified', path: ctx.componentsByName.get(name)?.path ? `force-app/main/default/${ctx.componentsByName.get(name).path}` : '' })
    .filter((c) => c.path);
  const exists = fs.existsSync(path.join(ROOT, page.path));

  return `${WRITE_PREAMBLE}

---- YOUR ASSIGNED PAGE ----
File to ${exists ? 'UPDATE (it already exists — read it first, then Edit)' : 'CREATE'}: ${page.path}
Title: ${page.title}
Feature: ${page.feature}
Category: ${page.category}
Slug: ${page.slug}
Why this page: ${page.reason || 'documents the components below'}

---- COMPONENTS THIS PAGE COVERS (context pack, precomputed and authoritative) ----
${buildContextPack(comps, ctx)}`;
}

console.log(`\nStage 2 — writing ${pages.length} page(s), one call each, concurrency ${CONCURRENCY}.`);
const dirtyBefore = new Set(dirtyPaths());

const writeResults = await pool(pages, async (page, i) => {
  const label = page.path.replace(/^docs\/business\//, '');
  const res = await runClaudeWithRetry(buildWritePrompt(page), runOpts, {
    retries: 2,
    onRetry: (n, ms, err) => console.log(`  ${label}: retry ${n} in ${Math.round(ms / 1000)}s after: ${err}`),
  });
  report.addCall('write', label, res);
  const wrote = fs.existsSync(path.join(ROOT, page.path));
  if (!res.ok) console.error(`  [${i + 1}/${pages.length}] ${label}: FAILED — ${res.error}`);
  else if (!wrote) console.error(`  [${i + 1}/${pages.length}] ${label}: call succeeded but the file was not created`);
  else console.log(`  [${i + 1}/${pages.length}] ${label}: ${fmtDuration(res.durationMs)}, ${res.turns ?? '?'} turns`);
  return { page, ok: res.ok && wrote };
}, {
  concurrency: CONCURRENCY,
  warmFirst: false, // stage 1 already warmed the shared prefix
});

// ===========================================================================
// Stage 3 — verify and record (no model)
// ===========================================================================

// Anything newly dirty outside docs/business/ is out of scope regardless of what
// the tool allowlist permitted.
const outOfScope = dirtyPaths().filter((f) => !f.startsWith('docs/business/') && !dirtyBefore.has(f));
if (outOfScope.length) {
  console.warn(`\nReverting ${outOfScope.length} file(s) touched outside docs/business/:`);
  for (const f of outOfScope) {
    console.warn(`  - ${f}`);
    if (sh(`git ls-files --error-unmatch "${f}"`) !== null) sh(`git checkout -- "${f}"`);
    else { try { fs.rmSync(path.join(ROOT, f), { recursive: true, force: true }); } catch (e) { console.warn(`    could not remove: ${e.message}`); } }
  }
}

// A page that does not parse would break build-site.js, so check before recording
// success — a malformed page must be re-attempted next run, not cached as done.
const { default: matterLib } = await import('gray-matter');
const REQUIRED_SECTIONS = ['## Overview', '## Steps to Navigate', '## Use Cases'];
const succeeded = [];
for (const r of writeResults) {
  if (!r || !r.ok) continue;
  const abs = path.join(ROOT, r.page.path);
  let problem = null;
  try {
    const raw = fs.readFileSync(abs, 'utf8');
    const fm = matterLib(raw);
    if (!fm.data || !fm.data.title) problem = 'frontmatter has no title';
    else {
      const missing = REQUIRED_SECTIONS.filter((s) => !raw.includes(s));
      if (missing.length) problem = `missing section(s): ${missing.join(', ')}`;
    }
  } catch (e) { problem = `unparseable: ${e.message}`; }
  if (problem) { warn(`${r.page.path}: ${problem} — not recorded as done, will be retried next run.`); continue; }
  succeeded.push(r.page);
}

const writeFailures = writeResults.filter((r) => !r || !r.ok).length;
const verifyFailures = writeResults.filter((r) => r && r.ok).length - succeeded.length;

// Record per-component hashes ONLY for components on pages that were written and
// verified. Everything else stays uncached so the next run retries exactly it.
const nextComponents = { ...componentState };
for (const page of succeeded) {
  for (const name of page.components) {
    const ch = changes.find((c) => c.name === name);
    if (ch && ch.hash) nextComponents[name] = { hash: ch.hash, page: page.path };
  }
}

const allClean = planFailures === 0 && writeFailures === 0 && verifyFailures === 0;
if (allClean) {
  saveState({ lastAuthoredCommit: headSha, components: nextComponents });
  console.log(`\nRecorded lastAuthoredCommit=${headSha.slice(0, 7)} and ${Object.keys(nextComponents).length} component hash(es).`);
} else {
  // Keep the per-component progress that DID succeed, but hold the commit pointer
  // back so the failed components are re-diffed next run.
  saveState({ components: nextComponents });
  warn(`${planFailures} plan + ${writeFailures} write + ${verifyFailures} verify failure(s) — NOT advancing lastAuthoredCommit. ` +
    'Successful pages are cached; the next run retries only what failed.');
}

const wallMs = Date.now() - started;
report.note(`${succeeded.length} page(s) written and verified.`);
report.finish(wallMs).write({ jsonFile: REPORT_FILE });

console.log(`AI business-doc authorship complete in ${fmtDuration(wallMs)}.`);
process.exit(allClean ? 0 : 0); // never fail the pipeline; the report carries the detail
