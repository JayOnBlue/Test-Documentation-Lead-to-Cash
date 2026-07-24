/**
 * Simulates quote document generation (the real org would call a doc-gen service): logs a
 * completed Task carrying the rendered summary so the send is auditable.
 */
public with sharing class QuotePdfQueueable implements Queueable {
    private final Id quoteId;
    public QuotePdfQueueable(Id quoteId) { this.quoteId = quoteId; }

    public void execute(QueueableContext ctx) {
        Quote q = [SELECT Id, Name, GrandTotal, ExpirationDate FROM Quote WHERE Id = :quoteId];
        insert new Task(Subject = 'Quote document generated: ' + q.Name,
            Description = 'Total ' + q.GrandTotal + ', valid until ' + String.valueOf(q.ExpirationDate),
            WhatId = q.Id, Status = 'Completed', ActivityDate = Date.today());
    }
}
