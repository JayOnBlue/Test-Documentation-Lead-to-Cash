'use strict';
/**
 * Run reporting for the AI authoring step.
 *
 * Before this, a run's only trace was interleaved stdout and a green check — the
 * step that silently skipped every batch for two runs looked identical to one that
 * worked. Every model call now records status, duration, turns, token usage
 * (including cache hits) and cost, and the run ends with:
 *
 *   - docs/_state/run-report.json   machine-readable, committed with the run
 *   - $GITHUB_STEP_SUMMARY          a table on the Actions run page
 *   - stdout                        the same table, for local runs
 *
 * Cache-hit rate is reported deliberately: it is the single number that says
 * whether the prompt-cache optimisations are actually working, and Anthropic's
 * guidance is to watch it the way you would watch uptime.
 */
const fs = require('fs');
const path = require('path');

function fmtDuration(ms) {
  if (ms == null) return '—';
  const s = ms / 1000;
  return s < 60 ? `${s.toFixed(1)}s` : `${Math.floor(s / 60)}m ${Math.round(s % 60)}s`;
}

function fmtTokens(n) {
  if (!n) return '0';
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
  return String(n);
}

function fmtCost(usd) {
  return usd == null ? '—' : `$${usd.toFixed(4)}`;
}

class RunReport {
  constructor(meta = {}) {
    this.meta = { startedAt: new Date().toISOString(), ...meta };
    this.calls = [];
    this.skipped = [];
    this.notes = [];
  }

  /** Record one model call. `kind` is 'plan' or 'write'. */
  addCall(kind, label, result) {
    this.calls.push({
      kind,
      label,
      ok: !!result.ok,
      error: result.error || null,
      durationMs: result.durationMs ?? null,
      turns: result.turns ?? null,
      costUsd: result.costUsd ?? null,
      attempts: result.attempts ?? 1,
      model: result.model || null,
      permissionDenials: result.permissionDenials || 0,
      usage: result.usage || { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    });
  }

  /** Record work the deterministic filters removed before any model saw it. */
  addSkipped(name, reason) { this.skipped.push({ name, reason }); }

  note(text) { this.notes.push(text); }

  totals() {
    const t = {
      calls: this.calls.length,
      ok: this.calls.filter((c) => c.ok).length,
      failed: this.calls.filter((c) => !c.ok).length,
      retried: this.calls.filter((c) => (c.attempts || 1) > 1).length,
      input: 0, output: 0, cacheRead: 0, cacheWrite: 0,
      costUsd: 0,
      permissionDenials: 0,
      // Sum of per-call durations. Compared against wall clock this is the
      // parallelism speed-up actually achieved on this run.
      serialMs: 0,
    };
    for (const c of this.calls) {
      t.input += c.usage.input; t.output += c.usage.output;
      t.cacheRead += c.usage.cacheRead; t.cacheWrite += c.usage.cacheWrite;
      t.costUsd += c.costUsd || 0;
      t.serialMs += c.durationMs || 0;
      t.permissionDenials += c.permissionDenials || 0;
    }
    const cacheable = t.cacheRead + t.cacheWrite;
    t.cacheHitRate = cacheable ? t.cacheRead / cacheable : 0;
    return t;
  }

  finish(wallMs) {
    this.meta.finishedAt = new Date().toISOString();
    this.meta.wallMs = wallMs;
    return this;
  }

  toJSON() {
    return { meta: this.meta, totals: this.totals(), calls: this.calls, skipped: this.skipped, notes: this.notes };
  }

  /** GitHub-flavoured Markdown, used for both the step summary and stdout. */
  toMarkdown() {
    const t = this.totals();
    const wall = this.meta.wallMs;
    const speedup = wall && t.serialMs ? (t.serialMs / wall) : null;
    const out = [];

    out.push('## Documentation AI step');
    out.push('');
    out.push(`**${t.ok}/${t.calls} calls succeeded**${t.failed ? ` — ${t.failed} failed` : ''}${t.retried ? `, ${t.retried} needed a retry` : ''}`);
    out.push('');
    out.push('| | |');
    out.push('|---|---|');
    out.push(`| Wall clock | ${fmtDuration(wall)} |`);
    out.push(`| Model time if run serially | ${fmtDuration(t.serialMs)}${speedup ? ` (**${speedup.toFixed(1)}x** faster in parallel)` : ''} |`);
    out.push(`| Model | ${this.meta.model || 'default'} |`);
    out.push(`| Input tokens | ${fmtTokens(t.input)} |`);
    out.push(`| Output tokens | ${fmtTokens(t.output)} |`);
    out.push(`| Cache read / written | ${fmtTokens(t.cacheRead)} / ${fmtTokens(t.cacheWrite)} |`);
    out.push(`| Cache hit rate | ${(t.cacheHitRate * 100).toFixed(0)}% |`);
    out.push(`| Cost | ${fmtCost(t.costUsd)} |`);
    out.push(`| Filtered before any model call | ${this.skipped.length} component(s) |`);
    if (t.permissionDenials) {
      out.push(`| ⚠️ Tool permission denials | ${t.permissionDenials} — an agent wanted a tool the allowlist refused; it wastes turns, so widen DOC_TOOLS or tighten the prompt |`);
    }
    out.push(`| Pages unchanged (cache hit, not regenerated) | ${this.meta.cachedPages ?? 0} |`);
    out.push('');

    if (this.calls.length) {
      out.push('### Calls');
      out.push('');
      out.push('| | Stage | Target | Time | Turns | In | Out | Cached | Cost |');
      out.push('|---|---|---|---|---:|---:|---:|---:|---:|');
      for (const c of this.calls) {
        out.push(`| ${c.ok ? '✅' : '❌'} | ${c.kind} | ${c.label} | ${fmtDuration(c.durationMs)} | ${c.turns ?? '—'} | ${fmtTokens(c.usage.input)} | ${fmtTokens(c.usage.output)} | ${fmtTokens(c.usage.cacheRead)} | ${fmtCost(c.costUsd)} |`);
      }
      out.push('');
    }

    const failures = this.calls.filter((c) => !c.ok);
    if (failures.length) {
      out.push('### Failures');
      out.push('');
      for (const f of failures) out.push(`- **${f.label}** (${f.kind}): ${f.error}`);
      out.push('');
      out.push('_These components stay queued — the progress marker is not advanced past them, so the next run retries them._');
      out.push('');
    }

    if (this.skipped.length) {
      const byReason = new Map();
      for (const s of this.skipped) byReason.set(s.reason, (byReason.get(s.reason) || 0) + 1);
      out.push('<details><summary>Filtered out before any model call</summary>');
      out.push('');
      for (const [reason, count] of byReason) out.push(`- ${count} x ${reason}`);
      out.push('');
      out.push('</details>');
      out.push('');
    }

    for (const n of this.notes) out.push(`> ${n}`);
    return out.join('\n');
  }

  write({ jsonFile, stepSummaryFile = process.env.GITHUB_STEP_SUMMARY }) {
    if (jsonFile) {
      fs.mkdirSync(path.dirname(jsonFile), { recursive: true });
      fs.writeFileSync(jsonFile, JSON.stringify(this.toJSON(), null, 2));
    }
    const md = this.toMarkdown();
    if (stepSummaryFile) {
      try { fs.appendFileSync(stepSummaryFile, md + '\n'); }
      catch (e) { console.warn(`Could not write the step summary: ${e.message}`); }
    }
    console.log('\n' + md + '\n');
  }
}

module.exports = { RunReport, fmtDuration, fmtTokens, fmtCost };
