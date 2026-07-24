trigger QuoteTrigger on Quote (before update, after update) {
    if (Trigger.isBefore) QuoteTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    if (Trigger.isAfter) QuoteTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
