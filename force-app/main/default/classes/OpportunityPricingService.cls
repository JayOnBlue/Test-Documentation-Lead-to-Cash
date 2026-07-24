/**
 * Reprices an opportunity's line items through PriceRuleEngine — used when lines are
 * added and when sales asks for a fresh price via the quote builder.
 */
public with sharing class OpportunityPricingService {
    public static Integer repriceOpportunities(Set<Id> opportunityIds) {
        List<OpportunityLineItem> lines = [
            SELECT Id, Quantity, ListPrice, UnitPrice, OpportunityId,
                   Opportunity.AccountId, PricebookEntry.Product2.Family
            FROM OpportunityLineItem WHERE OpportunityId IN :opportunityIds];
        if (lines.isEmpty()) return 0;

        Map<Id, String> tierByAccount = new Map<Id, String>();
        for (OpportunityLineItem line : lines) {
            if (line.Opportunity.AccountId != null && !tierByAccount.containsKey(line.Opportunity.AccountId)) {
                tierByAccount.put(line.Opportunity.AccountId, PriceRuleEngine.accountTierFor(line.Opportunity.AccountId));
            }
        }
        List<OpportunityLineItem> updates = new List<OpportunityLineItem>();
        for (OpportunityLineItem line : lines) {
            if (line.ListPrice == null || line.ListPrice == 0) continue;
            PriceRuleEngine.PriceResult result = PriceRuleEngine.price(new PriceRuleEngine.PriceContext(
                line.ListPrice, line.Quantity, line.PricebookEntry.Product2.Family,
                tierByAccount.get(line.Opportunity.AccountId)));
            if (result.unitPrice != line.UnitPrice) {
                updates.add(new OpportunityLineItem(Id = line.Id, UnitPrice = result.unitPrice));
            }
        }
        if (!updates.isEmpty()) {
            TriggerControl.bypass('OpportunityLineItem');
            update updates;
            TriggerControl.clearBypass('OpportunityLineItem');
        }
        return updates.size();
    }
}
