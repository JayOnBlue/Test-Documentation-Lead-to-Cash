/**
 * Accepted quote -> Order: creates the draft order against the quote's account and
 * pricebook and mirrors every quote line as an order product at the accepted price.
 */
public with sharing class OrderFromQuoteService {
    public static Id createOrder(Id quoteId) {
        Quote q = [SELECT Id, Name, OpportunityId, Opportunity.AccountId, Pricebook2Id, Status
                   FROM Quote WHERE Id = :quoteId];
        if (q.Status != 'Accepted') {
            throw new IllegalArgumentException('Only an Accepted quote can become an order (got ' + q.Status + ').');
        }
        Order o = new Order(AccountId = q.Opportunity.AccountId, OpportunityId = q.OpportunityId,
            Pricebook2Id = q.Pricebook2Id, EffectiveDate = Date.today(), Status = 'Draft');
        insert o;

        List<OrderItem> items = new List<OrderItem>();
        for (QuoteLineItem line : [SELECT Quantity, UnitPrice, PricebookEntryId FROM QuoteLineItem WHERE QuoteId = :quoteId]) {
            items.add(new OrderItem(OrderId = o.Id, PricebookEntryId = line.PricebookEntryId,
                Quantity = line.Quantity, UnitPrice = line.UnitPrice));
        }
        if (!items.isEmpty()) insert items;
        return o.Id;
    }
}
