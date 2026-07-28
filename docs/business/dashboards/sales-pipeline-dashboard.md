---
title: "Sales Pipeline Dashboard"
feature: "Pipeline Dashboard"
category: "Dashboards"
description: "Shows sales reps a live breakdown of open Opportunity value grouped by sales stage on any Lightning page."
verified: false
components:
  - "pipelineDashboard (LWC)"
  - "SalesMetricsService (ApexClass)"
prerequisites:
  - "An admin must add the \"Pipeline Dashboard\" component to a Home, App, or Record page using Lightning App Builder"
  - "Read access to Opportunity records (the underlying Apex class runs \"with sharing\", so totals only include Opportunities the viewing user can see)"
related: []
deprecated: false
replacement: ""
order: 10
slug: "sales-pipeline-dashboard"
---

## Overview

The Pipeline Dashboard gives sales reps and managers an at-a-glance view of open pipeline without
having to build or open a report. It is a Lightning web component that an admin can drop onto any
Home, App, or Record page. Once placed, it queries all open (not-yet-closed) Opportunities and
displays the total Amount for each sales stage, so a rep can see where the team's open pipeline is
concentrated (for example, how much is sitting in "Negotiation/Review" versus "Prospecting").

```mermaid
flowchart LR
    Opp[Open Opportunity records] --> Query[Pipeline Dashboard queries open deals, grouped by stage]
    Query --> Card[Pipeline by Stage card renders on the page]
```

## Prerequisites

- An admin must add the "Pipeline Dashboard" component to a Home, App, or Record page using Lightning App Builder
- Read access to Opportunity records (the underlying Apex class runs "with sharing", so totals only include Opportunities the viewing user can see)

```callout
type: note
This component is not placed on any page by default. Until an admin adds it to a page layout, no user will see it.
```

## Steps to Navigate

1. As an admin, open the page you want to add the dashboard to (Home Page, App Page, or a Record Page) and click the gear icon, then **Edit Page** to open Lightning App Builder.
2. In the components panel on the left, find and drag the **Pipeline Dashboard** component onto the page.

```screenshot
id: sales-pipeline-dashboard-app-builder
alt: Lightning App Builder with the Pipeline Dashboard component dragged onto a Home page
step: Open Lightning App Builder for a Home page and drag the Pipeline Dashboard component onto the canvas
url_pattern: /lightning/app/AppLauncher
actions:
  - goto: /lightning/setup/FlexiPageList/home
```

3. Click **Save**, then **Activate** the page (and assign it to the relevant app/profile/record type) if it is not already active.
4. As a sales rep or manager, navigate to the page where the component was placed to view the **Pipeline by Stage** card.

```screenshot
id: sales-pipeline-dashboard-card
alt: Pipeline by Stage card showing a list of sales stages with the total open Amount for each
step: Open the page where the Pipeline Dashboard component is placed
url_pattern: /lightning/page/home
```

## Use Cases

### View open pipeline grouped by stage

1. Navigate to the page where the component has been placed (Home, App, or a Record page).
2. The **Pipeline by Stage** card loads and lists each stage name that has at least one open Opportunity, with the summed Amount for that stage next to it (for example, "Negotiation/Review: 125000").
3. Only Opportunities where `IsClosed` is false are included; closed-won and closed-lost deals never appear in these totals.

### No open pipeline to show

1. If there are no open Opportunities visible to the user (either because none exist or because sharing rules restrict visibility), the query returns no rows and the card shows no stage rows.
2. The card title ("Pipeline by Stage") still renders, but the list underneath is empty until open Opportunities the user can see exist.

### Viewing as a rep with restricted sharing

1. Because the Apex service class runs `with sharing`, a rep who does not have visibility into another rep's Opportunities will see stage totals that reflect only the deals they can access, not the full org-wide pipeline.
2. Managers or admins with broader sharing access (e.g. role hierarchy visibility into a whole team) will see higher totals for the same stage, since more Opportunities are included in their aggregate.

## Validations & Business Rules

- Only Opportunities with `IsClosed = false` are included in the stage totals; there is no separate validation rule involved, this is a query filter applied every time the component loads.
- Amounts with no value are excluded from the sum implicitly by the SOQL `SUM()` aggregate, so stages made up entirely of Opportunities with a blank Amount will not appear.
- All data access goes through `SalesMetricsService`, which is `@AuraEnabled(cacheable=true)` — results are cached client-side by the Lightning Data Service until the underlying Opportunity data changes, so a rep may need to refresh the page to see very recent updates reflected.
- The same `SalesMetricsService` class also exposes a `topOpenDeals()` method, which returns the 10 largest open Opportunities by Amount (with Name, Stage, and Account). This method exists and is ready to use, but the Pipeline Dashboard component currently in place does not call it or render a "Top Open Deals" list — only the stage-total breakdown is shown today.

## Related Features

- Big Deal Alert (notifies when an individual Opportunity crosses a large deal-size threshold) is a related but separate automation from this dashboard's stage totals.
