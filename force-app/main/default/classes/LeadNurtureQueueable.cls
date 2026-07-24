/**
 * Sends the nurture touch for a chunk of stale leads. Queued by LeadNurtureBatch so email
 * volume never eats the batch transaction's limits.
 */
public with sharing class LeadNurtureQueueable implements Queueable {
    private final Set<Id> leadIds;
    public LeadNurtureQueueable(Set<Id> leadIds) { this.leadIds = leadIds; }

    public void execute(QueueableContext ctx) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Lead l : [SELECT Id, Name, Email FROM Lead WHERE Id IN :leadIds AND Email != null]) {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new List<String>{ l.Email });
            m.setSubject('Still exploring? We saved your place');
            m.setPlainTextBody('Hi ' + l.Name + ', picking up where we left off is one reply away.');
            mails.add(m);
        }
        if (!mails.isEmpty()) Messaging.sendEmail(mails, false);
    }
}
