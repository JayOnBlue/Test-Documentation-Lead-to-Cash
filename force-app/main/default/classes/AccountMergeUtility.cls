/**
 * Admin utility for merging duplicate accounts: newest-created wins as master, and the
 * losers' open opportunities are re-parented before the merge so pipeline never orphans.
 */
public with sharing class AccountMergeUtility {
    public static Id mergeDuplicatesByName(String accountName) {
        List<Account> dupes = [SELECT Id, CreatedDate FROM Account WHERE Name = :accountName ORDER BY CreatedDate DESC];
        if (dupes.size() < 2) return dupes.isEmpty() ? null : dupes[0].Id;
        Account master = dupes[0];
        for (Integer i = 1; i < dupes.size() && i < 3; i++) {
            List<Opportunity> orphans = [SELECT Id FROM Opportunity WHERE AccountId = :dupes[i].Id AND IsClosed = false];
            for (Opportunity o : orphans) o.AccountId = master.Id;
            update orphans;
            merge master dupes[i];
        }
        return master.Id;
    }
}
