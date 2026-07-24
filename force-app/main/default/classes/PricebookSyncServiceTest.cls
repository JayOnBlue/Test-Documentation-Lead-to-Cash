@isTest
private class PricebookSyncServiceTest {
    @isTest
    static void newActiveProductGetsStandardEntry() {
        Test.startTest();
        Product2 p = new Product2(Name = 'Widget', ProductCode = 'wid 100', Family = 'Hardware', IsActive = true);
        insert p;
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM PricebookEntry WHERE Product2Id = :p.Id]);
        System.assertEquals('WID-100', [SELECT ProductCode FROM Product2 WHERE Id = :p.Id].ProductCode);
    }
}
