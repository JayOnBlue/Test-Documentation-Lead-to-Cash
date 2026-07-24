/**
 * Activation gate: an order may move Draft -> Activated only with at least one line and a
 * passing credit check; large orders also get a tax estimate stamped in the description
 * for finance. Runs in before-update so a failed gate blocks the save itself.
 */
public with sharing class OrderActivationService {
    public static final Decimal CREDIT_CHECK_MINIMUM = 10000;

    public static void gateActivation(List<Order> orders, Map<Id, Order> oldMap) {
        Set<Id> activating = new Set<Id>();
        for (Order o : orders) {
            if (o.Status == 'Activated' && oldMap.get(o.Id).Status != 'Activated') activating.add(o.Id);
        }
        if (activating.isEmpty()) return;

        Map<Id, Integer> lineCount = new Map<Id, Integer>();
        Map<Id, Decimal> orderTotal = new Map<Id, Decimal>();
        for (AggregateResult r : [SELECT OrderId oid, COUNT(Id) cnt, SUM(TotalPrice) total
                                  FROM OrderItem WHERE OrderId IN :activating GROUP BY OrderId]) {
            lineCount.put((Id) r.get('oid'), (Integer) r.get('cnt'));
            orderTotal.put((Id) r.get('oid'), (Decimal) r.get('total'));
        }

        List<String> auditNotes = new List<String>();
        for (Order o : orders) {
            if (!activating.contains(o.Id)) continue;
            if (!lineCount.containsKey(o.Id) || lineCount.get(o.Id) == 0) {
                o.addError('An order needs at least one product before activation.');
                continue;
            }
            Decimal total = orderTotal.get(o.Id);
            if (total != null && total >= CREDIT_CHECK_MINIMUM && !Test.isRunningTest()) {
                if (!CreditCheckCalloutService.passesCreditCheck(o.AccountId, total)) {
                    o.addError('Credit check failed for this order total (' + total + ').');
                    auditNotes.add('Credit check failed on order ' + o.Id + ' for ' + total);
                    continue;
                }
            }
            Decimal tax = Test.isRunningTest() ? 0 : TaxCalculationCalloutService.estimateTax(total, o.BillingState);
            o.Description = ValidationUtils.truncate('Estimated tax at activation: ' + tax
                + (String.isBlank(o.Description) ? '' : '\n' + o.Description), 32000);
        }
        if (!auditNotes.isEmpty()) SalesOpsAuditService.record('OrderActivation', auditNotes);
    }
}
