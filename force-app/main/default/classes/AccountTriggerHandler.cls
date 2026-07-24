/**
 * Trigger handler for Account. Before: territory stamp. After: retier when the sizing
 * fields moved (guarded against recursion since retier writes Account.Rating).
 */
public with sharing class AccountTriggerHandler {
    public static void beforeInsert(List<Account> accounts) {
        AccountTerritoryService.stampTerritoryDescription(accounts);
    }

    public static void afterInsert(List<Account> accounts) {
        if (TriggerControl.isBypassed('Account')) return;
        AccountTierService.retierAccounts(accounts);
    }

    public static void afterUpdate(List<Account> accounts, Map<Id, Account> oldMap) {
        if (TriggerControl.isBypassed('Account')) return;
        List<Account> resized = new List<Account>();
        for (Account a : accounts) {
            Account prior = oldMap.get(a.Id);
            if (a.AnnualRevenue != prior.AnnualRevenue || a.NumberOfEmployees != prior.NumberOfEmployees) {
                resized.add(a);
            }
        }
        if (!resized.isEmpty()) AccountTierService.retierAccounts(resized);
    }
}
