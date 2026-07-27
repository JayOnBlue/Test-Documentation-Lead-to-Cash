---
title: "Sales Playbook Banner"
feature: "Sales Playbook Banner"
category: "Sales Enablement"
description: "A static reminder banner an admin can place on any page to reinforce the standard sales process: qualify, price, quote, then order."
verified: false
prerequisites:
  - "'Customize Application' permission (or App Builder access) to add the component to a page"
related: []
deprecated: false
replacement: ""
order: 10
slug: "sales-playbook-banner"
---

## Overview

The Sales Playbook Banner is a simple reminder strip that admins can drop onto any Lightning page to keep
reps pointed at the standard sales process: qualify the opportunity, price it through the rule engine, send
a quote, then create the order. It doesn't read or write any data and has no settings — it always shows the
same reminder text, wherever it's placed.

## Prerequisites

- Access to Lightning App Builder (typically via the **'Customize Application'** permission) to add the component to a page
- Edit access to the specific record, Home, or app page where the banner should appear

## Steps to Navigate

1. Click the gear icon in the top-right, then click **Edit Page** (or open **Setup > Lightning App Builder** and edit the target page).
2. In the component palette on the left, find **Sales Playbook Banner** and drag it onto the page layout.
3. Click **Save**, then **Activate** if prompted, to make it visible to users.

```screenshot
id: sales-playbook-banner-home-page
alt: Sales Playbook Banner reminder strip shown at the top of a Home page
step: View a Home page that has the Sales Playbook Banner component placed on it
url_pattern: /lightning/page/home
```

## Use Cases

### Placed on a record page

1. An admin adds the banner to an Opportunity, Quote, or Order record page via Lightning App Builder.
2. Every rep who opens that record page sees the same reminder text at the top, regardless of the record's own data.

### Placed on the Home page

1. An admin adds the banner to a user's Home page.
2. The reminder appears every time that user lands on Home, independent of any record.

### Placed on a custom app page

1. An admin adds the banner to a custom Lightning app page (e.g. a Sales Ops dashboard app).
2. The reminder appears alongside whatever other components live on that app page.

## Validations & Business Rules

- The component is purely static display — it has no configurable properties, reads no fields, and triggers no automation.
- It renders identically everywhere it's placed; there is no logic that changes its text or appearance based on the record, user, or page.
- Because it has no data dependency, there is nothing for it to break — if the banner text needs to change, it requires an update to the component itself, not a configuration change.

## Related Features

- None yet — this is a standalone, informational-only component with no other business docs referencing it.
