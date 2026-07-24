/**
 * Trigger handler for Opportunity: stage guard in before-update; big-deal flags and
 * discount review in after-update.
 */
public with sharing class OpportunityTriggerHandler {
    public static void beforeUpdate(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        if (TriggerControl.isBypassed('Opportunity')) return;
        OpportunityStageGuardService.enforce(opps, oldMap);
    }

    public static void afterUpdate(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        if (TriggerControl.isBypassed('Opportunity')) return;
        OpportunityForecastService.flagBigDeals(opps, oldMap);
        Set<Id> movedToNegotiation = new Set<Id>();
        for (Opportunity o : opps) {
            if (o.StageName == 'Negotiation/Review' && oldMap.get(o.Id).StageName != 'Negotiation/Review') {
                movedToNegotiation.add(o.Id);
            }
        }
        if (!movedToNegotiation.isEmpty()) OpportunityDiscountApprovalService.reviewDiscounts(movedToNegotiation);
    }
}
