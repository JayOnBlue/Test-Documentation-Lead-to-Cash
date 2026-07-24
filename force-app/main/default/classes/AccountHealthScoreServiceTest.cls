@isTest
private class AccountHealthScoreServiceTest {
    @isTest
    static void baselineIsFifty()
    {
        Account a = new Account(Name = 'Quiet Co');
        insert a;
        Test.startTest();
        Integer health = AccountHealthScoreService.healthForAccount(a.Id);
        Test.stopTest();
        System.assertEquals(50, health);
    }

    @isTest
    static void openPipelineRaisesHealth() {
        Account a = new Account(Name = 'Busy Co');
        insert a;
        insert new Opportunity(Name = 'Busy Deal', AccountId = a.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        Test.startTest();
        Integer health = AccountHealthScoreService.healthForAccount(a.Id);
        Test.stopTest();
        System.assert(health > 50, 'open pipeline should raise health above baseline');
    }
}
