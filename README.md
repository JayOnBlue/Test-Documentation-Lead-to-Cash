# sf-docs-stress-test

A **standard-objects-only** Salesforce project built to stress-test the documentation
automation (`sf-docs-workflow-kit`): how well the pipeline documents genuinely complex,
interconnected code, and how long each stage takes. This folder deliberately contains **only
`force-app/` and its metadata** — combine it with the workflow kit to run the test.

## Why standard objects

Every object used — Account, Lead, Contact, Opportunity, Product2, Pricebook2,
OpportunityLineItem, Quote, QuoteLineItem, Order, OrderItem — is a Salesforce standard object.
That means:

- **Zero custom schema to deploy** — the code deploys onto any org's existing objects.
- **The screenshot workflow works against any org** — the Sales app, Leads/Opportunities/
  Orders tabs, and record pages all exist everywhere, so `screenshot` blocks with `actions:`
  (App Launcher, tabs, New forms, record pages) capture real UI without setup.

## What's inside (the lead-to-cash cycle, end to end)

| Domain | Highlights |
|---|---|
| **Lead** | Scoring matrix (firmographics + contact quality) → Rating; dedupe by email; round-robin assignment; auto-conversion of Hot leads; nurture batch + queueable; REST capture endpoint |
| **Account / Contact** | Revenue/headcount tiering; composite health score; territory matrix by geography; duplicate merge utility; primary contact-role hygiene |
| **Product / Pricing** | `PriceRuleEngine` — the single pricing brain (volume bands per family, tier discounts, strategic adjustments, margin floors, approval matrix); pricebook-entry sync; bundle expansion; retirement warnings |
| **Opportunity** | Stage-skip guard; products-before-Proposal and accepted-quote-before-Closed-Won gates; big-deal alerts; blended-discount approval; deep clone; stale-deal and pipeline-snapshot batches |
| **Quote** | Generation from opportunity (repriced through the rule engine); approval-gated presentation; accepted-quote price sync back to the opportunity; expiry batch; doc-gen queueable |
| **Order** | Quote→Order conversion; activation gate (lines + credit-check callout + tax estimate callout); fulfillment kickoff; margin-floor surveillance on order lines; renewal schedulable (bridges back into Opportunity); REST status/activation endpoint |
| **Cross-cutting** | `SalesOpsAuditService` (governance audit trail used by 3 domains), `RevenueRecognitionService` (bridges Order→finance), `CustomerLifecycleOrchestrator` (one-call lead-to-cash journey), `SalesMetricsService` (dashboard aggregates), nightly job scheduler |

Inventory: **66 Apex classes** (53 production + 13 tests), **9 triggers** (Lead, Account,
Contact, Product2, Opportunity, OpportunityLineItem, Quote, Order, OrderItem), **5
record-triggered Flows**, **5 LWCs** (4 wired to Apex, 1 deliberately Apex-free). The
dependency graph is intentionally dense — shared utilities, a pricing engine referenced by
three domains, and audit/renewal services that bridge otherwise-separate clusters.

## Run the stress test

1. Create a new GitHub repo containing this folder's contents **plus** the
   `sf-docs-workflow-kit` files (copy the kit's `.github/`, `docs/`, `.gitignore` in beside
   `force-app/` and `sfdx-project.json`).
2. Complete the kit's one-time setup (Pages source, workflow permissions, optional
   `CLAUDE_CODE_OAUTH_TOKEN`).
3. Push to `main` and measure.

**Where to read the timings** — Actions → the *Docs Pipeline* run → each step shows its
duration: metadata extraction, version history, the AI business-doc step (the long pole; it
fans out one call per feature cluster), changelog, site build. The run summary shows
end-to-end wall time for the baseline sweep. Then make a small change (edit 1–2 classes),
push again, and compare: the incremental run should only re-document the touched feature.

**Screenshot test** — after the docs pipeline publishes, dispatch *SF Screenshots* with a
token from any org (`sf org display -o <alias>`). The AI-authored pages target standard-object
UI, so captures work without deploying anything. To test the full UI including this project's
gates and LWCs, deploy first:

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

## Deploy prerequisites (only if you deploy the code)

- **Quotes must be enabled** (Setup → Quote Settings) — `QuoteTrigger` and the quote services
  won't deploy without it.
- Orders are enabled by default in most editions (Setup → Order Settings if not).
- The two callout classes reference named credentials `Credit_Bureau` and `Tax_Engine`;
  they deploy fine without them, but activation of large orders will fail the credit gate at
  runtime until the named credentials exist (or you deactivate that path).
- This is demo logic for pipeline testing — don't deploy to an org whose Leads/Opportunities/
  Orders you care about; the triggers really do convert hot leads and close stale deals.
