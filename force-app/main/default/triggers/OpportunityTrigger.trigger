trigger OpportunityTrigger on Opportunity (before update, after update) {
    if (Trigger.isBefore) OpportunityTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    if (Trigger.isAfter) OpportunityTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
