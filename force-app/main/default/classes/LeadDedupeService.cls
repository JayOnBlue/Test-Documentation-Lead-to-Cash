/**
 * Duplicate detection for inbound leads: an incoming lead is a duplicate when an
 * unconverted lead already carries the same email (case-insensitive). Used by both the
 * trigger path and the REST capture endpoint so the rule can never drift between them.
 */
public with sharing class LeadDedupeService {
    public static Map<String, Lead> findExistingByEmail(Set<String> emails) {
        Map<String, Lead> out = new Map<String, Lead>();
        if (emails.isEmpty()) return out;
        for (Lead l : [SELECT Id, Email, OwnerId FROM Lead
                       WHERE IsConverted = false AND Email IN :emails]) {
            out.put(l.Email.toLowerCase(), l);
        }
        return out;
    }

    public static void flagDuplicates(List<Lead> incoming) {
        Set<String> emails = new Set<String>();
        for (Lead l : incoming) {
            if (l.Email != null) emails.add(l.Email);
        }
        Map<String, Lead> existing = findExistingByEmail(emails);
        for (Lead l : incoming) {
            if (l.Email != null && existing.containsKey(l.Email.toLowerCase())) {
                l.addError('A lead with this email already exists (' + existing.get(l.Email.toLowerCase()).Id + ').');
            }
        }
    }
}
