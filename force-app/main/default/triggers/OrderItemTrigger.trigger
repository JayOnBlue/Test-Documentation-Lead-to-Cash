trigger OrderItemTrigger on OrderItem (after insert, after update) {
    OrderItemTriggerHandler.afterInsertOrUpdate(Trigger.new);
}
