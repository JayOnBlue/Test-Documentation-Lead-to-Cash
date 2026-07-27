# Changelog

Generated from force-app metadata changes on every push to main. Newest first (each release is prepended).

## v4 — 2026-07-27 — 4e6d44d

**Contributors:** JayOnBlue, github-actions[bot]

**Compare:** [81a1ca8...4e6d44d](https://github.com/JayOnBlue/Test-Documentation-Lead-to-Cash/compare/81a1ca8...4e6d44d)

**Technical summary:** Changed 1 (1 ApexClass).

**Business summary:** No mapped business feature yet (not yet clustered into a Feature).

### Changed

- **ApexClass** `AccountMergeUtility`

## v3 — 2026-07-27 — d191644

**Contributors:** JayMalde, JayOnBlue, github-actions[bot]

**Compare:** [494dc91...d191644](https://github.com/JayOnBlue/Test-Documentation-Lead-to-Cash/compare/494dc91...d191644)

**Technical summary:** Changed 1 (1 ApexClass).

**Business summary:** Likely affects: Account Health Score & related.

**Business features:** Account Health Score & related

### Changed

- **ApexClass** `AccountHealthScoreService`

## v2 — 2026-07-24 — 494dc91

**Contributors:** JayOnBlue, github-actions[bot]

**Compare:** [2cbaf62...494dc91](https://github.com/JayOnBlue/Test-Documentation-Lead-to-Cash/compare/2cbaf62...494dc91)

**Technical summary:** Changed 1 (1 ApexClass).

**Business summary:** Likely affects: Account Health Score & related.

**Business features:** Account Health Score & related

### Changed

- **ApexClass** `AccountHealthScoreService`

## v1 — 2026-07-24 — 2cbaf62

**Contributors:** JayMalde

**Technical summary:** Added 85 (66 ApexClass, 5 Flow, 5 LightningComponentBundle, 9 ApexTrigger).

**Business summary:** Likely affects: Account Health Score & related, Trigger Control & related, Opportunity Clone & related, Product & related, Sales Metrics & related.

**Business features:** Account Health Score & related, Trigger Control & related, Opportunity Clone & related, Product & related, Sales Metrics & related

### Added

- **ApexClass** `AccountHealthScoreService`
- **ApexClass** `AccountHealthScoreServiceTest`
- **ApexClass** `AccountMergeUtility`
- **ApexClass** `AccountTerritoryService`
- **ApexClass** `AccountTierService`
- **ApexClass** `AccountTierServiceTest`
- **ApexClass** `AccountTriggerHandler`
- **ApexClass** `CollectionUtils`
- **ApexClass** `ContactRoleSyncService`
- **ApexClass** `ContactTriggerHandler`
- **ApexClass** `CreditCheckCalloutService`
- **ApexClass** `CustomerLifecycleOrchestrator`
- **ApexClass** `CustomerLifecycleOrchestratorTest`
- **ApexClass** `LeadAssignmentService`
- **ApexClass** `LeadCaptureRestResource`
- **ApexClass** `LeadConversionService`
- **ApexClass** `LeadConversionServiceTest`
- **ApexClass** `LeadDedupeService`
- **ApexClass** `LeadNurtureBatch`
- **ApexClass** `LeadNurtureQueueable`
- **ApexClass** `LeadScoringService`
- **ApexClass** `LeadScoringServiceTest`
- **ApexClass** `LeadTriggerHandler`
- **ApexClass** `MarginCalculationService`
- **ApexClass** `NightlyPipelineJobsSchedulable`
- **ApexClass** `OpportunityCloneService`
- **ApexClass** `OpportunityDiscountApprovalService`
- **ApexClass** `OpportunityForecastService`
- **ApexClass** `OpportunityLineItemTriggerHandler`
- **ApexClass** `OpportunityPricingService`
- **ApexClass** `OpportunityPricingServiceTest`
- **ApexClass** `OpportunityStageGuardService`
- **ApexClass** `OpportunityStageGuardServiceTest`
- **ApexClass** `OpportunityTriggerHandler`
- **ApexClass** `OrderActivationService`
- **ApexClass** `OrderActivationServiceTest`
- **ApexClass** `OrderFromQuoteService`
- **ApexClass** `OrderFromQuoteServiceTest`
- **ApexClass** `OrderFulfillmentService`
- **ApexClass** `OrderItemTriggerHandler`
- **ApexClass** `OrderRenewalSchedulable`
- **ApexClass** `OrderStatusRestResource`
- **ApexClass** `OrderTriggerHandler`
- **ApexClass** `PipelineSnapshotBatch`
- **ApexClass** `PriceRuleEngine`
- **ApexClass** `PriceRuleEngineTest`
- **ApexClass** `PricebookSyncService`
- **ApexClass** `PricebookSyncServiceTest`
- **ApexClass** `ProductBundleService`
- **ApexClass** `ProductCatalogService`
- **ApexClass** `ProductTriggerHandler`
- **ApexClass** `QuoteApprovalService`
- **ApexClass** `QuoteExpiryBatch`
- **ApexClass** `QuoteGenerationService`
- **ApexClass** `QuoteGenerationServiceTest`
- **ApexClass** `QuoteLineSyncService`
- **ApexClass** `QuoteLineSyncServiceTest`
- **ApexClass** `QuotePdfQueueable`
- **ApexClass** `QuoteTriggerHandler`
- **ApexClass** `RevenueRecognitionService`
- **ApexClass** `SalesMetricsService`
- **ApexClass** `SalesOpsAuditService`
- **ApexClass** `StaleOpportunityBatch`
- **ApexClass** `TaxCalculationCalloutService`
- **ApexClass** `TriggerControl`
- **ApexClass** `ValidationUtils`
- **Flow** `Big_Deal_Alert`
- **Flow** `Lead_Followup_Reminder`
- **Flow** `Order_Activation_Confirmation`
- **Flow** `Product_Retirement_Notice`
- **Flow** `Quote_Expiry_Alert`
- **LightningComponentBundle** `leadScorecard`
- **LightningComponentBundle** `orderTracker`
- **LightningComponentBundle** `pipelineDashboard`
- **LightningComponentBundle** `quoteBuilder`
- **LightningComponentBundle** `salesPlaybookBanner`
- **ApexTrigger** `AccountTrigger`
- **ApexTrigger** `ContactTrigger`
- **ApexTrigger** `LeadTrigger`
- **ApexTrigger** `OpportunityLineItemTrigger`
- **ApexTrigger** `OpportunityTrigger`
- **ApexTrigger** `OrderItemTrigger`
- **ApexTrigger** `OrderTrigger`
- **ApexTrigger** `ProductTrigger`
- **ApexTrigger** `QuoteTrigger`

