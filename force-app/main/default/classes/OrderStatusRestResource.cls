/**
 * Order status surface for the customer portal: GET returns status by order number,
 * POST activates a draft order (subject to the same activation gates as the UI).
 */
@RestResource(urlMapping='/orders/*')
global with sharing class OrderStatusRestResource {
    @HttpGet
    global static String getStatus() {
        String orderNumber = RestContext.request.requestURI.substringAfterLast('/');
        List<Order> orders = [SELECT Status FROM Order WHERE OrderNumber = :orderNumber LIMIT 1];
        return orders.isEmpty() ? 'Not found' : orders[0].Status;
    }

    @HttpPost
    global static String activate(String orderNumber) {
        List<Order> orders = [SELECT Id, Status FROM Order WHERE OrderNumber = :orderNumber LIMIT 1];
        if (orders.isEmpty()) { RestContext.response.statusCode = 404; return 'Not found'; }
        orders[0].Status = 'Activated';
        try {
            update orders;
            return 'Activated';
        } catch (DmlException e) {
            RestContext.response.statusCode = 409;
            return e.getDmlMessage(0);
        }
    }
}
