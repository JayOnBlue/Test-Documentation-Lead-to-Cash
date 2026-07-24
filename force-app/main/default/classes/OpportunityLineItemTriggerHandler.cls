/**
 * Trigger handler for OpportunityLineItem: newly added lines trigger a reprice of the
 * whole opportunity so stacked volume bands stay correct as quantity accumulates.
 */
public with sharing class OpportunityLineItemTriggerHandler {
    public static void afterInsertOrUpdate(List<OpportunityLineItem> lines) {
        if (TriggerControl.isBypassed('OpportunityLineItem')) return;
        Set<Id> oppIds = CollectionUtils.extractIds(lines, 'OpportunityId');
        if (!oppIds.isEmpty()) OpportunityPricingService.repriceOpportunities(oppIds);
    }
}
