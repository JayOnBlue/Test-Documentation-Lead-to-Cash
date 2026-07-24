/**
 * Discount governance on opportunities: when the blended discount across lines crosses
 * the PriceRuleEngine approval matrix, an approval Task goes to the owner's manager path
 * and the request is recorded with SalesOpsAuditService.
 */
public with sharing class OpportunityDiscountApprovalService {
    public static void reviewDiscounts(Set<Id> opportunityIds) {
        Map<Id, List<OpportunityLineItem>> linesByOpp = new Map<Id, List<OpportunityLineItem>>();
        for (OpportunityLineItem line : [SELECT Id, OpportunityId, ListPrice, UnitPrice, TotalPrice
                                         FROM OpportunityLineItem WHERE OpportunityId IN :opportunityIds]) {
            if (!linesByOpp.containsKey(line.OpportunityId)) linesByOpp.put(line.OpportunityId, new List<OpportunityLineItem>());
            linesByOpp.get(line.OpportunityId).add(line);
        }
        Map<Id, Opportunity> opps = new Map<Id, Opportunity>([SELECT Id, Name, Amount, OwnerId FROM Opportunity WHERE Id IN :opportunityIds]);

        List<Task> approvals = new List<Task>();
        List<String> auditNotes = new List<String>();
        for (Id oppId : linesByOpp.keySet()) {
            Decimal listTotal = 0, soldTotal = 0;
            for (OpportunityLineItem line : linesByOpp.get(oppId)) {
                if (line.ListPrice != null) listTotal += line.ListPrice * (line.TotalPrice == null || line.UnitPrice == 0 ? 1 : line.TotalPrice / line.UnitPrice);
                if (line.TotalPrice != null) soldTotal += line.TotalPrice;
            }
            if (listTotal == 0) continue;
            Decimal blendedDiscount = ((1 - soldTotal / listTotal) * 100).setScale(2);
            Opportunity opp = opps.get(oppId);
            if (PriceRuleEngine.requiresApproval(blendedDiscount, opp.Amount)) {
                approvals.add(new Task(Subject = 'Discount approval needed (' + blendedDiscount + '%): ' + opp.Name,
                    WhatId = oppId, OwnerId = opp.OwnerId, ActivityDate = Date.today().addDays(1),
                    Status = 'Not Started', Priority = 'High'));
                auditNotes.add('Discount ' + blendedDiscount + '% requested on ' + opp.Name);
            }
        }
        if (!approvals.isEmpty()) insert approvals;
        if (!auditNotes.isEmpty()) SalesOpsAuditService.record('DiscountApproval', auditNotes);
    }
}
