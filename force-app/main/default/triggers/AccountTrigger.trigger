trigger AccountTrigger on Account (before insert, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) AccountTriggerHandler.beforeInsert(Trigger.new);
    if (Trigger.isAfter && Trigger.isInsert) AccountTriggerHandler.afterInsert(Trigger.new);
    if (Trigger.isAfter && Trigger.isUpdate) AccountTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
