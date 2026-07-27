---
title: "Sales Pipeline Dashboard"
feature: "Pipeline Dashboard"
category: "Sales Analytics"
description: "Gives sales users a live, read-only view of open pipeline value grouped by sales stage."
verified: false
prerequisites:
  - "Read access to the Opportunity object, including the Amount, Stage, and Account Name fields"
  - "The Pipeline Dashboard component must already be added to a Home, Record, or App page by an admin"
related: []
deprecated: false
replacement: ""
order: 10
slug: "sales-pipeline-dashboard"
components:
  - pipelineDashboard
  - SalesMetricsService
---

## Overview

The Pipeline Dashboard is a small card that shows how much open pipeline value sits in each sales
stage right now. It is meant for sales reps and managers who want a quick, at-a-glance read on
where deals are stacking up without running a report. An admin drops the component onto a Home
page, App page, or Opportunity record page in Lightning App Builder, and it loads automatically
whenever a user views that page — there is nothing for the end user to configure or click to
generate it.

```mermaid
flowchart LR
    Opp["All Opportunities"] --> Filter["Exclude closed deals"]
    Filter --> Group["Group remaining deals by Stage"]
    Group --> Sum["Add up Amount per stage"]
    Sum --> Card["Pipeline by Stage card"]
```

## Prerequisites

```callout
type: before
This is a display-only component. There is no setup screen inside the dashboard itself — placement
and layout are handled entirely by an admin in Lightning App Builder.
```

- Read access to the Opportunity object, including the Amount, Stage, and Account Name fields
- The Pipeline Dashboard component must already be added to a Home, Record, or App page by an admin

## Steps to Navigate

1. Open the Home page, App page, or Opportunity record page where an admin has placed the **Pipeline by Stage** card.
2. Look for the card titled **Pipeline by Stage** — it lists each open sales stage with its running total.

```screenshot
id: sales-pipeline-dashboard-view
alt: Pipeline by Stage card on a Home page listing open sales stages with their dollar totals
step: Open the Home page where the Pipeline Dashboard component is placed
url_pattern: /lightning/page/home
actions:
  - goto: /lightning/page/home
```

### Adding the dashboard to a page (admin)

1. Click the gear icon in the top-right, then click **Edit Page** (or open **Setup > Lightning App Builder** and edit an existing Home, App, or Record page).
2. Drag the **pipelineDashboard** component from the Custom Components list onto the page.
3. Click **Save**, then **Activate** if prompted, and assign the page to the appropriate app, profile, or record type.

```screenshot
id: sales-pipeline-dashboard-app-builder
alt: Lightning App Builder with the Pipeline Dashboard component dragged onto a Home page
step: Add the pipelineDashboard component to a page in Lightning App Builder
url_pattern: /lightning/setup/FlexiPageList/home
```

## Use Cases

### Reviewing pipeline at a glance

1. A sales manager opens the Home page where the dashboard is placed.
2. The card lists every stage that currently has open (not-closed) Opportunities, each with the summed Amount for that stage.
3. No filtering, sorting, or refresh action is needed — the list reflects live data every time the page loads.

### No open opportunities in scope

1. A rep with no visible open deals (or a brand-new org with no Opportunities yet) opens the page.
2. The **Pipeline by Stage** card title still appears, but the list underneath is empty since there are no stages to show.
3. This is expected behavior, not an error — it simply means there is nothing open in the pipeline that the user can see.

### Stage with no dollar amount recorded

1. If every open Opportunity in a given stage has a blank Amount, that stage's total sums to a blank value rather than zero.
2. Sales ops should treat a blank total as a data-quality signal — it means Amount was never filled in on those deals — rather than assuming the stage truly has $0 of pipeline.

### Viewing on different page types

1. The same card can appear on a Home page, an App page, or an Opportunity record page, since the component is exposed for all three.
2. On a record page, the totals shown are still org-wide (grouped by stage across all visible Opportunities) — they are not scoped to the specific record being viewed.

## Validations & Business Rules

- The underlying Apex class (`SalesMetricsService`) runs `with sharing`, so the totals only include Opportunities the logged-in user has access to see.
- Only Opportunities where `IsClosed = false` are counted — Closed Won and Closed Lost deals never appear in the stage totals.
- Stage totals are not filtered by Amount, so a stage where every deal has a blank Amount will sum to a blank total instead of showing $0.
- The Apex method is marked `cacheable=true`, so the Lightning Data Service may serve a cached result for a short time rather than querying fresh on every single page view.
- `SalesMetricsService` also exposes `topOpenDeals()` (top 10 open deals by Amount) and `leadCountBySource()` (open lead counts by source), but neither is currently wired into this dashboard component.

## Related Features

- Lightning App Builder placement (admin-configured; controls where this dashboard is visible)
