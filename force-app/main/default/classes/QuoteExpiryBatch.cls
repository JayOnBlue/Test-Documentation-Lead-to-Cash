/**
 * Daily sweep: presented quotes past their expiration date flip to Denied ("expired" in
 * this org's vocabulary) and the owner gets a requote Task.
 */
public with sharing class QuoteExpiryBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId FROM Quote
            WHERE Status = 'Presented' AND ExpirationDate < :Date.today()]);
    }

    public void execute(Database.BatchableContext ctx, List<Quote> scope) {
        List<Task> requotes = new List<Task>();
        for (Quote q : scope) {
            q.Status = 'Denied';
            requotes.add(new Task(Subject = 'Quote expired — requote: ' + q.Name, WhatId = q.Id,
                OwnerId = q.OwnerId, ActivityDate = Date.today().addDays(2), Status = 'Not Started'));
        }
        TriggerControl.bypass('Quote');
        update scope;
        TriggerControl.clearBypass('Quote');
        insert requotes;
    }

    public void finish(Database.BatchableContext ctx) { }
}
