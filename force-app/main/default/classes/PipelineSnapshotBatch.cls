/**
 * Nightly pipeline snapshot: aggregates open pipeline by stage and posts the numbers as a
 * completed Task on the running user's timeline — a cheap, dependency-free audit trail of
 * how the funnel moved day over day.
 */
public with sharing class PipelineSnapshotBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Map<String, Decimal> totalByStage = new Map<String, Decimal>();

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([SELECT StageName, Amount FROM Opportunity WHERE IsClosed = false]);
    }

    public void execute(Database.BatchableContext ctx, List<Opportunity> scope) {
        for (Opportunity o : scope) {
            Decimal current = totalByStage.containsKey(o.StageName) ? totalByStage.get(o.StageName) : 0;
            totalByStage.put(o.StageName, current + (o.Amount == null ? 0 : o.Amount));
        }
    }

    public void finish(Database.BatchableContext ctx) {
        List<String> parts = new List<String>();
        for (String stage : totalByStage.keySet()) parts.add(stage + ': ' + totalByStage.get(stage));
        insert new Task(Subject = 'Pipeline snapshot ' + Date.today().format(),
            Description = String.join(parts, '\n'), Status = 'Completed', ActivityDate = Date.today());
    }
}
