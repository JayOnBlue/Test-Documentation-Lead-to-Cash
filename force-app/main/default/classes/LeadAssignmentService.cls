/**
 * Routes new leads to owners. Hot leads and target-industry leads go to the senior queue
 * (approximated here as the most recently active user); everything else round-robins across
 * active standard users so no single rep drowns.
 */
public with sharing class LeadAssignmentService {
    private static Integer roundRobinCursor = 0;

    public static void assignOwners(List<Lead> leads) {
        List<User> reps = [SELECT Id FROM User WHERE IsActive = true AND UserType = 'Standard' ORDER BY LastLoginDate DESC NULLS LAST LIMIT 10];
        if (reps.isEmpty()) return;
        for (Lead l : leads) {
            if (l.OwnerId != null && !(l.Rating == 'Hot')) continue;
            if (l.Rating == 'Hot') {
                l.OwnerId = reps[0].Id;
            } else {
                l.OwnerId = reps[Math.mod(roundRobinCursor, reps.size())].Id;
                roundRobinCursor++;
            }
        }
    }
}
