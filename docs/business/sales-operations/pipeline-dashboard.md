---
title: "Pipeline by Stage Dashboard"
feature: "Pipeline by Stage Dashboard"
category: "Sales Operations"
description: "A live, at-a-glance card showing total open Opportunity value grouped by sales stage, for a Home, App, or record page."
verified: false
prerequisites:
  - "Read access to Opportunities (Amount, Stage, Account Name)"
  - "An admin must add the component to a Home Page, App Page, or Record Page in Lightning App Builder before it appears"
related:
  - "opportunity-pipeline-guardrails"
  - "nightly-jobs-and-audit-trail"
deprecated: false
replacement: ""
order: 20
slug: "pipeline-dashboard"
---

## Overview

The Pipeline by Stage dashboard gives sales managers and reps a live, at-a-glance read of how much open
Opportunity value sits in each sales stage, right on a Home Page, App Page, or record page — no report to
run or filter. It queries the current open pipeline fresh from a Lightning component every time the page
loads, rather than relying on a report someone has to remember to check. This is distinct from the nightly
Pipeline Snapshot logged as a Task (see Nightly Sales Ops Jobs & Audit Trail), which is a once-a-day,
point-in-time log entry rather than a live view.

## Prerequisites

- Read access to Opportunities and their Amount, Stage, and Account Name fields
- An admin must add the **Pipeline by Stage** component to a Home Page, App Page, or Record Page using Lightning App Builder — it isn't visible anywhere until placed on a page

## Steps to Navigate

1. As an admin, click the gear icon in the top-right and click **Edit Page** on the Home, App, or record page where the dashboard should appear (or go to **Setup > Lightning App Builder**).
2. Drag the **Pipeline by Stage** component from the Custom Components list onto the page.
3. Click **Save**, then **Activate** the page if it isn't already active.

```screenshot
id: pipeline-dashboard-app-builder
alt: Lightning App Builder with the Pipeline by Stage component added to a Home page
step: Open Lightning App Builder on a Home Page and add the Pipeline by Stage component
url_pattern: /lightning/setup/FlexiPageList/home
```

4. Any user with access to that page navigates to it to see the **Pipeline by Stage** card.

```screenshot
id: pipeline-dashboard-card
alt: Pipeline by Stage card listing each open sales stage with its total Opportunity Amount
step: View the Pipeline by Stage card on the page where it was added
url_pattern: /lightning/page/home
actions:
  - goto: /lightning/page/home
```

## Use Cases

### Viewing pipeline totals at a glance

1. A sales manager opens the Home Page (or App Page) where the Pipeline by Stage card has been placed.
2. The card lists each sales stage that currently has open Opportunities, alongside the total Amount of open
   deals sitting in that stage — refreshed from live data each time the page loads.

### A stage temporarily has no open deals

1. Every open Opportunity moves out of a given stage (won, lost, or advanced), so no open Opportunity remains
   in it.
2. That stage's row simply disappears from the card — it does not show a $0 line — until a deal is open in
   that stage again.

### An admin adds the dashboard to a new page

1. An admin opens Lightning App Builder on a Home Page, App Page, or record page that doesn't yet have the
   component.
2. They drag **Pipeline by Stage** onto the page, save, and activate it.
3. The card starts showing live open-pipeline totals to anyone who can access that page — no additional setup
   (no custom permission, no data load) is required beyond normal Opportunity read access.

## Validations & Business Rules

- **Only open Opportunities count:** the totals are filtered to `IsClosed = false`; Closed Won and Closed Lost
  deals are excluded entirely.
- **A stage only appears if it has open deals:** the underlying query groups by stage, so a stage with zero
  open Opportunities is absent from the list rather than shown at zero.
- **Totals sum Amount per stage:** Opportunities with a blank Amount don't contribute to their stage's total
  (standard SOQL aggregate behavior — `SUM` ignores nulls).
- **Read-only:** the card has no buttons or inline edit — Stage and Amount can only be changed on the
  Opportunity record itself (see Opportunity Pipeline Guardrails).
- **Cached data:** the underlying Apex methods are marked `cacheable=true`, so the Lightning Data Service may
  briefly serve a cached result — a stage change or Amount edit made moments ago may not appear until the
  wire cache refreshes or the page is reloaded.
- The same Apex class also computes a top-10 open-deals list and a lead-count-by-source breakdown, but as of
  this writing only the by-stage totals are wired into a visible component — those two aggregates aren't yet
  surfaced on any page.

## Related Features

- Opportunity Pipeline Guardrails — the stage-transition and Amount rules that determine what these totals reflect.
- Nightly Sales Ops Jobs & Audit Trail — logs a once-nightly, point-in-time snapshot of the same open-pipeline-by-stage totals as an unattached Task, in contrast to this component's live view.
