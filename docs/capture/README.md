# Screenshot capture with CumulusCI + Robot Framework (SalesforcePlaywright)

The **interaction-aware** capture harness — the approach Salesforce itself uses for testing.
It reads `../screenshot-manifest.json` (generated from the ```` ```screenshot ```` blocks in
`../business/**/*.md`) and captures every entry against a real org:

- Entries with an **`actions:` list** are replayed as real UI steps — the App Launcher actually
  opened, the search text actually typed, the New button actually clicked — so each image depicts
  the exact documented action.
- Entries with only a **`url_pattern`** are captured by direct navigation, with `{recordId}`
  resolved automatically via SOQL.

The suite is **100% manifest-driven**: adding a screenshot to the docs (one ```` ```screenshot ````
block, see `../business/TEMPLATE.md` for the action vocabulary) is all it takes — no test case,
selector, or workflow edit needed.

## Never captures a half-loaded page

Every navigation and action waits for `Wait For Lightning Ready`
(`robot/DocsProject/resources/DocsProject.resource`): CumulusCI's own loading wait, **then** a poll
until zero visible spinners *and* zero visible Lightning stencil skeletons (the grey placeholder
bars), **then** a settle delay. That three-stage gate is what makes captures consistent run to
run. Tune with `-o vars SETTLE:3s` if your org paints slowly.

## Two ways to run it

### 1. GitHub Actions (secretless) — `.github/workflows/sf-screenshots.yml`

Dispatch from the Actions tab, pasting a short-lived access token (mint with
`sf org display -o <alias>`). No stored secrets; the run masks the token, revokes the session on
exit, and commits **only** `docs/images/`. Robot's log/report is uploaded as the `robot-results`
artifact for debugging.

### 2. Local control panel

```bash
cd docs
npm run capture-panel
```

Opens **http://localhost:4322** automatically. Pick an org your `sf` CLI is already logged into
(no passkey/MFA), or log in to a new one right there, click **Capture & Build** — it captures,
rebuilds the site, and commits/pushes `docs/images/` using your own git credentials.

## One-time local setup

```bash
cd docs/capture

# 1) Install CumulusCI (brings Robot Framework + the Browser/SalesforcePlaywright libraries)
python -m pip install -r requirements.txt        # or: pipx install cumulusci

# 2) Install the Playwright browser binaries the Browser library uses
rfbrowser init
```

## Manual run (what the control panel / workflow do under the hood)

```bash
# Regenerate the manifest from the business docs
cd docs && node scripts/build-site.js

# Connect an already-authenticated sf CLI org to CumulusCI (no new login, no MFA)
cd capture
cci org import <sf alias/username> ci

# Capture (skips already-captured ids; add -o vars FORCE:True to redo everything)
cci task run capture_docs --org ci
```

Images are written to `../images/<screenshot-id>.png`; rebuild the site to see them inline.
Robot's own logs/report (the first place to look when a capture fails) land in
`robot/DocsProject/results/`.

## Deploy the demo metadata (once per org)

Deploy your app, tabs, and a docs-capture permission set granting the objects and tabs the screenshots need:

```bash
sf project deploy start --source-dir ../../force-app --target-org <org>
sf org assign permset --name Order_Management_Docs --target-org <org>
```

## Adding a new screenshot

Don't edit anything in this folder. Add a ```` ```screenshot ```` block (with `actions:` if the
step is an interaction) to the relevant page under `../business/` — the manifest, the capture
suite, and the site placeholder all pick it up automatically. The supported action verbs are
documented in `../business/TEMPLATE.md`.

## Notes

- Selectors live in `robot/DocsProject/resources/DocsProject.resource` (one place). They're the
  pragmatic style CumulusCI/Salesforce QA suites use (`button[title="App Launcher"]`, etc.);
  if one drifts with a Salesforce release, fix it there and every screenshot benefits.
- Keyword references: [CumulusCI/SalesforcePlaywright](https://cumulusci.readthedocs.io/en/stable/Keywords.html),
  [Browser (Playwright)](https://marketsquare.github.io/robotframework-browser/Browser.html).
