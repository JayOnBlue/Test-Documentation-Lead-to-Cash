@isTest
private class LeadScoringServiceTest {
    @isTest
    static void scoresBusinessLeadHot() {
        Lead l = new Lead(LastName = 'Big', Company = 'BigCo', Email = 'cto@bigco.com',
            Phone = '415-555-0100', Industry = 'Technology', AnnualRevenue = 60000000,
            NumberOfEmployees = 500, LeadSource = 'Web');
        Test.startTest();
        insert l;
        Test.stopTest();
        System.assertEquals('Hot', [SELECT Rating FROM Lead WHERE Id = :l.Id].Rating);
    }

    @isTest
    static void scoresThinLeadCold() {
        Lead l = new Lead(LastName = 'Small', Company = 'SmallCo', Email = 'someone@gmail.com');
        Test.startTest();
        insert l;
        Test.stopTest();
        System.assertEquals('Cold', [SELECT Rating FROM Lead WHERE Id = :l.Id].Rating);
    }

    @isTest
    static void rejectsDuplicateEmail() {
        insert new Lead(LastName = 'First', Company = 'Co', Email = 'dupe@co.com');
        Test.startTest();
        Database.SaveResult res = Database.insert(new Lead(LastName = 'Second', Company = 'Co', Email = 'dupe@co.com'), false);
        Test.stopTest();
        System.assert(!res.isSuccess());
    }
}
