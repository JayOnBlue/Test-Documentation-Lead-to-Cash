# Documentation System

Everything documentation-related for this Salesforce project lives in this `docs/` folder.
The only automation files outside it are the two GitHub Actions workflow files in
`.github/workflows/`. The Salesforce source itself is in `force-app/` — the pipeline watches
it, never modifies it.

## What you get

A single documentation website (published on GitHub Pages) with four always-current sections,
regenerated automatically from the Salesforce codebase:

| Section | What it contains | How it's produced |
|---|---|---|
| **Business docs** | Plain-language feature & use-case guides with step-by-step navigation and screenshots | AI-drafted from code changes, human-reviewed via pull request |
| **Technical reference** | Every Apex class, trigger, object, field, Flow and LWC — with dependencies, impact analysis and coverage | Deterministic code analysis, no AI |
| **Changelog** | Release-style summary of every change (Added / Changed / Removed) | Deterministic, from git |
| **Version history** | Commit-by-commit timeline with technical + business summaries | Deterministic, from git |

## Folder structure

```
docs/
├── business/            The business documentation "database" — one Markdown file per feature.
│   └── TEMPLATE.md      The page schema + the screenshot block convention (start here to author).
├── technical/           Generated JSON: component graph (data.json) + version history (versions.json).
├── CHANGELOG.md         Generated changelog — the release data IS this file.
├── images/              Captured screenshots, one <screenshot-id>.png per documented step.
├── screenshot-manifest.json   Generated index of every screenshot block across the business docs —
│                        the single input the screenshot workflow reads.
├── _state/              Pipeline state (last documented commit) — enables incremental doc updates.
├── site/                Build output for GitHub Pages (git-ignored, rebuilt every run).
├── scripts/             All pipeline code (Node.js, no build step).
├── capture/             The screenshot capture harness (CumulusCI + Robot Framework + Playwright)
│                        and a local control panel (`npm run capture-panel`).
└── package.json         The docs tooling's npm manifest — run all npm commands from docs/.
```

## The two workflows

### 1. Documentation generation — `.github/workflows/docs-pipeline.yml`

Runs on every push/merge to `main` that touches `force-app/**` (and on demand).

1. Scans `force-app` and regenerates the technical reference, version history and changelog
   (all deterministic — same input, same output).
2. Asks AI to update **only** the affected business docs — it diffs against the last documented
   commit (`_state/progress.json`), so a 2-file commit updates just the docs for those 2 files,
   never the whole library. A brand-new repository gets a full baseline sweep automatically.
   AI-written prose always lands as a **pull request** for human review, never a direct commit.
3. Rebuilds the site and deploys it to GitHub Pages.

The workflow commits only Markdown and the generated JSON/Markdown indexes above — all code
(scripts, site shell) is prebuilt in the repository and never modified by automation.

### 2. Screenshot capture — `.github/workflows/sf-screenshots.yml`

Run on demand from the Actions tab. **No stored credentials**: you paste a short-lived
Salesforce access token when you trigger it (mint it locally with `sf org display -o <alias>`);
the run masks it, uses it, and revokes the session on exit.

It reads `screenshot-manifest.json` and captures every documented step against the org:

- Steps declared with `actions:` are **replayed as real UI interactions** — the App Launcher is
  actually opened, the search text actually typed, the New button actually clicked — so every
  image shows exactly the action the doc describes.
- Every capture waits until the page is fully rendered (spinners *and* Lightning's grey
  loading skeletons gone) before shooting, so images are consistent run to run.
- The only thing the workflow commits is `docs/images/`. Existing images are kept unless you
  tick *recapture*.

## How docs and screenshots link up

One convention connects everything. A business doc embeds a screenshot block at the step it
illustrates:

````markdown
```screenshot
id: order-lifecycle-app-launcher
alt: App Launcher open with "Orders" typed into the search box
step: Open the App Launcher and search for Orders
url_pattern: /lightning/app/AppLauncher
actions:
  - open_app_launcher
  - search_app_launcher: Orders
```
````

That single block is simultaneously: the **placeholder** on the site (shows "Screenshot
pending" until captured), the **capture instruction** (the `actions` are replayed verbatim),
and the **link** (the captured file `images/<id>.png` slots in automatically on the next site
build). Adding a screenshot to the documentation is just adding one of these blocks — no
workflow, script, or test changes needed. The full action vocabulary is documented in
[business/TEMPLATE.md](business/TEMPLATE.md).

## Running locally (optional)

```bash
cd docs
npm install
npm run build          # regenerate everything + build the site
# open docs/site/index.html in a browser — fully static, no server needed

npm run capture-panel  # local one-click screenshot capture UI (see capture/README.md)
```
