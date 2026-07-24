/**
 * Trigger handler for Quote: presentation is approval-gated in before-update; acceptance
 * syncs prices back to the opportunity and generates the document in after-update.
 */
public with sharing class QuoteTriggerHandler {
    public static void beforeUpdate(List<Quote> quotes, Map<Id, Quote> oldMap) {
        if (TriggerControl.isBypassed('Quote')) return;
        QuoteApprovalService.gatePresentation(quotes, oldMap);
    }

    public static void afterUpdate(List<Quote> quotes, Map<Id, Quote> oldMap) {
        if (TriggerControl.isBypassed('Quote')) return;
        List<Quote> accepted = new List<Quote>();
        for (Quote q : quotes) {
            if (q.Status == 'Accepted' && oldMap.get(q.Id).Status != 'Accepted') accepted.add(q);
        }
        if (!accepted.isEmpty()) {
            QuoteLineSyncService.syncAcceptedQuotes(accepted);
            for (Quote q : accepted) System.enqueueJob(new QuotePdfQueueable(q.Id));
        }
    }
}
