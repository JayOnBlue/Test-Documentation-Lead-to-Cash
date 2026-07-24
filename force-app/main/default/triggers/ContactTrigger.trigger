trigger ContactTrigger on Contact (after insert) {
    ContactTriggerHandler.afterInsert(Trigger.new);
}
