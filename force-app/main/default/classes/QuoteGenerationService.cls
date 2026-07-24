/**
 * Creates a Quote from an Opportunity: header copied, every opportunity line mirrored as
 * a quote line at the PriceRuleEngine-computed price, expiration defaulted 30 days out.
 */
public with sharing class QuoteGenerationService {
    public static Id generateFromOpportunity(Id opportunityId) {
        Opportunity opp = [SELECT Id, Name, AccountId, Pricebook2Id FROM Opportunity WHERE Id = :opportunityId];
        Quote q = new Quote(Name = ValidationUtils.truncate(opp.Name + ' — Quote', 255),
            OpportunityId = opp.Id, Pricebook2Id = opp.Pricebook2Id,
            ExpirationDate = Date.today().addDays(30), Status = 'Draft');
        insert q;

        String tier = PriceRuleEngine.accountTierFor(opp.AccountId);
        List<QuoteLineItem> quoteLines = new List<QuoteLineItem>();
        for (OpportunityLineItem line : [SELECT Quantity, UnitPrice, ListPrice, PricebookEntryId,
                                         PricebookEntry.Product2.Family
                                         FROM OpportunityLineItem WHERE OpportunityId = :opportunityId]) {
            Decimal unitPrice = line.UnitPrice;
            if (line.ListPrice != null && line.ListPrice > 0) {
                PriceRuleEngine.PriceResult priced = PriceRuleEngine.price(new PriceRuleEngine.PriceContext(
                    line.ListPrice, line.Quantity, line.PricebookEntry.Product2.Family, tier));
                unitPrice = priced.unitPrice;
            }
            quoteLines.add(new QuoteLineItem(QuoteId = q.Id, PricebookEntryId = line.PricebookEntryId,
                Quantity = line.Quantity, UnitPrice = unitPrice));
        }
        if (!quoteLines.isEmpty()) insert quoteLines;
        return q.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getQuotableOpportunities() {
        return [SELECT Id, Name, Amount, StageName FROM Opportunity
                WHERE IsClosed = false AND HasOpportunityLineItem = true
                ORDER BY LastModifiedDate DESC LIMIT 25];
    }
}
