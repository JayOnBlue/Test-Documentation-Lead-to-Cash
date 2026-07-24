/**
 * Converts qualified leads into Account + Contact + Opportunity via Database.LeadConvert,
 * then hands the new accounts to AccountTierService so tiering is correct from minute one.
 */
public with sharing class LeadConversionService {
    public static List<Database.LeadConvertResult> convertQualified(List<Lead> leads) {
        LeadStatus converted = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        List<Database.LeadConvert> conversions = new List<Database.LeadConvert>();
        for (Lead l : leads) {
            if (l.IsConverted || l.Rating != 'Hot') continue;
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(l.Id);
            lc.setConvertedStatus(converted.MasterLabel);
            lc.setDoNotCreateOpportunity(false);
            conversions.add(lc);
        }
        if (conversions.isEmpty()) return new List<Database.LeadConvertResult>();

        List<Database.LeadConvertResult> results = Database.convertLead(conversions, false);
        Set<Id> accountIds = new Set<Id>();
        for (Database.LeadConvertResult r : results) {
            if (r.isSuccess() && r.getAccountId() != null) accountIds.add(r.getAccountId());
        }
        if (!accountIds.isEmpty()) {
            AccountTierService.retierAccounts([SELECT Id, AnnualRevenue, NumberOfEmployees, Rating FROM Account WHERE Id IN :accountIds]);
        }
        return results;
    }
}
