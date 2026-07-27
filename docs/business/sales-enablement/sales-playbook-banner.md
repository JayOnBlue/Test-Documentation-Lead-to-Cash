---
title: "Sales Playbook Banner"
feature: "Sales Playbook Banner"
category: "Sales Enablement"
description: "A static reminder banner that reinforces the sales team's step-by-step playbook order directly on a Salesforce page."
verified: false
components:
  - "salesPlaybookBanner"
prerequisites:
  - "\"Customize Application\" permission (to add or remove the component in Lightning App Builder)"
  - "The banner component must be added to a Record, Home, or App page using Lightning App Builder before it is visible to any user"
related:
  - "rule-engine"
  - "quoting"
deprecated: false
replacement: ""
order: 10
slug: "sales-playbook-banner"
---

## Overview

The Sales Playbook Banner is a simple on-screen reminder that displays the recommended sales process order — qualify, price through the rule engine, quote, then order — at the top of a Salesforce page. It's meant to keep sales reps oriented on the correct sequence of steps while they work a deal, especially reps who are new to the process or prone to skipping a step (such as pricing before quoting). The banner is static: it does not read any record data, respond to clicks, or change based on context.

```callout
type: note
This component is not currently placed on any page in this org. An admin must add it to a Record, Home, or App page in Lightning App Builder before sales users will see it.
```

## Prerequisites

- "Customize Application" permission (to add or remove the component in Lightning App Builder)
- The banner component must be added to a Record, Home, or App page using Lightning App Builder before it is visible to any user

## Steps to Navigate

Only an admin adding or removing the banner needs to navigate Setup. Sales users simply see the banner at the top of whichever page it has been placed on — there is nothing for them to click or configure.

1. Click the gear icon in the top-right, then click **Edit Page** (while viewing the Record, Home, or App page you want to add the banner to).
2. In Lightning App Builder, drag the **Sales Playbook Banner** component from the Custom components list onto the page.
3. Click **Save**, then **Activate** if the page is not already active.

```screenshot
id: sales-playbook-banner-app-builder
alt: Lightning App Builder showing the Sales Playbook Banner component available in the Custom Components panel
step: Open Lightning App Builder for a page and locate the Sales Playbook Banner component in the components list
url_pattern: /lightning/app/AppLauncher
```

## Use Cases

The component has no branching logic — it always renders the same message regardless of the record, user, or app it's placed on. The scenarios below describe how it's used and removed, not variants in its behavior.

### Add the banner to a Record Page

1. Open any Opportunity (or other) record page in Lightning App Builder as described in Steps to Navigate.
2. Drag the **Sales Playbook Banner** component to the top of the page layout.
3. Save and activate the page.
4. Sales reps opening that record now see the alert banner reading: "Follow the sales playbook: qualify, price through the rule engine, quote, then order."

```screenshot
id: sales-playbook-banner-record-page
alt: Record page with the Sales Playbook Banner alert displayed at the top
step: View a record page that has the Sales Playbook Banner component placed on it
url_pattern: /lightning/r/Opportunity/{recordId}/view
```

### Remove or relocate the banner

1. Open the page in Lightning App Builder.
2. Click the banner component on the canvas, then click the delete (trash) icon to remove it, or drag it to a different position on the page.
3. Save and activate the page. The change takes effect immediately for all users of that page.

## Validations & Business Rules

- The component has no Apex controller, no wire adapters, and no configurable properties — it renders static markup only.
- Because it does not query or depend on any object, field, or record data, it introduces no validation rules or automation of its own.
- Visibility is controlled entirely by Lightning App Builder page assignment (and standard page/profile visibility rules for that page), not by any logic inside the component.

## Related Features

- Rule Engine — the pricing step the banner tells reps to use before quoting
- Quoting — the step that follows pricing in the playbook sequence referenced by the banner
