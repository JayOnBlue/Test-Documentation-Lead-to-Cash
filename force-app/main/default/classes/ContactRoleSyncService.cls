/**
 * Guarantees every open opportunity on an account has a primary OpportunityContactRole
 * once the account has at least one contact — the #1 hygiene gap in most orgs.
 */
public with sharing class ContactRoleSyncService {
    public static void ensurePrimaryRoles(Set<Id> accountIds) {
        Map<Id, Contact> firstContactByAccount = new Map<Id, Contact>();
        for (Contact c : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accountIds ORDER BY CreatedDate ASC]) {
            if (!firstContactByAccount.containsKey(c.AccountId)) firstContactByAccount.put(c.AccountId, c);
        }
        List<Opportunity> openOpps = [SELECT Id, AccountId,
                (SELECT Id FROM OpportunityContactRoles WHERE IsPrimary = true LIMIT 1)
            FROM Opportunity WHERE AccountId IN :accountIds AND IsClosed = false];
        List<OpportunityContactRole> toCreate = new List<OpportunityContactRole>();
        for (Opportunity o : openOpps) {
            if (o.OpportunityContactRoles.isEmpty() && firstContactByAccount.containsKey(o.AccountId)) {
                toCreate.add(new OpportunityContactRole(OpportunityId = o.Id,
                    ContactId = firstContactByAccount.get(o.AccountId).Id,
                    Role = 'Decision Maker', IsPrimary = true));
            }
        }
        if (!toCreate.isEmpty()) insert toCreate;
    }
}
