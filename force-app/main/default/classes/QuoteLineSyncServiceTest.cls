@isTest
private class QuoteLineSyncServiceTest {
    @isTest
    static void acceptedQuotePricesFlowBackToOpportunity() {
        Account a = new Account(Name = 'Sync Co');
        insert a;
        Product2 p = new Product2(Name = 'Module', Family = 'Software', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id,
            Pricebook2Id = Test.getStandardPricebookId(), UnitPrice = 100, IsActive = true);
        insert pbe;
        Opportunity o = new Opportunity(Name = 'Sync Deal', AccountId = a.Id, StageName = 'Qualification',
            CloseDate = Date.today().addDays(30), Pricebook2Id = Test.getStandardPricebookId());
        insert o;
        insert new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe.Id, Quantity = 10, UnitPrice = 100);
        Id quoteId = QuoteGenerationService.generateFromOpportunity(o.Id);
        QuoteLineItem qli = [SELECT Id, UnitPrice FROM QuoteLineItem WHERE QuoteId = :quoteId];
        qli.UnitPrice = 80;
        update qli;
        Test.startTest();
        Quote q = new Quote(Id = quoteId, Status = 'Accepted');
        update q;
        Test.stopTest();
        System.assertEquals(80, [SELECT UnitPrice FROM OpportunityLineItem WHERE OpportunityId = :o.Id].UnitPrice);
    }
}
