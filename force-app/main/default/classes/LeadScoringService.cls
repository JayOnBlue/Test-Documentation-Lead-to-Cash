/**
 * Lead scoring: rates every lead 0-100 from firmographics (industry, revenue, headcount)
 * and contact quality (business email, phone present), then writes the band to Lead.Rating
 * (Hot / Warm / Cold). Runs in the before-context so no extra DML is spent.
 */
public with sharing class LeadScoringService {
    public static final Integer HOT_THRESHOLD = 70;
    public static final Integer WARM_THRESHOLD = 40;
    private static final Set<String> TARGET_INDUSTRIES = new Set<String>{
        'Technology', 'Finance', 'Healthcare', 'Manufacturing'
    };

    public static void scoreLeads(List<Lead> leads) {
        for (Lead l : leads) {
            Integer score = computeScore(l);
            l.Rating = score >= HOT_THRESHOLD ? 'Hot' : score >= WARM_THRESHOLD ? 'Warm' : 'Cold';
        }
    }

    public static Integer computeScore(Lead l) {
        Integer score = 0;
        if (ValidationUtils.isBusinessEmail(l.Email)) score += 25;
        else if (ValidationUtils.isValidEmail(l.Email)) score += 10;
        if (ValidationUtils.isValidPhone(l.Phone)) score += 10;
        if (TARGET_INDUSTRIES.contains(l.Industry)) score += 20;
        if (l.AnnualRevenue != null) {
            if (l.AnnualRevenue >= 50000000) score += 25;
            else if (l.AnnualRevenue >= 5000000) score += 15;
            else if (l.AnnualRevenue >= 500000) score += 5;
        }
        if (l.NumberOfEmployees != null && l.NumberOfEmployees >= 200) score += 10;
        if (l.LeadSource == 'Web' || l.LeadSource == 'Partner Referral') score += 10;
        return Math.min(score, 100);
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getRecentHotLeads() {
        return [SELECT Id, Name, Company, Rating, LeadSource, CreatedDate
                FROM Lead WHERE IsConverted = false AND Rating = 'Hot'
                ORDER BY CreatedDate DESC LIMIT 25];
    }
}
