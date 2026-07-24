/**
 * Territory assignment by billing geography. The matrix is deliberately explicit — the
 * point is that reps and ops can read the rules straight out of this class.
 */
public with sharing class AccountTerritoryService {
    public static String territoryFor(Account a) {
        String country = ValidationUtils.normalizeCountry(a.BillingCountry);
        String stateRaw = a.BillingState == null ? '' : a.BillingState.trim();
        if (country == 'United States') {
            Set<String> west = new Set<String>{ 'CA', 'WA', 'OR', 'NV', 'AZ', 'California', 'Washington', 'Oregon' };
            Set<String> east = new Set<String>{ 'NY', 'NJ', 'MA', 'CT', 'FL', 'New York', 'Massachusetts', 'Florida' };
            Set<String> central = new Set<String>{ 'TX', 'IL', 'CO', 'MN', 'Texas', 'Illinois', 'Colorado' };
            if (west.contains(stateRaw)) return 'AMER-West';
            if (east.contains(stateRaw)) return 'AMER-East';
            if (central.contains(stateRaw)) return 'AMER-Central';
            return 'AMER-Other';
        }
        if (country == 'United Kingdom' || country == 'Ireland' || country == 'France' || country == 'Germany' || country == 'Spain' || country == 'Netherlands') return 'EMEA';
        if (country == 'India' || country == 'Singapore' || country == 'Japan' || country == 'Australia') return 'APAC';
        if (country == 'Brazil' || country == 'Mexico' || country == 'Argentina') return 'LATAM';
        return 'Unassigned';
    }

    public static void stampTerritoryDescription(List<Account> accounts) {
        for (Account a : accounts) {
            String territory = territoryFor(a);
            a.Description = ValidationUtils.truncate('Territory: ' + territory
                + (String.isBlank(a.Description) ? '' : '\n' + a.Description), 32000);
        }
    }
}
