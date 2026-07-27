'use strict';
/**
 * Precomputed context for the AI authoring step.
 *
 * WHY THIS EXISTS
 * ---------------
 * The first production run of this pipeline spent 23 minutes on the AI step, and
 * the transcript shows where much of it went: the agent grepping the repository to
 * answer questions the pipeline had ALREADY answered deterministically — "is this
 * class called from anywhere?", "which page documents this feature?", "is this a
 * test class?". docs/technical/data.json holds a full component graph (methods,
 * dependsOn, usedBy, isTestClass) and docs/business/ holds parseable frontmatter.
 *
 * So: compute the facts once, in Node, and hand them to the model as authoritative
 * input. Anthropic's own context-engineering guidance is that runtime exploration
 * is slower than retrieving precomputed data, and recommends the hybrid used here —
 * facts up front, with the agent still free to Read the source it needs to write
 * accurate prose.
 *
 * Everything in this module is deterministic. No model is involved.
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const matter = require('gray-matter');

// A reverse-dependency list on a shared utility class can run to hundreds of
// entries in a large org. Truncate (highest-signal first) rather than blowing the
// prompt budget — the count is still reported so the model knows it was truncated.
const MAX_LISTED_RELATIONS = 12;

// ---------------------------------------------------------------------------
// Technical graph
// ---------------------------------------------------------------------------

function loadTechData(techDataFile) {
  try { return JSON.parse(fs.readFileSync(techDataFile, 'utf8')); }
  catch (e) { return { components: [], features: [] }; }
}

/** name -> component record from data.json */
function indexComponents(techData) {
  const byName = new Map();
  for (const c of techData.components || []) byName.set(c.name, c);
  return byName;
}

/** name -> feature title, from the connected-component clusters data.json computes. */
function indexFeatures(techData) {
  const byComponent = new Map();
  for (const f of techData.features || []) {
    for (const m of f.members) byComponent.set(m, f.title);
  }
  return byComponent;
}

// ---------------------------------------------------------------------------
// Doc relevance pre-filter  (runs BEFORE any model call)
// ---------------------------------------------------------------------------

const TEST_NAME_RE = /(^Test[A-Z_]|Test$|_Test$|Tests$)/;

/**
 * Is this component worth spending a model call on?
 *
 * Salesforce diffs are noisy: test classes are typically a third to a half of the
 * Apex in an org and can never produce user-facing documentation, and org-wide
 * apiVersion bumps churn thousands of -meta.xml files with no behavior change. The
 * previous run proves the cost of not filtering — the model read six *Test.cls
 * files across two batches purely to conclude "skipped: internal tests".
 *
 * Returns { relevant: true } or { relevant: false, reason }.
 */
function docRelevance(change, component) {
  const name = change.name || '';
  const rel = (change.path || '').split(path.sep).join('/');

  if ((component && component.isTestClass) || TEST_NAME_RE.test(name)) {
    return { relevant: false, reason: 'test class — never user-facing documentation' };
  }
  if (/\.cls-meta\.xml$|\.trigger-meta\.xml$/.test(rel)) {
    return { relevant: false, reason: 'Apex -meta.xml sidecar (apiVersion/status only)' };
  }
  if (/\/(profiles|permissionsets|layouts|translations|labels|staticresources)\//.test(rel)) {
    return { relevant: false, reason: 'non-behavioral configuration metadata' };
  }
  if (change.type === 'metadata') {
    return { relevant: false, reason: 'unclassified metadata with no component type' };
  }
  return { relevant: true };
}

// ---------------------------------------------------------------------------
// Source-derived signals
// ---------------------------------------------------------------------------

/**
 * How does a user or external system actually reach this component? This is the
 * question that decides whether a page is warranted at all, and the model
 * previously answered it with repo-wide greps.
 */
