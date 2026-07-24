@isTest
private class LeadConversionServiceTest {
    @isTest
    static void convertsHotLead() {
        Lead l = new Lead(LastName = 'Convert', Company = 'ConvertCo', Email = 'vp@convertco.com',
            Phone = '415-555-0101', Industry = 'Finance', AnnualRevenue = 80000000, LeadSource = 'Partner Referral');
        insert l;
        Test.startTest();
        List<Database.LeadConvertResult> results = LeadConversionService.convertQualified(
            [SELECT Id, IsConverted, Rating FROM Lead WHERE Id = :l.Id]);
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assert(results[0].isSuccess());
    }
}
