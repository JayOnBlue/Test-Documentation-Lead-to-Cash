@isTest
private class AccountTierServiceTest {
    @isTest
    static void tiersEnterpriseAccountHot() {
        Account a = new Account(Name = 'Mega Corp', AnnualRevenue = 200000000, NumberOfEmployees = 5000);
        Test.startTest();
        insert a;
        Test.stopTest();
        System.assertEquals('Hot', [SELECT Rating FROM Account WHERE Id = :a.Id].Rating);
    }

    @isTest
    static void retiersOnResize() {
        Account a = new Account(Name = 'Growing Co', AnnualRevenue = 1000000);
        insert a;
        Test.startTest();
        a.AnnualRevenue = 50000000;
        update a;
        Test.stopTest();
        System.assertEquals('Warm', [SELECT Rating FROM Account WHERE Id = :a.Id].Rating);
    }
}
