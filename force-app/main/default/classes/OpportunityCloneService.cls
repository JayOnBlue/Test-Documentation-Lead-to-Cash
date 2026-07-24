/**
 * Deep-clones an opportunity with its line items — the renewal and upsell starting point.
 * The clone lands one stage back at Qualification with a close date pushed a quarter out.
 */
public with sharing class OpportunityCloneService {
    public static Id deepClone(Id opportunityId, String newName) {
        Opportunity source = [SELECT Id, Name, AccountId, StageName, CloseDate, Amount, Pricebook2Id, OwnerId
                              FROM Opportunity WHERE Id = :opportunityId];
        Opportunity copy = source.clone(false, true, false, false);
        copy.Name = String.isBlank(newName) ? source.Name + ' (renewal)' : newName;
        copy.StageName = 'Qualification';
        copy.CloseDate = Date.today().addDays(90);
        insert copy;

        List<OpportunityLineItem> lineCopies = new List<OpportunityLineItem>();
        for (OpportunityLineItem line : [SELECT Quantity, UnitPrice, PricebookEntryId
                                         FROM OpportunityLineItem WHERE OpportunityId = :opportunityId]) {
            lineCopies.add(new OpportunityLineItem(OpportunityId = copy.Id,
                Quantity = line.Quantity, UnitPrice = line.UnitPrice, PricebookEntryId = line.PricebookEntryId));
        }
        if (!lineCopies.isEmpty()) insert lineCopies;
        return copy.Id;
    }
}
