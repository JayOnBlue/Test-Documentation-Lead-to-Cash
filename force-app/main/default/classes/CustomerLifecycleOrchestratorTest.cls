@isTest
private class CustomerLifecycleOrchestratorTest {
    @isTest
    static void fullLeadToOrderJourney() {
        Lead l = new Lead(LastName = 'Journey', Company = 'JourneyCo', Email = 'ceo@journeyco.com',
            Phone = '415-555-0102', Industry = 'Technology', AnnualRevenue = 90000000, LeadSource = 'Web');
        insert l;
        Test.startTest();
        Id oppId = CustomerLifecycleOrchestrator.qualifyAndConvert(
            [SELECT Id, Rating, IsConverted FROM Lead WHERE Id = :l.Id].Id == null ? null : l.Id);
        Test.stopTest();
        // Conversion may have already happened via the trigger when the lead scored Hot on
        // insert — either way, exactly one opportunity must exist for the company.
        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Account.Name = 'JourneyCo']);
    }
}
