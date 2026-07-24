@isTest
private class PriceRuleEngineTest {
    @isTest
    static void stacksVolumeAndTierDiscounts() {
        PriceRuleEngine.PriceContext ctx = new PriceRuleEngine.PriceContext(100, 300, 'Software', 'Hot');
        Test.startTest();
        PriceRuleEngine.PriceResult result = PriceRuleEngine.price(ctx);
        Test.stopTest();
        System.assertEquals(25, result.discountPct, 'volume 15 + tier 8 + family 2 = 25');
        System.assertEquals(75.00, result.unitPrice);
    }

    @isTest
    static void marginFloorWins() {
        PriceRuleEngine.PriceContext ctx = new PriceRuleEngine.PriceContext(100, 5000, 'Services', 'Hot');
        Test.startTest();
        PriceRuleEngine.PriceResult result = PriceRuleEngine.price(ctx);
        Test.stopTest();
        System.assert(result.flooredByMargin, 'services floor must clamp stacked discounts');
        System.assertEquals(75.00, result.unitPrice, 'services floor is 75% of list');
    }

    @isTest
    static void approvalMatrix() {
        System.assert(PriceRuleEngine.requiresApproval(35, 1000));
        System.assert(PriceRuleEngine.requiresApproval(25, 500000));
        System.assert(!PriceRuleEngine.requiresApproval(15, 500000));
        System.assert(!PriceRuleEngine.requiresApproval(25, 50000));
    }
}
