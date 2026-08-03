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
function decodeEntities(text) {
  return String(text)
    // Numeric character references first: Robot writes Playwright's box-drawing frame
    // as &#9484;&#9472;… and without decoding them the filter below cannot recognise
    // the frame, so the "cause" line came out as a row of entity codes.
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'").replace(/&amp;/g, '&');
}

function firstUsefulLines(text, max = 2) {
  const lines = decodeEntities(text)
    .split('\n')
    .map((l) => l.trim())
    // Drop blank lines, bare "...:" headers, and Playwright's box-drawing frame.
    .filter((l) => l && !/^[A-Za-z][\w '-]*:$/.test(l) && !/^[│┌└─┐┘|+=-]+$/.test(l))
    .map((l) => l.replace(/^[│|]\s*/, '').replace(/\s*[│|]$/, '').trim())
    .filter(Boolean);
  return lines.slice(0, max).join(' — ').slice(0, 300) || '(no message; see the Robot report artifact)';
}

/**
 * A capture test runs every screenshot with Run Keyword And Continue On Failure, so its
 * message is Robot's "Several failures occurred:" list — one numbered entry per screenshot.
 * Printing the first two lines of that hid the shape of the problem: 21 identical readiness
 * timeouts read as a single mysterious error. Group identical causes and count them.
 */
function summariseTestFailure(raw) {
  const text = decodeEntities(raw);
  if (!/Several failures occurred/i.test(text)) return firstUsefulLines(raw);
  const items = text
    .split(/^\s*\d+\)\s*/m)
    .slice(1)
    .map((item) => item.split('\n').map((l) => l.trim()).filter(Boolean)[0] || '')
    .filter(Boolean);
  if (!items.length) return firstUsefulLines(raw);
  const groups = new Map();
  for (const item of items) {
    // Collapse the varying parts (counts, timings) so "1 spinner" and "6 spinner" group.
    const key = item.replace(/\d+/g, 'N');
    groups.set(key, (groups.get(key) || 0) + 1);
  }
  const parts = [...groups.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([cause, n]) => `${n}× ${cause.slice(0, 160)}`);
  const shown = [...groups.values()].slice(0, 3).reduce((a, b) => a + b, 0);
  if (groups.size > 3) parts.push(`…and ${items.length - shown} more`);
  return `${items.length} screenshot(s) failed — ${parts.join('; ')}`;
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
      // Take the test's OWN status, which is its LAST <status> — the ones before it belong
      // to nested keywords, including failures that were caught and handled. Taking the
      // first match reported `'/_ui/...' does not contain '{recordId}'` as the cause of a
      // run whose real problem was 21 readiness timeouts: that message came from a
      // Should Contain inside Run Keyword And Return Status, i.e. a deliberate probe.
      const statuses = [...body.matchAll(/<status\b[^>]*\bstatus="(\w+(?: \w+)?)"[^>]*(?:\/>|>([\s\S]*?)<\/status>)/g)];
      const own = statuses[statuses.length - 1];
      if (!own || own[1] !== 'FAIL') return null;
      return { name, message: summariseTestFailure(own[2] || '') };
    })
    .filter(Boolean);

  // Screenshots skipped because the org has no record of the required object. A data gap,
  // not a code or selector problem, so it gets its own section: the fix is creating a
  // record, and no amount of re-running will change the outcome without one.
  const noRecord = [...new Set(
    [...xml.matchAll(/Skipping ([\w-]+) [^<]*?(?:no sample record|had nothing to act on)/g)].map((m) => m[1]),
  )];

  // Diagnoses must be read from MESSAGES and STATUSES only. Robot also writes every
  // keyword's <arg> values and <doc> text into output.xml — including those of IF branches
  // that never ran — so scanning the raw file made the 2026-07-30 run report a frontdoor
  // login failure that never happened: the text came from the arguments of a Catenate in an
  // unexecuted branch.
  const evidence = xml.replace(/<arg>[\s\S]*?<\/arg>/g, ' ').replace(/<doc>[\s\S]*?<\/doc>/g, ' ');
  // Known root causes worth naming outright, so nobody has to read Playwright's
  // box-drawing error art to work out what to change.
  const diagnoses = [];
  if (/Missing X server|without having a XServer|\$DISPLAY/i.test(evidence)) {
    diagnoses.push('Playwright tried to launch a HEADED browser and the runner has no display. ' +
      'CumulusCI picks headless purely from the `${BROWSER}` variable — it must start with "headless" ' +
      '(e.g. `headlesschrome`). Check the `${BROWSER}` default in docs_capture.robot.');
  }
  if (/viewport\.\w+: expected integer, got string|newContext:.*expected integer/i.test(evidence)) {
    diagnoses.push('Playwright rejected the browser context because the viewport was passed as strings. ' +
      'CumulusCI\'s own `Open Test Browser` does this (it splits "WIDTHxHEIGHT" and forwards the parts ' +
      'unconverted), so the suite must build the context itself — see `Open Docs Browser` in ' +
      'DocsProject.resource and the &{VIEWPORT} variable, whose values must be ${int} not plain text.');
  }
  if (/Timed out waiting for a lightning page/i.test(evidence)) {
    diagnoses.push('CumulusCI waited for Salesforce to redirect frontdoor.jsp to a `/lightning/` URL and it ' +
      'never did — where frontdoor lands depends on the user\'s default app and UI setting. The suite now ' +
      'requests the destination explicitly (`frontdoor.jsp?...&retURL=/lightning/page/home`) and judges ' +
      'readiness from the Lightning app shell in the DOM. If you still see this, the org config is stale.');
  }
  if (/Still loading: \d+ spinner\/stencil/i.test(evidence)) {
    diagnoses.push('One or more pages never reached "zero visible spinners", so the readiness gate gave up on ' +
      'them. This is expected on some Salesforce pages (a chart still fetching, a polling related list) and is ' +
      'no longer fatal — `Wait For Lightning Ready` now captures anyway and logs the shortfall. If a captured ' +
      'image genuinely looks half-rendered, raise ${ARTIFACT_TIMEOUT} or narrow ${LOADING_ARTIFACTS}.');
  }
  if (/locator\.click: Timeout|element is outside of the viewport/i.test(evidence)) {
    diagnoses.push('A click timed out. If the log says "element is outside of the viewport", the button was ' +
      'present but Playwright would not click it — `Click Doc Element` scrolls it into view and, failing that, ' +
      'dispatches a DOM click. If instead the selector never resolved, the button genuinely is not on that ' +
      'page: check the action verb and its label in the screenshot block that names it.');
  }
  if (/locator\.fill: Timeout|Could not find a field for/i.test(evidence)) {
    diagnoses.push('A `fill_field` action named a field the form does not have. This is a DOCS-vs-ORG ' +
      'mismatch, not a timing problem: `fill_field` needs the field API NAME (LastName, Amount), the field ' +
      'must be on that page layout for this user, and a picklist such as Lead.Rating is chosen from a ' +
      'combobox rather than typed. Fix the `fill_field` action in the screenshot block named in the message.');
  }
  if (/is not in the navigation bar/i.test(evidence)) {
    diagnoses.push('A `click_tab` action named a tab that the app does not have in its navigation bar. Note ' +
      '"Related" and "Details" are tabs INSIDE a record page, not app tabs — those need an `open_record` ' +
      'action plus a click, not `click_tab`. Fix the screenshot block named in the message.');
  }
  const suiteSetupDied = /(?:Parent s|S)uite setup failed/i.test(evidence);
  if (suiteSetupDied && /got multiple values for argument|expected \d+ argument|No keyword with name/i.test(evidence)) {
    diagnoses.push('This is a KEYWORD SIGNATURE bug in the capture suite itself, not an org, token or ' +
      'selector problem — Robot could not bind the arguments given to a keyword. Nothing was captured ' +
      'because suite setup died. Reproduce it in seconds without a real org, and without spending a CI ' +
      'run, with: `python -m robot --outputdir /tmp/st docs/capture/selftest/login_selftest.robot`. ' +
      '(A frequent cause: `Log`/`Fail` take (message, level=…) / (message, *tags), so multi-line ' +
      'continuations become extra POSITIONAL arguments — catenate them into one string first.)');
  }
  if (/strict mode violation/i.test(evidence)) {
    diagnoses.push('A selector matched MORE THAN ONE element and Playwright runs in strict mode, which rejects ' +
      'that instead of picking the first. The error text lists every element it matched. Fix the selector in ' +
      'DocsProject.resource by appending `>> nth=0` (as the other capture keywords do), or count with ' +
      '`Get Element Count`, which is not a strict operation. This is not an org or data problem.');
  }
  if (/Frontdoor login (did not reach|never reached)/i.test(evidence)) {
    diagnoses.push('The browser did not land on a `/lightning/` path — the failure message names the page title ' +
      'and URL it reached. A login screen there means the pasted access token is not usable for browser login ' +
      '(expired, or the org restricts session reuse): mint a fresh one and re-dispatch.');
  }
  if (/Suite setup failed|Parent suite setup failed/i.test(evidence) && !diagnoses.length) {
    diagnoses.push('The suite SETUP failed, so no capture was even attempted — every screenshot is missing ' +
      'for one shared reason (browser launch, login URL, or org connection), not because of individual selectors.');
  }
  if (/INVALID_AUTH_HEADER|Expired session/i.test(evidence)) {
    diagnoses.push('The org session was rejected. If the token itself is valid, check that the org config ' +
      'handed to CumulusCI has a real access_token (a redacted `sf org display` value causes exactly this).');
  }
  if (/INVALID_SESSION_ID/i.test(evidence)) {
    diagnoses.push('The Salesforce session expired mid-run — mint a fresh access token and re-dispatch.');
  }
  const base = stat
    ? { pass: +stat[1], fail: +stat[2], skip: +(stat[3] || 0) }
    : { pass: 0, fail: 0, skip: 0 };
  return { ...base, failedTests, diagnoses, noRecord };
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
if (images.length && missing.length) warnings.push(`${missing.length} of ${wanted.length} requested screenshots are still missing (the docs render a "Screenshot pending" placeholder for each). The ${images.length} captured so far are COMMITTED, so the next run skips them and works only on these — no need to re-dispatch with recapture.`);
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

if (robot && robot.noRecord?.length) {
  out.push(`### 📄 Skipped — the org has no record to show (${robot.noRecord.length})`);
  out.push('');
  out.push('These are **data gaps, not bugs**: the documentation describes a record page, and the org has no');
  out.push('record of that object to open. Re-running changes nothing until one exists — create a sample');
  out.push('record (or deploy the demo data) and re-dispatch.');
  out.push('');
  for (const id of robot.noRecord) out.push(`- \`${id}\``);
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
