/**
 * Quote-level discount governance. A quote whose blended discount crosses the
 * PriceRuleEngine matrix cannot be sent (Status -> Presented is blocked) until an
 * approval Task exists and is completed. Approvals and rejections are audited.
 */
public with sharing class QuoteApprovalService {
    public static void gatePresentation(List<Quote> quotes, Map<Id, Quote> oldMap) {
        Set<Id> presenting = new Set<Id>();
        for (Quote q : quotes) {
            if (q.Status == 'Presented' && oldMap.get(q.Id).Status != 'Presented') presenting.add(q.Id);
        }
        if (presenting.isEmpty()) return;

        Map<Id, Decimal> discountByQuote = blendedDiscountFor(presenting);
        Map<Id, Quote> quoteRecords = new Map<Id, Quote>([SELECT Id, Name, OwnerId, GrandTotal FROM Quote WHERE Id IN :presenting]);
        Set<Id> approved = quotesWithCompletedApproval(presenting);

        List<String> auditNotes = new List<String>();
        for (Quote q : quotes) {
            if (!presenting.contains(q.Id)) continue;
            Decimal discount = discountByQuote.containsKey(q.Id) ? discountByQuote.get(q.Id) : 0;
            Quote record = quoteRecords.get(q.Id);
            if (PriceRuleEngine.requiresApproval(discount, record.GrandTotal) && !approved.contains(q.Id)) {
                q.addError('This quote\'s discount (' + discount + '%) needs a completed approval task first.');
                auditNotes.add('Blocked presentation of ' + record.Name + ' at ' + discount + '%');
            }
        }
        if (!auditNotes.isEmpty()) SalesOpsAuditService.record('QuoteApproval', auditNotes);
    }

    public static Map<Id, Decimal> blendedDiscountFor(Set<Id> quoteIds) {
        Map<Id, Decimal> listTotal = new Map<Id, Decimal>();
        Map<Id, Decimal> soldTotal = new Map<Id, Decimal>();
        for (QuoteLineItem line : [SELECT QuoteId, ListPrice, UnitPrice, Quantity FROM QuoteLineItem WHERE QuoteId IN :quoteIds]) {
            Decimal listAmt = (line.ListPrice == null ? 0 : line.ListPrice) * line.Quantity;
            Decimal soldAmt = (line.UnitPrice == null ? 0 : line.UnitPrice) * line.Quantity;
            listTotal.put(line.QuoteId, (listTotal.containsKey(line.QuoteId) ? listTotal.get(line.QuoteId) : 0) + listAmt);
            soldTotal.put(line.QuoteId, (soldTotal.containsKey(line.QuoteId) ? soldTotal.get(line.QuoteId) : 0) + soldAmt);
        }
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        for (Id quoteId : listTotal.keySet()) {
            Decimal listAmt = listTotal.get(quoteId);
            if (listAmt > 0) out.put(quoteId, ((1 - soldTotal.get(quoteId) / listAmt) * 100).setScale(2));
        }
        return out;
    }

    public static Set<Id> quotesWithCompletedApproval(Set<Id> quoteIds) {
        Set<Id> out = new Set<Id>();
        for (Task t : [SELECT WhatId FROM Task WHERE WhatId IN :quoteIds
                       AND Subject LIKE 'Discount approval%' AND Status = 'Completed']) {
            out.add(t.WhatId);
        }
        return out;
    }

    public static Set<Id> opportunitiesWithAcceptedQuote(Set<Id> opportunityIds) {
        Set<Id> out = new Set<Id>();
        for (Quote q : [SELECT OpportunityId FROM Quote
                        WHERE OpportunityId IN :opportunityIds AND Status = 'Accepted']) {
            out.add(q.OpportunityId);
        }
        return out;
    }
}
