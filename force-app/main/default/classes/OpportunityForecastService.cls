/**
 * Forecast hygiene: derives the amount-weighted pipeline per owner and stamps big deals
 * for leadership visibility (a Task on deals crossing the big-deal threshold).
 */
public with sharing class OpportunityForecastService {
    public static final Decimal BIG_DEAL_AMOUNT = 250000;

    public static void flagBigDeals(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        List<Task> alerts = new List<Task>();
        for (Opportunity o : opps) {
            Opportunity prior = oldMap.get(o.Id);
            Boolean crossed = o.Amount != null && o.Amount >= BIG_DEAL_AMOUNT
                && (prior.Amount == null || prior.Amount < BIG_DEAL_AMOUNT);
            if (crossed && !o.IsClosed) {
                alerts.add(new Task(Subject = 'Big deal alert: ' + o.Name, WhatId = o.Id,
                    OwnerId = o.OwnerId, ActivityDate = Date.today().addDays(1), Status = 'Not Started', Priority = 'High'));
            }
        }
        if (!alerts.isEmpty()) insert alerts;
    }

    public static Map<Id, Decimal> weightedPipelineByOwner() {
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        for (AggregateResult r : [SELECT OwnerId oid, SUM(ExpectedRevenue) total FROM Opportunity
                                  WHERE IsClosed = false GROUP BY OwnerId]) {
            out.put((Id) r.get('oid'), (Decimal) r.get('total'));
        }
        return out;
    }
}
