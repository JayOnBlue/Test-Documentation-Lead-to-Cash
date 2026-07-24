/**
 * Monthly renewal factory: activated orders older than ~11 months spawn a renewal
 * opportunity (deep-cloned from the source opportunity when one exists) so the pipeline
 * always contains next year's revenue.
 */
public with sharing class OrderRenewalSchedulable implements Schedulable {
    public void execute(SchedulableContext ctx) {
        List<Order> expiring = [SELECT Id, OpportunityId FROM Order
                                WHERE Status = 'Activated' AND EffectiveDate <= :Date.today().addDays(-330)
                                LIMIT 50];
        for (Order o : expiring) {
            if (o.OpportunityId != null) {
                OpportunityCloneService.deepClone(o.OpportunityId, null);
            }
        }
    }
}
