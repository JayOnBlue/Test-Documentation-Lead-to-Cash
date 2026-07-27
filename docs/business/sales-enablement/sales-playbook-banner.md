---
title: "Sales Playbook Banner"
feature: "Sales Playbook Banner"
category: "Sales Enablement"
description: "A static reminder banner admins can place on Lightning pages to reinforce the standard sales playbook sequence."
verified: false
components:
  - "salesPlaybookBanner"
prerequisites:
  - "\"Customize Application\" or App Builder access to edit Lightning record, home, or app pages"
related:
  - "quote-rule-engine-pricing"
deprecated: false
replacement: ""
order: 10
slug: "sales-playbook-banner"
---

## Overview

The Sales Playbook Banner is a small Lightning component that displays a fixed reminder message —
"Follow the sales playbook: qualify, price through the rule engine, quote, then order." — to reinforce
the standard sales process. Sales managers and enablement teams use it as an always-visible nudge on
the pages reps work from most, so the correct order of operations (qualify the lead, price through the
rule engine, generate a quote, then create the order) stays top of mind. It has no configuration options
and does not read or write any record data — it is purely a static message that an admin drops onto a page
in Lightning App Builder.

```callout
type: note
This component is available in the org but is not currently placed on any Lightning page. An admin must
add it via App Builder for it to appear to users.
```

## Prerequisites

- "Customize Application" permission or equivalent App Builder access
- A Lightning record, Home, or App page to edit (the component supports all three page types)

## Steps to Navigate

1. Navigate to the Lightning page where the banner should appear (a record page, the Home page, or an app page).
2. Click the gear icon in the top-right, then click **Edit Page** to open Lightning App Builder.

```screenshot
id: sales-playbook-banner-app-builder
alt: Lightning App Builder open on a record page with the component list visible on the left
step: Open Lightning App Builder for the target page
url_pattern: /lightning/setup/FlexiPageList/home
```

3. In the components list on the left, find **Sales Playbook Banner** and drag it onto the page canvas in the desired location (commonly the top of the page).

```screenshot
id: sales-playbook-banner-placed
alt: Sales Playbook Banner component placed at the top of a record page showing the playbook reminder text
step: Drag the Sales Playbook Banner component onto the page and save
url_pattern: /lightning/setup/FlexiPageList/home
```

4. Click **Save**.
5. If prompted, click **Activate** to set page assignment (org default, app default, or specific record types/profiles).
6. Navigate to the page as an end user to confirm the banner displays.

## Use Cases

### Add the banner to a record page

1. Open a record page (e.g. an Opportunity or Lead record page) in App Builder as described above.
2. Drag **Sales Playbook Banner** to the top of the layout so it's visible before any other content.
3. Save and activate. Every user who views that record page and record type/profile assignment now sees
   the static reminder text.

### Add the banner to a Home or App page

1. Open the Home page or an app page (e.g. the Sales app's default landing page) in App Builder.
2. Drag **Sales Playbook Banner** onto the page.
3. Save and activate for the appropriate app, profile, or org default. Since Home and App pages aren't
   tied to a specific record, this surfaces the reminder to reps as soon as they land in the app, rather
   than only when they open a specific record.

### Remove the banner

1. Open the page in App Builder where the banner was placed.
2. Click the component on the canvas to select it, then click the trash/delete icon to remove it.
3. Save and activate. The reminder text no longer displays to users of that page.

## Validations & Business Rules

- The component contains no Apex, no Lightning Message Service usage, and no configurable properties —
  the displayed text is fixed in the component markup and can only be changed by editing the component source.
- There are no validation rules or automation tied to this component; it does not read, write, or
  validate any record field. It is purely presentational.
- Because it is not referenced by any Flow, Apex class, or other component, it only has an effect on
  users once an admin explicitly places it on a page via App Builder.

## Related Features

- Works well alongside the quote-to-order process (qualify → price via the rule engine → quote → order)
  that the banner text reminds reps to follow.
