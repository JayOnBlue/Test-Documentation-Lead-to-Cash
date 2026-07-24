trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert, after update) {
    OpportunityLineItemTriggerHandler.afterInsertOrUpdate(Trigger.new);
}
