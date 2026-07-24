@isTest
private class OrderActivationServiceTest {
    @isTest
    static void blocksActivationWithoutLines() {
        Account a = new Account(Name = 'Empty Order Co');
        insert a;
        Order o = new Order(AccountId = a.Id, EffectiveDate = Date.today(), Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId());
        insert o;
        o.Status = 'Activated';
        Test.startTest();
        Database.SaveResult res = Database.update(o, false);
        Test.stopTest();
        System.assert(!res.isSuccess(), 'activation without lines must be blocked');
    }
}
