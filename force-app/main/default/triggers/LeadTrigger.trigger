trigger LeadTrigger on Lead (before insert, before update, after update) {
    if (Trigger.isBefore && Trigger.isInsert) LeadTriggerHandler.beforeInsert(Trigger.new);
    if (Trigger.isBefore && Trigger.isUpdate) LeadTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    if (Trigger.isAfter && Trigger.isUpdate) LeadTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
