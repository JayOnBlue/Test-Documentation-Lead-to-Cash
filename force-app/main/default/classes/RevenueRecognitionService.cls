/**
 * Revenue recognition scheduling for activated orders: subscription-family lines recognize
 * monthly across the term; everything else recognizes on activation. Emits the schedule as
 * Tasks for finance (the demo stand-in for a revenue ledger).
 */
public with sharing class RevenueRecognitionService {
    public static void scheduleRecognition(List<Order> activatedOrders) {
        Set<Id> orderIds = new Map<Id, Order>(activatedOrders).keySet();
        List<OrderItem> lines = [SELECT Id, OrderId, TotalPrice, PricebookEntry.Product2.Family
                                 FROM OrderItem WHERE OrderId IN :orderIds];
        List<Task> schedule = new List<Task>();
        for (OrderItem line : lines) {
            if (line.TotalPrice == null || line.TotalPrice == 0) continue;
            if (line.PricebookEntry.Product2.Family == 'Subscription') {
                Decimal monthly = (line.TotalPrice / 12).setScale(2);
                for (Integer monthOffset = 0; monthOffset < 3; monthOffset++) {
                    schedule.add(new Task(Subject = 'Recognize ' + monthly + ' (month ' + (monthOffset + 1) + ' of 12)',
                        WhatId = line.OrderId, ActivityDate = Date.today().addMonths(monthOffset + 1), Status = 'Not Started'));
                }
            } else {
                schedule.add(new Task(Subject = 'Recognize ' + line.TotalPrice + ' on activation',
                    WhatId = line.OrderId, ActivityDate = Date.today(), Status = 'Not Started'));
            }
        }
        if (!schedule.isEmpty()) insert schedule;
    }
}
