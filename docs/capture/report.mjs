#!/usr/bin/env node
/**
 * Run report for the screenshot capture workflow.
 *
 * The capture job's failures were previously only findable by scrolling a 2,000-line
 * log — the CumulusCI errors that actually killed two runs were a single line each,
 * buried under a full pip install. This prints one short summary that leads with
 * SUCCESS / FAILURE / WARNING counts, then the detail behind each.
 *
 * Inputs (all optional; whatever is present gets reported):
 *   STEP_OUTCOMES  JSON map of step name -> outcome ("success"|"failure"|"skipped"|"")
 *   docs/screenshot-manifest.json           what the docs asked to be captured
 *   docs/images/*.png|jpg|jpeg              what actually exists now
 *   docs/capture/robot/DocsProject/results/output.xml   Robot's own pass/fail record
 *
 * Writes Markdown to $GITHUB_STEP_SUMMARY (when set) and always to stdout.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..', '..');
const MANIFEST = path.join(ROOT, 'docs', 'screenshot-manifest.json');
const IMAGES_DIR = path.join(ROOT, 'docs', 'images');
const ROBOT_OUTPUT = path.join(__dirname, 'robot', 'DocsProject', 'results', 'output.xml');

const ICON = { success: '✅', failure: '❌', skipped: '⏭️', cancelled: '⚪', '': '⚪' };

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { return fallback; }
}

function listImages() {
  try {
    return fs.readdirSync(IMAGES_DIR).filter((f) => /\.(png|jpe?g)$/i.test(f));
  } catch (e) { return []; }
}

/**
 * Robot's output.xml carries a <statistics><total><stat pass="" fail="" skip="">
 * summary. Parsed with a regex rather than an XML dependency — this is one
 * well-known attribute set, not general XML processing, and it keeps the capture
 * harness free of another package.
 */
/**
 * Robot failure messages often open with a bare header line like
 * "Parent suite setup failed:" and put the real cause underneath. Taking only the
 * first line reported exactly that header and threw the diagnosis away, so take the
 * first couple of lines that actually say something.
 */
