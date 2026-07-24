trigger ProductTrigger on Product2 (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) ProductTriggerHandler.beforeInsertOrUpdate(Trigger.new);
    if (Trigger.isAfter && Trigger.isInsert) ProductTriggerHandler.afterInsert(Trigger.new);
    if (Trigger.isAfter && Trigger.isUpdate) ProductTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
