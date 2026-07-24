/**
 * Nightly sweep for unconverted leads untouched for 14+ days: logs a follow-up Task for
 * the owner and queues the nurture email.
 */
public with sharing class LeadNurtureBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId FROM Lead
            WHERE IsConverted = false AND LastModifiedDate < :Date.today().addDays(-14)
        ]);
    }

    public void execute(Database.BatchableContext ctx, List<Lead> scope) {
        List<Task> tasks = new List<Task>();
        for (Lead l : scope) {
            tasks.add(new Task(Subject = 'Nurture follow-up', WhoId = l.Id, OwnerId = l.OwnerId,
                ActivityDate = Date.today().addDays(2), Status = 'Not Started'));
        }
        insert tasks;
        System.enqueueJob(new LeadNurtureQueueable(new Map<Id, Lead>(scope).keySet()));
    }

    public void finish(Database.BatchableContext ctx) { }
}
