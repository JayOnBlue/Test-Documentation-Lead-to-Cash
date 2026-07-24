/**
 * Composite account health: open pipeline, recent closed-won momentum, and order activity.
 * Read-only — surfaces through the dashboard component and the metrics service; never
 * writes to the account itself.
 */
public with sharing class AccountHealthScoreService {
    public static Map<Id, Integer> healthFor(Set<Id> accountIds) {
        Map<Id, Integer> score = new Map<Id, Integer>();
        for (Id accountId : accountIds) score.put(accountId, 50);

        for (AggregateResult r : [SELECT AccountId aid, COUNT(Id) cnt FROM Opportunity
                                  WHERE AccountId IN :accountIds AND IsClosed = false GROUP BY AccountId]) {
            Id aid = (Id) r.get('aid');
            score.put(aid, score.get(aid) + Math.min(20, 5 * (Integer) r.get('cnt')));
        }
        for (AggregateResult r : [SELECT AccountId aid, COUNT(Id) cnt FROM Opportunity
                                  WHERE AccountId IN :accountIds AND IsWon = true AND CloseDate = LAST_N_DAYS:180 GROUP BY AccountId]) {
            Id aid = (Id) r.get('aid');
            score.put(aid, score.get(aid) + Math.min(20, 10 * (Integer) r.get('cnt')));
        }
        for (AggregateResult r : [SELECT AccountId aid, COUNT(Id) cnt FROM Order
                                  WHERE AccountId IN :accountIds AND Status = 'Activated' GROUP BY AccountId]) {
            Id aid = (Id) r.get('aid');
            score.put(aid, score.get(aid) + Math.min(10, 5 * (Integer) r.get('cnt')));
        }
        for (Id aid : score.keySet()) score.put(aid, Math.min(100, score.get(aid)));
        return score;
    }

    @AuraEnabled(cacheable=true)
    public static Integer healthForAccount(Id accountId) {
        return healthFor(new Set<Id>{ accountId }).get(accountId);
    }
}
