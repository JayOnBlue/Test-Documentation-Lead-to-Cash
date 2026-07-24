/**
 * Trigger handler for OrderItem: margin surveillance — any order line landing at or below
 * its family's margin floor gets flagged to sales ops as a Task on the order.
 */
public with sharing class OrderItemTriggerHandler {
    public static void afterInsertOrUpdate(List<OrderItem> items) {
        Set<Id> productIds = CollectionUtils.extractIds(items, 'Product2Id');
        Map<Id, Product2> productsById = new Map<Id, Product2>([SELECT Id, Family FROM Product2 WHERE Id IN :productIds]);
        List<MarginCalculationService.MarginLine> margins = MarginCalculationService.marginsForOrderItems(items, productsById);
        Map<Id, OrderItem> itemsById = new Map<Id, OrderItem>(items);
        List<Task> flags = new List<Task>();
        for (MarginCalculationService.MarginLine line : margins) {
            if (line.atFloor) {
                flags.add(new Task(Subject = 'Order line at margin floor (' + line.marginPct + '% of list)',
                    WhatId = itemsById.get(line.lineId).OrderId, ActivityDate = Date.today().addDays(1),
                    Status = 'Not Started', Priority = 'High'));
            }
        }
        if (!flags.isEmpty()) insert flags;
    }
}
