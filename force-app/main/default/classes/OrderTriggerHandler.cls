/**
 * Trigger handler for Order: activation gate before update; fulfillment kickoff and
 * revenue recognition scheduling after.
 */
public with sharing class OrderTriggerHandler {
    public static void beforeUpdate(List<Order> orders, Map<Id, Order> oldMap) {
        if (TriggerControl.isBypassed('Order')) return;
        OrderActivationService.gateActivation(orders, oldMap);
    }

    public static void afterUpdate(List<Order> orders, Map<Id, Order> oldMap) {
        if (TriggerControl.isBypassed('Order')) return;
        List<Order> activated = new List<Order>();
        for (Order o : orders) {
            if (o.Status == 'Activated' && oldMap.get(o.Id).Status != 'Activated') activated.add(o);
        }
        if (!activated.isEmpty()) {
            OrderFulfillmentService.kickoffFulfillment(activated);
            RevenueRecognitionService.scheduleRecognition(activated);
        }
    }
}
