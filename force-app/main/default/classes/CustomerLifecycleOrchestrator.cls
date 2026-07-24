/**
 * End-to-end journey helper gluing the domains together: qualify the lead, price the deal,
 * quote it, and order it — in one call each. Exists so integration tests (and admins in
 * anonymous Apex) can drive the full lead-to-cash path without touching six services.
 */
public with sharing class CustomerLifecycleOrchestrator {
    public static Id qualifyAndConvert(Id leadId) {
        Lead l = [SELECT Id, Rating, IsConverted FROM Lead WHERE Id = :leadId];
        List<Database.LeadConvertResult> results = LeadConversionService.convertQualified(new List<Lead>{ l });
        return results.isEmpty() || !results[0].isSuccess() ? null : results[0].getOpportunityId();
    }

    public static Id priceAndQuote(Id opportunityId) {
        OpportunityPricingService.repriceOpportunities(new Set<Id>{ opportunityId });
        return QuoteGenerationService.generateFromOpportunity(opportunityId);
    }

    public static Id acceptAndOrder(Id quoteId) {
        TriggerControl.bypass('Quote');
        update new Quote(Id = quoteId, Status = 'Accepted');
        TriggerControl.clearBypass('Quote');
        QuoteLineSyncService.syncAcceptedQuotes([SELECT Id, OpportunityId FROM Quote WHERE Id = :quoteId]);
        return OrderFromQuoteService.createOrder(quoteId);
    }
}
