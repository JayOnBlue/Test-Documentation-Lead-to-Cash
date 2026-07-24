/**
 * Cross-domain audit trail: discount approvals, blocked quote presentations, failed
 * credit checks. Everything lands as completed Tasks under one subject convention so
 * sales ops has a single query for "what did governance do this week."
 */
public without sharing class SalesOpsAuditService {
    public static void record(String category, List<String> notes) {
        List<Task> entries = new List<Task>();
        for (String note : notes) {
            entries.add(new Task(Subject = 'AUDIT/' + category,
                Description = ValidationUtils.truncate(note, 32000),
                Status = 'Completed', ActivityDate = Date.today()));
        }
        if (!entries.isEmpty()) insert entries;
    }
}
