/**
 * Post-activation fulfillment: creates the provisioning Task set per order and exposes the
 * open-order feed the tracker component reads.
 */
public with sharing class OrderFulfillmentService {
    public static void kickoffFulfillment(List<Order> activated) {
        List<Task> tasks = new List<Task>();
        for (Order o : activated) {
            tasks.add(new Task(Subject = 'Provision order ' + o.OrderNumber, WhatId = o.Id,
                ActivityDate = Date.today().addDays(1), Status = 'Not Started', Priority = 'High'));
            tasks.add(new Task(Subject = 'Confirm delivery details for order ' + o.OrderNumber, WhatId = o.Id,
                ActivityDate = Date.today().addDays(3), Status = 'Not Started'));
        }
        if (!tasks.isEmpty()) insert tasks;
    }

    @AuraEnabled(cacheable=true)
    public static List<Order> getOpenOrders() {
        return [SELECT Id, OrderNumber, Status, TotalAmount, EffectiveDate, Account.Name
                FROM Order WHERE Status IN ('Draft', 'Activated')
                ORDER BY EffectiveDate DESC LIMIT 50];
    }
}