function firstUsefulLines(text, max = 2) {
  const lines = String(text)
    // Numeric character references first: Robot writes Playwright's box-drawing frame
    // as &#9484;&#9472;… and without decoding them the filter below cannot recognise
    // the frame, so the "cause" line came out as a row of entity codes.
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&')
    .split('\n')
    .map((l) => l.trim())
    // Drop blank lines, bare "...:" headers, and Playwright's box-drawing frame.
    .filter((l) => l && !/^[A-Za-z][\w '-]*:$/.test(l) && !/^[│┌└─┐┘|+=-]+$/.test(l))
    .map((l) => l.replace(/^[│|]\s*/, '').replace(/\s*[│|]$/, '').trim())
    .filter(Boolean);
  return lines.slice(0, max).join(' — ').slice(0, 300) || '(no message; see the Robot report artifact)';
}

function robotStats() {
  let xml;
  try { xml = fs.readFileSync(ROBOT_OUTPUT, 'utf8'); } catch (e) { return null; }
  const totalBlock = xml.match(/<total>([\s\S]*?)<\/total>/);
  const scope = totalBlock ? totalBlock[1] : xml;
  const stat = scope.match(/<stat[^>]*pass="(\d+)"[^>]*fail="(\d+)"(?:[^>]*skip="(\d+)")?/);
  // Match each <test> block FIRST, then look for a FAIL status inside that block.
  // Scanning for name and status in one pattern spans across tests: it pairs the
  // first test's name with the first failing status anywhere after it, which
  // reported the wrong test as the failing one.
  const failedTests = [...xml.matchAll(/<test\b[^>]*\bname="([^"]*)"([\s\S]*?)<\/test>/g)]
    .map(([, name, body]) => {
      const failed = body.match(/<status\b[^>]*\bstatus="FAIL"[^>]*(?:\/>|>([\s\S]*?)<\/status>)/);
      if (!failed) return null;
      return { name, message: firstUsefulLines(failed[1] || '') };
    })
    .filter(Boolean);
  // Known root causes worth naming outright, so nobody has to read Playwright's
  // box-drawing error art to work out what to change.
  const diagnoses = [];
  if (/Missing X server|without having a XServer|\$DISPLAY/i.test(xml)) {
    diagnoses.push('Playwright tried to launch a HEADED browser and the runner has no display. ' +
      'CumulusCI picks headless purely from the `${BROWSER}` variable — it must start with "headless" ' +
      '(e.g. `headlesschrome`). Check the `${BROWSER}` default in docs_capture.robot.');
  }
  if (/INVALID_AUTH_HEADER|Expired session/i.test(xml)) {
    diagnoses.push('The org session was rejected. If the token itself is valid, check that the org config ' +
      'handed to CumulusCI has a real access_token (a redacted `sf org display` value causes exactly this).');
  }
  if (/INVALID_SESSION_ID/i.test(xml)) {
    diagnoses.push('The Salesforce session expired mid-run — mint a fresh access token and re-dispatch.');
  }
  const base = stat
    ? { pass: +stat[1], fail: +stat[2], skip: +(stat[3] || 0) }
    : { pass: 0, fail: 0, skip: 0 };
  return { ...base, failedTests, diagnoses };
}

function parseOutcomes() {
  try { return JSON.parse(process.env.STEP_OUTCOMES || '{}'); }
  catch (e) { console.warn('STEP_OUTCOMES was not valid JSON — reporting without step outcomes.'); return {}; }
}
const outcomes = parseOutcomes();

const manifest = readJson(MANIFEST, []);
const images = listImages();
const captured = new Set(images.map((f) => f.replace(/\.(png|jpe?g)$/i, '')));
const wanted = manifest.map((s) => s.id).filter(Boolean);
const missing = wanted.filter((id) => !captured.has(id));
const robot = robotStats();

const failedSteps = Object.entries(outcomes).filter(([, v]) => v === 'failure').map(([k]) => k);
const okSteps = Object.entries(outcomes).filter(([, v]) => v === 'success').map(([k]) => k);
const skippedSteps = Object.entries(outcomes).filter(([, v]) => v === 'skipped' || !v).map(([k]) => k);

// ---- warnings: things that did not fail the job but need a human to notice ----
const warnings = [];
if (!manifest.length) warnings.push('The screenshot manifest is empty — no `screenshot` blocks were found in docs/business/**. Nothing could be captured.');
if (manifest.length && !images.length) warnings.push(`No images exist at all: 0 of ${wanted.length} requested screenshots were captured.`);
if (images.length && missing.length) warnings.push(`${missing.length} of ${wanted.length} requested screenshots are still missing (the docs render a "Screenshot pending" placeholder for each).`);
if (robot && robot.fail > 0) warnings.push(`Robot reported ${robot.fail} failing capture(s) — the suite continues past individual failures, so the job can look green while images are absent.`);
if (!robot && failedSteps.length) warnings.push('Robot never produced output.xml, so the capture suite did not start — the failure is upstream of it (auth, org config, or CumulusCI project setup).');

const verdict = failedSteps.length ? 'FAILED' : (warnings.length ? 'COMPLETED WITH WARNINGS' : 'SUCCEEDED');
const verdictIcon = failedSteps.length ? '❌' : (warnings.length ? '⚠️' : '✅');

const out = [];
out.push(`## ${verdictIcon} Screenshot capture ${verdict}`);
out.push('');
out.push(`**${okSteps.length} step(s) succeeded · ${failedSteps.length} failed · ${skippedSteps.length} skipped · ${warnings.length} warning(s)**`);
out.push('');

out.push('| | |');
out.push('|---|---|');
out.push(`| Screenshots requested by the docs | ${wanted.length} |`);
out.push(`| Images present after this run | ${images.length} |`);
out.push(`| Still missing | ${missing.length} |`);
if (robot) out.push(`| Robot captures passed / failed | ${robot.pass} / ${robot.fail} |`);
else out.push('| Robot captures | _suite did not run_ |');
out.push('');

if (Object.keys(outcomes).length) {
  out.push('### Steps');
  out.push('');
  out.push('| | Step | Outcome |');
  out.push('|---|---|---|');
  for (const [name, res] of Object.entries(outcomes)) {
    out.push(`| ${ICON[res] || '⚪'} | ${name} | ${res || 'skipped'} |`);
  }
  out.push('');
}

if (failedSteps.length) {
  out.push('### ❌ Failures');
  out.push('');
  for (const s of failedSteps) out.push(`- **${s}** failed — see that step's log for the error.`);
  out.push('');
}

if (robot && robot.diagnoses?.length) {
  out.push('### 🔎 Likely cause');
  out.push('');
  for (const d of robot.diagnoses) out.push(`- ${d}`);
  out.push('');
}

if (robot && robot.failedTests.length) {
  out.push('### ❌ Failing captures');
  out.push('');
  for (const t of robot.failedTests) out.push(`- **${t.name}** — ${t.message}`);
  out.push('');
}

if (warnings.length) {
  out.push('### ⚠️ Warnings');
  out.push('');
  for (const w of warnings) out.push(`- ${w}`);
  out.push('');
}

if (missing.length) {
  out.push(`<details><summary>Missing screenshot ids (${missing.length})</summary>`);
  out.push('');
  for (const id of missing.slice(0, 60)) out.push(`- \`${id}\``);
  if (missing.length > 60) out.push(`- …and ${missing.length - 60} more`);
  out.push('');
  out.push('</details>');
  out.push('');
}

out.push('<sub>Artifacts: `sf-screenshots` (the images) and `robot-results` (Robot log/report — the first place to look when a selector drifts).</sub>');

const md = out.join('\n');
if (process.env.GITHUB_STEP_SUMMARY) {
  try { fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, md + '\n'); }
  catch (e) { console.warn(`Could not write the step summary: ${e.message}`); }
}
console.log('\n' + md + '\n');

// Never fail the job from the reporter — the steps themselves own that.
process.exit(0);
