trigger OrderTrigger on Order (before update, after update) {
    if (Trigger.isBefore) OrderTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    if (Trigger.isAfter) OrderTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
