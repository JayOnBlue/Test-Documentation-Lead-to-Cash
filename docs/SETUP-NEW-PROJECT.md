# Setting this pipeline up on another Salesforce project

Everything here is portable. Nothing in the pipeline is specific to this org: the
technical reference, changelog and version history are derived from whatever is in
`force-app/`, and the business docs are written from that same metadata. There is no
project name, object name or org id hard-coded anywhere outside `cumulusci.yml`.

## 1. Copy these files into the new repository

Exactly this set — 36 files. Keep the paths identical, because the scripts locate each
other relative to the repository root.

```
.gitignore                                  ← keeps node_modules/site/robot results out of git
cumulusci.yml                               ← MUST be at the repo root (CumulusCI requirement)
.github/workflows/docs-pipeline.yml         ← docs generation + Pages deploy
.github/workflows/sf-screenshots.yml        ← screenshot capture (manual dispatch)

docs/package.json                           ← docs tooling manifest
docs/package-lock.json                      ← copy BOTH so `npm ci` is reproducible
docs/README.md                              ← how the pipeline works (worth keeping)
docs/business/TEMPLATE.md                   ← the page schema the AI writes against
docs/images/.gitkeep                        ← keeps the (initially empty) images dir

docs/scripts/extract-technical.js           ← component graph from force-app
docs/scripts/generate-version-history.js
docs/scripts/generate-changelog.js
docs/scripts/build-site.js
docs/scripts/author-business-docs.mjs       ← the one AI step
docs/scripts/config.js                      ← site name + glossary (EDIT THIS, see §3)
docs/scripts/lib/discover.js
docs/scripts/lib/impact.js
docs/scripts/lib/util.js
docs/scripts/lib/context-pack.js
docs/scripts/lib/claude-runner.mjs
docs/scripts/lib/run-report.js
docs/scripts/site-assets/index.html         ← the site shell
docs/scripts/site-assets/app.js
docs/scripts/site-assets/styles.css

docs/capture/requirements.txt               ← CumulusCI + Robot Browser pins
docs/capture/report.mjs                     ← capture run report
docs/capture/server.mjs                     ← optional local control panel
docs/capture/control.html                   ← optional local control panel
docs/capture/package.json
docs/capture/README.md
docs/capture/robot/DocsProject/tests/docs_capture.robot
docs/capture/robot/DocsProject/resources/DocsProject.resource
docs/capture/robot/DocsProject/resources/DocsCapture.py
```

### Do NOT copy

These are this project's *output*, and copying them would seed the new project with the
wrong content or a state file that lies about what has been documented:

```
docs/business/**/*.md   (except TEMPLATE.md)   ← the other project's pages
docs/technical/                                ← regenerated on the first run
docs/CHANGELOG.md                              ← regenerated on the first run
docs/_state/                                   ← progress markers + content-hash cache
docs/screenshot-manifest.json                  ← regenerated on the first run
docs/site/                                     ← build output
docs/node_modules/                             ← `npm ci` recreates it
force-app/                                     ← the new project brings its own
```

## 2. Two settings and one secret

| What | Where | Why |
|---|---|---|
| **Pages source = GitHub Actions** | Settings → Pages → Build and deployment | otherwise the deploy step has nowhere to publish |
| **Allow GitHub Actions to create and approve pull requests** | Settings → Actions → General → Workflow permissions (and the same box in your **account** settings if the repo is user-owned) | the AI docs land as a reviewed PR |
| **`CLAUDE_CODE_OAUTH_TOKEN`** secret | Settings → Secrets and variables → Actions | generate locally with `claude setup-token` (Pro/Max plan). Without it the AI step skips with a warning and everything else still runs |

`permissions:` in the workflow already requests `contents: write` / `pull-requests: write`,
so you do **not** need to switch the default token to "Read and write".

## 3. Three edits

1. **`cumulusci.yml`** — set `project: name:` and `package: name:` to the new project.
   Leave the `capture_docs` task alone; its paths are already repo-root relative.
2. **`docs/scripts/config.js`** — set `siteName`, and the `glossary` / `roleCategories`
   if you want project-specific terms and audience filters on the site.
3. **`docs/capture/robot/DocsProject/tests/docs_capture.robot`** — nothing to change for
   a normal run. `${BROWSER}` must stay `headlesschrome` for CI.

That is the whole configuration surface. Everything else discovers itself from
`force-app/`.

## 4. First run

1. Push to `main` with anything under `force-app/` changed (or run the workflow manually).
   The first run treats every component as new, so expect it to take longer than later
   runs — it plans and writes the whole documentation set. Later runs only touch what
   changed.
2. Review and merge the pull request it opens on the `docs-business-updates` branch. Until
   that merge the pages are published to the site marked "Auto-generated" but are not part
   of `main`.
3. Screenshots are a separate, manual step: Actions → **SF Screenshots** → Run workflow,
   pasting a fresh org access token (`sf org display --target-org <alias> --json`, then the
   `accessToken` field) and the org's My Domain URL.

## 5. Screenshot capture: the one thing that needs org-side attention

The capture suite is driven entirely by the ````screenshot```` blocks the AI writes into
the business docs, so it needs no test authoring. What it does need is for the org to
*contain* what the docs describe — an `open_record: Order` action needs an Order to exist.
On a fresh org, expect a first capture run to report missing screenshots for records that
aren't there yet; the run report lists them individually by id.

Read the security caveat at the top of `sf-screenshots.yml` before the first capture:
the access token is a `workflow_dispatch` input, and **on a public repository those are
recorded in the run log in cleartext**. Either make the repository private, move the token
to a secret, or treat every pasted token as burned after use.
