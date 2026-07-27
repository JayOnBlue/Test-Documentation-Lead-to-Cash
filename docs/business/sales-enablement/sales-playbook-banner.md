---
title: "Sales Playbook Banner"
feature: "Sales Playbook Banner"
category: "Sales Enablement"
description: "Displays a persistent reminder banner that prompts sales reps to follow the standard qualify, price, quote, order playbook."
verified: false
prerequisites:
  - "\"Customize Application\" permission (or App Builder access) to add the component to a page"
related: []
deprecated: false
replacement: ""
order: 10
slug: "sales-playbook-banner"
components:
  - "salesPlaybookBanner"
---

## Overview

The Sales Playbook Banner is a small alert-style banner that reminds sales users of the standard
sales process: qualify the opportunity, price it through the rule engine, generate a quote, then
create the order. An administrator adds it to a Home, App, or Record page in Lightning App Builder
so it's visible to reps as they work, keeping the correct sequence of steps top of mind.

```callout
type: note
This banner is purely informational — it displays static text and does not read or write any
record data. It has no configurable properties.
```

## Prerequisites

- "Customize Application" permission (or equivalent App Builder access) to add the component to a page
- A Lightning Home, App, or Record page that is active and assigned to the relevant app or profile

## Steps to Navigate

1. Click the gear icon in the top-right, then click **Edit Page** (or open **Setup > Lightning App Builder** and select the target page).
2. In the Lightning App Builder component palette, find **Sales Playbook Banner** under the Custom - Managed/Unmanaged components list.
3. Drag the component onto the desired region of the page layout.
4. Click **Save**, then **Activate** if the page is not already active, and confirm the assignment (org default, app default, or specific app/record type/profile) as needed.

```screenshot
id: sales-playbook-banner-app-builder
alt: Lightning App Builder canvas with the Sales Playbook Banner component dragged onto a Home page
step: Add the Sales Playbook Banner component to a page in Lightning App Builder
url_pattern: /lightning/setup/FlexiPageList/home
```

Once activated, the banner appears automatically to any user who opens that page — no further
action is required from end users.

```screenshot
id: sales-playbook-banner-live-view
alt: Home page showing the Sales Playbook Banner alert reminding reps to qualify, price, quote, then order
step: Open the Home page where the banner has been added
url_pattern: /lightning/page/home
```

## Use Cases

### Reinforcing the sales process on the Home page

1. An admin places the banner on the Sales app Home page.
2. Reps see the reminder — "Follow the sales playbook: qualify, price through the rule engine,
   quote, then order" — every time they log in or return to Home, reinforcing the intended sequence
   before they jump into an Opportunity.

### Reinforcing the process on an Opportunity record page

1. An admin instead (or additionally) places the banner on the Opportunity Record Page layout.
2. Reps see the same reminder directly on the record they're working, at the point where they might
   be tempted to skip a step (for example, creating a Quote before pricing has gone through the rule
   engine).

## Validations & Business Rules

- The component contains no Apex, no Lightning Message Service usage, and no Apex/wire calls — it is
  a static template with fixed text.
- There is no logic to dismiss, personalize, or conditionally hide the banner; visibility is
  controlled entirely by which pages an admin adds it to and any standard App Builder page filters.

## Related Features

- None — this component does not interact with other Lead-to-Cash features; it only displays guidance text.
