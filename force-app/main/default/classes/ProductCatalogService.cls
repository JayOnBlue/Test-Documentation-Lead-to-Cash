/**
 * Catalog lifecycle: normalizes product codes on the way in, and retires products safely —
 * a product with open pipeline can be deactivated but the owning reps get a Task so
 * nothing dies silently mid-deal.
 */
public with sharing class ProductCatalogService {
    public static void normalizeProductCodes(List<Product2> products) {
        for (Product2 p : products) {
            if (String.isNotBlank(p.ProductCode)) {
                p.ProductCode = p.ProductCode.trim().toUpperCase().replaceAll('\\s+', '-');
            }
            if (String.isBlank(p.Family)) p.Family = 'General';
        }
    }

    public static void warnOpenPipelineOnRetirement(List<Product2> deactivated) {
        Set<Id> productIds = new Map<Id, Product2>(deactivated).keySet();
        List<OpportunityLineItem> exposed = [
            SELECT Id, OpportunityId, Opportunity.OwnerId, Product2Id
            FROM OpportunityLineItem
            WHERE Product2Id IN :productIds AND Opportunity.IsClosed = false];
        Map<Id, Task> taskByOpp = new Map<Id, Task>();
        for (OpportunityLineItem line : exposed) {
            if (!taskByOpp.containsKey(line.OpportunityId)) {
                taskByOpp.put(line.OpportunityId, new Task(
                    Subject = 'Product on this deal was retired — swap or requote',
                    WhatId = line.OpportunityId, OwnerId = line.Opportunity.OwnerId,
                    ActivityDate = Date.today().addDays(3), Status = 'Not Started'));
            }
        }
        if (!taskByOpp.isEmpty()) insert taskByOpp.values();
    }
}
