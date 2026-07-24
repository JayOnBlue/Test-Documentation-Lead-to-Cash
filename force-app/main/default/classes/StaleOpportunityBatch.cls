/**
 * Weekly hygiene: open deals with a close date 30+ days in the past get a "revive or
 * close" Task; deals 90+ days past are auto-moved to Closed Lost so the pipeline reflects
 * reality.
 */
public with sharing class StaleOpportunityBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, CloseDate, StageName FROM Opportunity
            WHERE IsClosed = false AND CloseDate < :Date.today().addDays(-30)]);
    }

    public void execute(Database.BatchableContext ctx, List<Opportunity> scope) {
        List<Task> nudges = new List<Task>();
        List<Opportunity> toClose = new List<Opportunity>();
        for (Opportunity o : scope) {
            if (o.CloseDate < Date.today().addDays(-90)) {
                o.StageName = 'Closed Lost';
                toClose.add(o);
            } else {
                nudges.add(new Task(Subject = 'Stale deal — revive or close: ' + o.Name,
                    WhatId = o.Id, OwnerId = o.OwnerId, ActivityDate = Date.today().addDays(3), Status = 'Not Started'));
            }
        }
        if (!nudges.isEmpty()) insert nudges;
        if (!toClose.isEmpty()) {
            TriggerControl.bypass('Opportunity');
            update toClose;
            TriggerControl.clearBypass('Opportunity');
        }
    }

    public void finish(Database.BatchableContext ctx) { }
}
