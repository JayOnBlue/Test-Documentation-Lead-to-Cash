@isTest
private class QuoteGenerationServiceTest {
    @isTest
    static void generatesQuoteWithPricedLines() {
        Account a = new Account(Name = 'Quote Co', AnnualRevenue = 200000000);
        insert a;
        Product2 p = new Product2(Name = 'Platform', Family = 'Software', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id,
            Pricebook2Id = Test.getStandardPricebookId(), UnitPrice = 200, IsActive = true);
        insert pbe;
        Opportunity o = new Opportunity(Name = 'Quote Deal', AccountId = a.Id, StageName = 'Qualification',
            CloseDate = Date.today().addDays(30), Pricebook2Id = Test.getStandardPricebookId());
        insert o;
        insert new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe.Id, Quantity = 60, UnitPrice = 200);
        Test.startTest();
        Id quoteId = QuoteGenerationService.generateFromOpportunity(o.Id);
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId]);
        System.assertEquals('Draft', [SELECT Status FROM Quote WHERE Id = :quoteId].Status);
    }
}
