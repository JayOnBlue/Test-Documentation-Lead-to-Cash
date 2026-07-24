@isTest
private class OpportunityStageGuardServiceTest {
    private static Opportunity makeOpp(String stage) {
        Account a = new Account(Name = 'Guard Co');
        insert a;
        Opportunity o = new Opportunity(Name = 'Guard Deal', AccountId = a.Id,
            StageName = stage, CloseDate = Date.today().addDays(30), Amount = 5000);
        insert o;
        return o;
    }

    @isTest
    static void blocksSkippingStages() {
        Opportunity o = makeOpp('Prospecting');
        o.StageName = 'Negotiation/Review';
        Test.startTest();
        Database.SaveResult res = Database.update(o, false);
        Test.stopTest();
        System.assert(!res.isSuccess(), 'jumping three stages must be blocked');
    }

    @isTest
    static void blocksProposalWithoutProducts() {
        Opportunity o = makeOpp('Needs Analysis');
        o.StageName = 'Proposal/Price Quote';
        Test.startTest();
        Database.SaveResult res = Database.update(o, false);
        Test.stopTest();
        System.assert(!res.isSuccess(), 'proposal without line items must be blocked');
    }
}
