---
title: "Quote Generation, Approval Gating & Expiry"
feature: "Quote Approval & Expiry"
category: "Quotes"
description: "Gates quote presentation on discount approval, syncs accepted prices back to the opportunity, generates a quote document, and expires quotes left unanswered."
verified: false
prerequisites:
  - "Standard User (or higher) profile with access to Quotes"
  - "Quotes must be enabled on the Opportunity (Quotes related list) for reps to create them"
related:
  - "opportunity-pipeline-guardrails"
  - "order-activation-fulfillment"
order: 10
slug: "quote-generation-approval"
---

## Overview

Reps generate quotes from an opportunity using Salesforce's standard Quote creation, which mirrors the
opportunity's line items and pricing. From there, the system takes over: presenting a quote with too large a
discount is blocked until a discount-approval task is completed, accepting a quote syncs its prices back onto
the opportunity and triggers a document-generation task, and a nightly job automatically expires any quote
that's been sitting in Presented status past its expiration date.

```mermaid
flowchart LR
    Draft -->|Present| Gate{Discount over\napproval threshold?}
    Gate -->|"No"| Presented
    Gate -->|"Yes, no completed\napproval task"| Blocked[Blocked — stays Draft]
    Presented -->|Customer accepts| Accepted
    Presented -->|Past expiration\n(nightly job)| Denied["Denied (expired)"]
    Accepted --> Sync[Prices sync to Opportunity]
    Accepted --> PDF[Quote document task created]
```

## Prerequisites

- Standard User (or higher) profile with access to Quotes
- Quotes enabled on the Opportunity Products related list so a Quote can be created from an Opportunity
- A completed Task with a Subject starting **"Discount approval"** on the quote, if its discount requires approval — see [[opportunity-pipeline-guardrails]] for how that task gets created

## Steps to Navigate

1. Open an Opportunity that has one or more Opportunity Product lines.
2. In the **Quotes** related list, click **New Quote**.
3. Confirm the pricebook and line items, then click **Save**.
4. Open the new Quote record and review the **Quote Line Items**.

```screenshot
id: quote-generation-new-quote
alt: New Quote form opened from an Opportunity's Quotes related list
step: Open an Opportunity, go to the Quotes related list, and click New Quote
url_pattern: /lightning/r/Opportunity/{recordId}/view
actions:
  - open_record: Opportunity
```

## Use Cases

### Browse quotable opportunities

1. An admin adds the **Quotable Opportunities** component to a Home page, record page, or app page.
2. Anyone viewing that page sees up to 25 open opportunities that already have line items, most recently modified first, as a reference list of Name — Stage (Amount).
3. This component is read-only — it doesn't create the quote itself; use the standard **New Quote** action from the Opportunity's Quotes related list for that.

```screenshot
id: quote-generation-quotable-opportunities
alt: Quotable Opportunities component listing open opportunities with line items
step: Open a Home page that has the Quotable Opportunities component added
url_pattern: /lightning/page/home
```

### Present a quote (standard, no approval needed)

1. Open a Draft quote whose blended discount (versus list price across all lines) is under 30%, or under 20% on a quote worth $100,000 or less.
2. Change **Status** to **Presented** and click **Save**.
3. The save succeeds immediately — no approval task is required.

### Present a quote with a large discount (blocked pending approval)

1. Open a Draft quote whose blended discount is over 30%, or over 20% and the quote total is over $100,000.
2. Change **Status** to **Presented** and click **Save**.
3. The save is blocked with: **"This quote's discount ({pct}%) needs a completed approval task first."**
4. The block is also logged as an audit note (see [[nightly-sales-operations]]).

### Complete the discount approval task and re-present

1. Sales ops locates the **"Discount approval needed"** task created on the related opportunity (see [[opportunity-pipeline-guardrails]]) and marks it **Completed** after reviewing the deal.
2. The rep re-opens the quote and changes **Status** to **Presented** again.
3. This time the save succeeds, since a completed Task with a Subject starting "Discount approval" now exists on the quote.

### Customer accepts the quote

1. Open a Presented quote and change **Status** to **Accepted**, then click **Save**.
2. Every Opportunity line whose product matches an accepted quote line has its **Unit Price** updated to match the quote's accepted price (only where the price actually differs).
3. A Task **"Quote document generated: {Quote Name}"** is created (already Completed) noting the total and expiration date — standing in for the actual PDF/document.
4. The opportunity can now be moved to Closed Won, since it has an Accepted quote (see [[opportunity-pipeline-guardrails]]).

```screenshot
id: quote-generation-accepted-status
alt: Quote record showing Status set to Accepted
step: Change a Presented quote's Status to Accepted and save
url_pattern: /lightning/r/Quote/{recordId}/view
```

### Quote expires unaddressed

1. A quote sits in **Presented** status past its **Expiration Date** (set 30 days out when the quote was generated).
2. Every night, a batch job finds these quotes, flips **Status** to **Denied** (this org's "expired" state), and creates a Task **"Quote expired — requote: {Quote Name}"** due in 2 days for the quote owner.
3. The rep sees the requote task and either builds a fresh quote or follows up with the customer.

## Validations & Business Rules

- Automation: `QuoteTriggerHandler` before-update runs the discount-approval gate whenever Status is changing to `Presented`; after-update runs price sync and document generation whenever Status just changed to `Accepted`.
- Validation: presenting a quote is blocked with **"This quote's discount ({pct}%) needs a completed approval task first."** when the blended discount exceeds 30%, or exceeds 20% on a quote over $100,000, and no completed Task with Subject starting "Discount approval" exists on the quote.
- Blended discount is calculated as `(1 - sum(UnitPrice × Quantity) / sum(ListPrice × Quantity)) × 100` across all quote lines.
- Automation: accepting a quote updates matching Opportunity line Unit Prices to the accepted quote price, and creates a completed "Quote document generated" task recording the total and expiration date.
- Automation: a nightly batch job (see [[nightly-sales-operations]]) sets any `Presented` quote past its Expiration Date to `Denied` and creates a "Quote expired — requote" task for the owner, due in 2 days.
- Quotes are generated with a default **Expiration Date** of 30 days from creation and start in **Draft** status.

```callout
type: warning
Denied is used in this org as the "expired" status for quotes, not necessarily a rejection by the customer —
support should confirm with the rep whether a Denied quote expired on its own or was actually turned down before
assuming which one happened.
```

## Related Features

- [[opportunity-pipeline-guardrails]] — supplies the discount-approval task this page's presentation gate checks for, and requires an Accepted quote before Closed Won.
- [[order-activation-fulfillment]] — an Accepted quote is the starting point for creating an Order.
