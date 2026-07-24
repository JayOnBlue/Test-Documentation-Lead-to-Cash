/**
 * When a quote is Accepted, its line prices become the deal's truth: every matching
 * opportunity line (same pricebook entry) is updated to the accepted quote-line price,
 * and the opportunity amount follows.
 */
public with sharing class QuoteLineSyncService {
    public static void syncAcceptedQuotes(List<Quote> quotes) {
        Map<Id, Id> oppByQuote = new Map<Id, Id>();
        for (Quote q : quotes) {
            if (q.OpportunityId != null) oppByQuote.put(q.Id, q.OpportunityId);
        }
        if (oppByQuote.isEmpty()) return;

        Map<Id, Map<Id, QuoteLineItem>> quoteLinesByOpp = new Map<Id, Map<Id, QuoteLineItem>>();
        for (QuoteLineItem line : [SELECT Id, QuoteId, PricebookEntryId, UnitPrice, Quantity
                                   FROM QuoteLineItem WHERE QuoteId IN :oppByQuote.keySet()]) {
            Id oppId = oppByQuote.get(line.QuoteId);
            if (!quoteLinesByOpp.containsKey(oppId)) quoteLinesByOpp.put(oppId, new Map<Id, QuoteLineItem>());
            quoteLinesByOpp.get(oppId).put(line.PricebookEntryId, line);
        }

        List<OpportunityLineItem> oppLineUpdates = new List<OpportunityLineItem>();
        for (OpportunityLineItem oppLine : [SELECT Id, OpportunityId, PricebookEntryId, UnitPrice
                                            FROM OpportunityLineItem WHERE OpportunityId IN :quoteLinesByOpp.keySet()]) {
            Map<Id, QuoteLineItem> accepted = quoteLinesByOpp.get(oppLine.OpportunityId);
            QuoteLineItem match = accepted == null ? null : accepted.get(oppLine.PricebookEntryId);
            if (match != null && match.UnitPrice != oppLine.UnitPrice) {
                oppLineUpdates.add(new OpportunityLineItem(Id = oppLine.Id, UnitPrice = match.UnitPrice));
            }
        }
        if (!oppLineUpdates.isEmpty()) {
            TriggerControl.bypass('OpportunityLineItem');
            update oppLineUpdates;
            TriggerControl.clearBypass('OpportunityLineItem');
        }
    }
}
