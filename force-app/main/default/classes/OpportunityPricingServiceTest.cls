@isTest
private class OpportunityPricingServiceTest {
    @isTest
    static void repricesLineThroughRuleEngine() {
        Account a = new Account(Name = 'Pricing Co', AnnualRevenue = 200000000);
        insert a;
        Product2 p = new Product2(Name = 'Suite', Family = 'Software', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id,
            Pricebook2Id = Test.getStandardPricebookId(), UnitPrice = 100, IsActive = true);
        insert pbe;
        Opportunity o = new Opportunity(Name = 'Priced Deal', AccountId = a.Id,
            StageName = 'Qualification', CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId());
        insert o;
        Test.startTest();
        insert new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe.Id, Quantity = 300, UnitPrice = 100);
        Test.stopTest();
        OpportunityLineItem line = [SELECT UnitPrice FROM OpportunityLineItem WHERE OpportunityId = :o.Id];
        System.assert(line.UnitPrice < 100, 'volume + tier discounts should lower the unit price');
    }
}