function entryPointsFor(component, absPath) {
  const hits = [];
  if (!component) return hits;
  if (component.type === 'ApexTrigger') hits.push('Runs automatically on record save (Apex trigger)');
  if (component.type === 'Flow') hits.push('Flow — runs from its own trigger/entry criteria');
  if (component.type === 'LightningComponentBundle') hits.push('Lightning component placed on a page by an admin');
  if (component.type === 'CustomObject') hits.push('Object records created/edited by users');

  for (const m of component.methods || []) {
    if (m.auraEnabled) hits.push(`Called from the UI: ${m.signature || m.name} (@AuraEnabled)`);
  }

  let src = '';
  try { src = fs.readFileSync(absPath, 'utf8'); } catch (e) { /* deleted or not a file */ }
  if (/@RestResource/i.test(src)) hits.push('Exposed as a REST endpoint (@RestResource)');
  if (/implements\s+[^{]*Schedulable/i.test(src)) hits.push('Runs on a schedule (Schedulable)');
  if (/implements\s+[^{]*Database\.Batchable/i.test(src)) hits.push('Runs as a batch job (Database.Batchable)');
  if (/@InvocableMethod/i.test(src)) hits.push('Callable from Flow (@InvocableMethod)');
  if (/@future/i.test(src)) hits.push('Runs asynchronously (@future)');
  return hits;
}

/**
 * Strip comments and collapse whitespace before hashing, so a reformat or a
 * comment tweak does not invalidate a cached page.
 */
function normalizeSource(text) {
  return String(text)
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/\/\/[^\n]*/g, ' ')
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function hashFile(absPath) {
  try { return crypto.createHash('sha1').update(normalizeSource(fs.readFileSync(absPath, 'utf8'))).digest('hex').slice(0, 16); }
  catch (e) { return 'missing'; }
}

// ---------------------------------------------------------------------------
// Existing business pages
// ---------------------------------------------------------------------------

function walkMarkdown(dir) {
  let out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out = out.concat(walkMarkdown(full));
    else if (entry.name.endsWith('.md') && entry.name !== 'TEMPLATE.md') out.push(full);
  }
  return out;
}

/**
 * Index every existing business page ONCE per run.
 *
 * This replaces the old prompt's step 1 ("Read the existing pages under
 * docs/business/ to find the page(s)..."), which made every single batch sweep the
 * whole docs tree — O(pages x batches) work that grows with the documentation set.
 * Now each prompt is told the exact file to open, or that none exists.
 */
function buildPageIndex(businessDir, repoRoot) {
  const pages = [];
  for (const full of walkMarkdown(businessDir)) {
    let data = {};
    try { data = matter(fs.readFileSync(full, 'utf8')).data || {}; } catch (e) { data = {}; }
    const relPath = path.relative(repoRoot, full).split(path.sep).join('/');
    pages.push({
      path: relPath,
      slug: data.slug || path.basename(full, '.md'),
      title: data.title || '',
      feature: data.feature || data.title || '',
      category: data.category || 'General',
      // `components` is written by this pipeline (see the write prompt) so a page
      // knows which force-app components it covers. Hand-written pages won't have
      // it; those fall back to feature-title matching.
      components: Array.isArray(data.components) ? data.components : [],
    });
  }
  return pages;
}

/** component name -> existing page, via the explicit `components:` frontmatter list. */
function componentToPage(pageIndex) {
  const map = new Map();
  for (const p of pageIndex) for (const c of p.components) map.set(c, p);
  return map;
}

// ---------------------------------------------------------------------------
// The pack itself
// ---------------------------------------------------------------------------

function relationLine(label, list) {
  if (!list || !list.length) return `${label}: none`;
  const names = list.map((r) => (typeof r === 'string' ? r : r.name));
  const shown = names.slice(0, MAX_LISTED_RELATIONS);
  const more = names.length - shown.length;
  return `${label} (${names.length}): ${shown.join(', ')}${more > 0 ? `, +${more} more` : ''}`;
}

/**
 * A compact, authoritative block describing one component. Deliberately terse —
 * this is reference data the model reads, not prose it has to wade through.
 */
function packForComponent(change, ctx) {
  const c = ctx.componentsByName.get(change.name);
  const absPath = path.join(ctx.repoRoot, change.path);
  const lines = [];
  lines.push(`### ${change.name} (${change.type}) — ${change.status}`);
  lines.push(`Path: ${change.path}`);
  if (c) {
    if (c.methods && c.methods.length) {
      const sigs = c.methods.slice(0, MAX_LISTED_RELATIONS).map((m) => m.signature || m.name);
      lines.push(`Methods (${c.methods.length}): ${sigs.join(' | ')}${c.methods.length > sigs.length ? ' | ...' : ''}`);
    }
    lines.push(relationLine('Calls', c.dependsOn));
    // usedBy minus test classes: "only its own test calls this" is the signal that
    // a class is dead code, and the model should not have to grep to learn it.
    const callers = (c.usedBy || []).filter((u) => !TEST_NAME_RE.test(u.name));
    lines.push(relationLine('Called by (excluding tests)', callers));
    if (!callers.length) {
      lines.push('REACHABILITY: nothing in production code calls this. Treat as dead code unless an entry point below says otherwise.');
    }
  }
  const entries = entryPointsFor(c, absPath);
  lines.push(entries.length ? `Entry points: ${entries.join('; ')}` : 'Entry points: none detected');

  const existing = ctx.componentPages.get(change.name);
  lines.push(existing ? `Already documented in: ${existing.path}` : 'Not yet covered by any business page.');
  return lines.join('\n');
}

/** Full context pack for a set of changes belonging to one feature. */
function buildContextPack(changes, ctx) {
  return changes.map((ch) => packForComponent(ch, ctx)).join('\n\n');
}

/**
 * One call sets up everything the prompts need.
 */
function createContext({ repoRoot, techDataFile, businessDir }) {
  const techData = loadTechData(techDataFile);
  const pageIndex = buildPageIndex(businessDir, repoRoot);
  return {
    repoRoot,
    techData,
    componentsByName: indexComponents(techData),
    featureByComponent: indexFeatures(techData),
    pageIndex,
    componentPages: componentToPage(pageIndex),
  };
}

module.exports = {
  createContext,
  buildContextPack,
  packForComponent,
  docRelevance,
  hashFile,
  normalizeSource,
  buildPageIndex,
  entryPointsFor,
  TEST_NAME_RE,
};
