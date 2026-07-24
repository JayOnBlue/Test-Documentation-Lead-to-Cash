@isTest
private class OrderFromQuoteServiceTest {
    @isTest
    static void acceptedQuoteBecomesDraftOrder() {
        Account a = new Account(Name = 'Order Co');
        insert a;
        Product2 p = new Product2(Name = 'Thing', Family = 'Hardware', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id,
            Pricebook2Id = Test.getStandardPricebookId(), UnitPrice = 50, IsActive = true);
        insert pbe;
        Opportunity o = new Opportunity(Name = 'Order Deal', AccountId = a.Id, StageName = 'Qualification',
            CloseDate = Date.today().addDays(10), Pricebook2Id = Test.getStandardPricebookId());
        insert o;
        insert new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe.Id, Quantity = 2, UnitPrice = 50);
        Id quoteId = QuoteGenerationService.generateFromOpportunity(o.Id);
        update new Quote(Id = quoteId, Status = 'Accepted');
        Test.startTest();
        Id orderId = OrderFromQuoteService.createOrder(quoteId);
        Test.stopTest();
        System.assertEquals('Draft', [SELECT Status FROM Order WHERE Id = :orderId].Status);
        System.assertEquals(1, [SELECT COUNT() FROM OrderItem WHERE OrderId = :orderId]);
    }
}
