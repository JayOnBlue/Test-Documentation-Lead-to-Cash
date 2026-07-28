---
title: "Sales Playbook Banner"
feature: "Sales Playbook Banner"
category: "Sales Enablement"
description: "Shows a static reminder banner that walks sales reps through the recommended qualify, price, quote, order sequence."
verified: false
prerequisites:
  - "'Customize Application' permission to add or remove the component using Lightning App Builder"
  - "Component must be placed on a Home, App, or Record page by an admin before it is visible to users"
related: []
deprecated: false
replacement: ""
order: 10
slug: "sales-playbook-banner"
components:
  - "salesPlaybookBanner"
---

## Overview

The Sales Playbook Banner is a lightweight reminder that admins can drop onto any Home, App, or record
page to reinforce the recommended sales process: **qualify, price through the rule engine, quote, then
order**. It has no configurable fields or logic of its own — it simply renders a static alert banner
wherever it is placed, keeping the correct sequence visible to reps as they work.

## Prerequisites

```callout
type: before
This component ships in the org but is **not placed on any page by default**. It only appears once an
admin adds it to a Home, App, or Record page using Lightning App Builder.
```

- 'Customize Application' permission (to edit pages in Lightning App Builder)
- A Home, App, or Record page to place the component on

## Steps to Navigate

1. Click the gear icon in the top-right, then click **Edit Page** (or open **Setup** > **Lightning App
   Builder** and select the page to edit).
2. In the component palette on the left, search for **Sales Playbook Banner**.
3. Drag the component onto the desired region of the page.
4. Click **Save**, then **Activate** if prompted, to make the page (and banner) visible to the intended
   users.

```screenshot
id: sales-playbook-banner-app-builder
alt: Lightning App Builder with the Sales Playbook Banner component dragged onto a page
step: Open Lightning App Builder for a page and drag the Sales Playbook Banner component onto it
url_pattern: /lightning/setup/FlexiPageList/home
```

```screenshot
id: sales-playbook-banner-rendered
alt: Sales Playbook Banner rendered as an alert banner on a Lightning page reminding users to qualify, price, quote, then order
step: View a page where the Sales Playbook Banner has been placed and activated
url_pattern: /lightning/n/Home
```

## Use Cases

### Add the banner to a page

1. An admin edits a Home, App, or Record page in Lightning App Builder.
2. The admin drags the Sales Playbook Banner onto a region of the page and saves/activates it.
3. Any user who opens that page now sees the alert banner reading "Follow the sales playbook: qualify,
   price through the rule engine, quote, then order."

### Remove the banner from a page

1. An admin edits the page in Lightning App Builder.
2. The admin selects the Sales Playbook Banner component and removes it (or drags it off the page).
3. The admin saves the page. The banner no longer appears for users viewing that page.

## Validations & Business Rules

- The component has no configurable properties, Apex controller, or automation — the banner text is
  fixed and identical everywhere it is placed.
- Because it is not placed on any page out of the box, it will not appear anywhere in the org until an
  admin explicitly adds it via Lightning App Builder.

## Related Features

- Works well alongside the Quote, Order, and pricing rule engine features it references, reminding reps
  of the intended qualify → price → quote → order sequence.
