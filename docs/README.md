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
├── _state/              Pipeline state. progress.json holds two independent progress markers —
│                        lastChangelogCommit (changelog) and lastAuthoredCommit (AI step), so a
│                        skipped/failed AI run never loses queued work to the changelog advancing —
│                        plus a per-component content-hash cache. run-report.json is the last AI
│                        run's metrics (calls, tokens, cache hits, cost, failures).
├── site/                Build output for GitHub Pages (git-ignored, rebuilt every run).
├── scripts/             All pipeline code (Node.js, no build step).
├── capture/             The screenshot capture harness (CumulusCI + Robot Framework + Playwright)
│                        and a local control panel (`npm run capture-panel`).
└── package.json         The docs tooling's npm manifest — run all npm commands from docs/.
```

## The two workflows

### 1. Documentation generation — `.github/workflows/docs-pipeline.yml`

Runs on every push/merge to `main` that touches `force-app/**` or `docs/business/**` (and on
demand). The `docs/business/**` trigger is what re-deploys the site after an AI business-doc PR
is merged — that merge touches nothing under `force-app/`.

1. Scans `force-app` and regenerates the technical reference, version history and changelog
   (all deterministic — same input, same output).
2. Asks AI to update **only** the affected business docs (see below). AI-written prose always
   lands as a **pull request** for human review, never a direct commit.
3. Rebuilds the site and deploys it to GitHub Pages.

The workflow commits only Markdown and the generated JSON/Markdown indexes above — all code
(scripts, site shell) is prebuilt in the repository and never modified by automation.

#### How the AI step is structured (and why)

The AI step is the only part of this pipeline whose cost grows with the codebase — the
deterministic steps finish in about a second even on a large org. Its first production run took
**23 minutes for 85 components**: one sequential loop of six calls, of which a single 60-file call
took 12.7 minutes on its own, and every call re-derived facts the pipeline had already computed.
It is now four stages, and the expensive one runs in parallel:

| Stage | Model? | What it does |
|---|---|---|
| **0. Triage** | no | Drops what can never be user-facing (test classes, `-meta.xml` sidecars, non-behavioral config), then drops anything whose **normalized** source hash is unchanged since it was last documented. Comment and whitespace edits cost zero calls. |
| **1. Plan** | yes, parallel | Components are bin-packed into a few calls that return **JSON only** — create / update / skip per page, with the components each page covers. Small output, so these are fast. |
| **2. Write** | yes, parallel | **One call per page**, never per batch of files. Each call owns exactly one file, which is what makes parallelism safe — two workers can never write the same page. |
| **3. Verify** | no | Frontmatter parses, required sections present, nothing written outside `docs/business/`. A page that fails is not recorded as done, so the next run retries it. |

Two things make the model calls cheaper rather than just more numerous:

- **A context pack replaces agentic search.** `docs/technical/data.json` already holds the call
  graph, so each prompt is handed the component's methods, callers (excluding tests), callees,
  entry points (`@AuraEnabled`, `@RestResource`, `Schedulable`, trigger, LWC) and the exact path of
  the page that already documents it. The old prompt made the agent grep the repo to answer all of
  that — on one call it grepped every LWC, flow and trigger just to conclude "dead code".
- **Prompts are ordered static-content-first.** Prompt caching matches on an exact prefix, so the
  fixed preamble (template, rules, output schema) comes first and the per-call payload last. The
  pool also runs its first call alone before fanning out, because a cache entry only becomes
  readable once the first response has begun — firing N cold calls at once guarantees N misses.
  `--exclude-dynamic-system-prompt-sections` keeps per-machine details (cwd, git status) out of the
  cached prefix so separate CLI processes can share it.

Progress is tracked **per component**, not by a single commit pointer, so a partial failure
re-queues only the components that actually failed.

Every run writes `_state/run-report.json` and a table to the GitHub Actions run summary: per-call
status, duration, turns, token usage, cache-hit rate and cost, plus what triage filtered out and
how much faster the parallel run was than the same work serially. Tool **permission denials** are
reported too — a non-zero count means an agent wanted a tool the allowlist refused, which is what
stalled the original 60-file call.

Tuning knobs (environment variables on the workflow step): `DOCS_AI_CONCURRENCY` (default 4 —
subscription rate limits, not correctness, are the ceiling), `DOCS_PLAN_BATCH` (components per
planning call, default 40), `DOCS_MAX_PAGES` (pages per run, default 200 — the overflow drains on
later runs), `DOCS_AI_TIMEOUT_MS` (per-call wall clock, default 10 min) and `CLAUDE_CLI_BIN`
(absolute path to the CLI, or a stub for testing). Bump `PROMPT_VERSION` in
`scripts/author-business-docs.mjs` after editing a prompt — it is part of the cache key, so raising
it correctly invalidates previously generated pages.

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
