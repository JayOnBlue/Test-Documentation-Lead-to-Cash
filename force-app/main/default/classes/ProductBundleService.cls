/**
 * Expands a "bundle" parent product into its component lines on an opportunity — the
 * component list is derived from product codes sharing the bundle's code prefix
 * (BNDL-CORE -> BNDL-CORE-*), which keeps the demo entirely on standard fields.
 */
public with sharing class ProductBundleService {
    public static Integer expandBundles(Id opportunityId) {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :opportunityId];
        if (opp.Pricebook2Id == null) return 0;
        List<OpportunityLineItem> bundleLines = [
            SELECT Id, Quantity, PricebookEntry.Product2.ProductCode
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId AND PricebookEntry.Product2.ProductCode LIKE 'BNDL-%'];
        if (bundleLines.isEmpty()) return 0;

        List<OpportunityLineItem> componentsToAdd = new List<OpportunityLineItem>();
        for (OpportunityLineItem bundle : bundleLines) {
            String prefix = bundle.PricebookEntry.Product2.ProductCode + '-';
            for (PricebookEntry component : [SELECT Id, UnitPrice FROM PricebookEntry
                                             WHERE Pricebook2Id = :opp.Pricebook2Id AND IsActive = true
                                             AND Product2.ProductCode LIKE :(prefix + '%')]) {
                componentsToAdd.add(new OpportunityLineItem(OpportunityId = opportunityId,
                    PricebookEntryId = component.Id, Quantity = bundle.Quantity, UnitPrice = component.UnitPrice));
            }
        }
        if (!componentsToAdd.isEmpty()) insert componentsToAdd;
        return componentsToAdd.size();
    }
}
