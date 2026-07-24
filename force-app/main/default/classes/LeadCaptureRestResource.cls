/**
 * Inbound lead capture for web forms and partner integrations. Validates, dedupes, scores,
 * and inserts in one call; duplicates are rejected with the existing lead id.
 */
@RestResource(urlMapping='/leads/capture')
global with sharing class LeadCaptureRestResource {
    @HttpPost
    global static String capture(String firstName, String lastName, String company, String email, String phone, String source) {
        if (!ValidationUtils.hasText(lastName, 2) || !ValidationUtils.hasText(company, 2)) {
            RestContext.response.statusCode = 400;
            return 'lastName and company are required';
        }
        if (!ValidationUtils.isValidEmail(email)) {
            RestContext.response.statusCode = 400;
            return 'invalid email';
        }
        Map<String, Lead> existing = LeadDedupeService.findExistingByEmail(new Set<String>{ email });
        if (existing.containsKey(email.toLowerCase())) {
            RestContext.response.statusCode = 409;
            return 'duplicate of ' + existing.get(email.toLowerCase()).Id;
        }
        Lead l = new Lead(FirstName = firstName, LastName = lastName, Company = company,
            Email = email, Phone = phone, LeadSource = String.isBlank(source) ? 'Web' : source);
        LeadScoringService.scoreLeads(new List<Lead>{ l });
        insert l;
        return l.Id;
    }
}
