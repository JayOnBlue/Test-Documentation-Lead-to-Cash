# sf-docs-workflow-kit

The documentation + screenshot automation, packaged on its own — **no demo project, no sample
content**. Drop these files into any Salesforce DX repository (one with a `force-app/` folder)
to get:

- **Docs pipeline** — on every push to `main` touching `force-app/**`: regenerated technical
  reference, business-friendly changelog, technical version history, AI-drafted business docs
  (as a review PR), and a GitHub Pages site.
- **Screenshot workflow** — on demand, secretless (paste a short-lived org token at dispatch):
  captures every documented UI step as a real interaction and commits the images.

## What's in here

```
.github/workflows/
├── docs-pipeline.yml        push to main -> docs regeneration -> GitHub Pages
└── sf-screenshots.yml       on-demand secretless screenshot capture
docs/
├── README.md                client-facing guide to the whole system (edit to taste)
├── package.json             docs tooling dependencies (npm commands run from docs/)
├── business/TEMPLATE.md     page schema: sections, callouts, screenshot + diagram conventions
├── scripts/                 pipeline code — deterministic extractors, the one AI step, site builder
│   └── config.js            <- EDIT: site name, roles, glossary
├── capture/                 CumulusCI + Robot Framework capture harness + local control panel
└── images/                  captured screenshots land here (only thing capture ever commits)
.gitignore                   node_modules, docs/site, capture results
```

## Install into your repository

1. Copy everything above into your repo root (alongside your existing `force-app/` and
   `sfdx-project.json`). If you already have a `.gitignore`, merge the four lines instead of
   overwriting.
2. Edit `docs/scripts/config.js` — site name, roles, glossary.
3. One-time GitHub settings:
   - **Settings → Pages** → Build and deployment → Source → *GitHub Actions*.
   - **Settings → Actions → General → Workflow permissions** → *Read and write permissions* +
     check *Allow GitHub Actions to create and approve pull requests*.
   - Optional (enables the AI business-doc step): repo secret **`CLAUDE_CODE_OAUTH_TOKEN`**
     from `claude setup-token`. Everything else runs without it.
4. Push to `main`. The first run does a full baseline sweep of `force-app/` and deploys the site.

## Capture screenshots

Document a step with a ```` ```screenshot ```` block (see `docs/business/TEMPLATE.md`, including
the declarative `actions:` vocabulary), then either:

- **GitHub Actions**: Actions → *SF Screenshots* → Run workflow, pasting the token from
  `sf org display -o <alias>`. No stored secrets; the run masks the token, revokes the session
  on exit, and commits only `docs/images/`.
- **Locally**: `cd docs && npm run capture-panel` → one-click capture UI at `localhost:4322`.

Local capture prerequisites (once): `pip install -r docs/capture/requirements.txt && rfbrowser init`.

## Notes

- Node 22+ locally (the CI workflows pin it); the Salesforce CLI crashes on Node 20.
- The screenshot workflow's dispatch inputs are visible in run history to anyone with repo read
  access — accepted by design for private/single-maintainer repos, since the pasted token is
  short-lived and revoked at the end of every run. Details in the workflow header comment.
- Diagrams: ```` ```mermaid ```` blocks in business docs render as flowcharts/sequence diagrams
  on the site (CDN-loaded; the raw text stays visible if the CDN is unreachable).
