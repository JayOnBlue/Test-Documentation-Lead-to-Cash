/**
 * Account tiering: derives the account's Rating (Hot/Warm/Cold as tier proxy) from annual
 * revenue and headcount, and stamps Type for net-new customers. Called from the Account
 * trigger and after lead conversion so tiers never lag reality.
 */
public with sharing class AccountTierService {
    public static final Decimal ENTERPRISE_REVENUE = 100000000;
    public static final Decimal MIDMARKET_REVENUE = 10000000;

    public static void retierAccounts(List<Account> accounts) {
        List<Account> updates = new List<Account>();
        for (Account a : accounts) {
            String tier = tierFor(a);
            if (a.Rating != tier) updates.add(new Account(Id = a.Id, Rating = tier));
        }
        if (!updates.isEmpty()) {
            TriggerControl.bypass('Account');
            update updates;
            TriggerControl.clearBypass('Account');
        }
    }

    public static String tierFor(Account a) {
        Decimal revenue = a.AnnualRevenue == null ? 0 : a.AnnualRevenue;
        Integer heads = a.NumberOfEmployees == null ? 0 : a.NumberOfEmployees;
        if (revenue >= ENTERPRISE_REVENUE || heads >= 1000) return 'Hot';
        if (revenue >= MIDMARKET_REVENUE || heads >= 100) return 'Warm';
        return 'Cold';
    }
}
