/**
 * Keeps pricing infrastructure consistent when products change: every active product gets
 * a standard PricebookEntry, and deactivated products get their entries deactivated so
 * they stop being quotable immediately.
 */
public with sharing class PricebookSyncService {
    public static void syncStandardEntries(List<Product2> products) {
        Id standardPricebookId = standardPricebookId();
        if (standardPricebookId == null) return;

        Set<Id> productIds = new Map<Id, Product2>(products).keySet();
        Map<Id, PricebookEntry> existingByProduct = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [SELECT Id, Product2Id, IsActive FROM PricebookEntry
                                   WHERE Product2Id IN :productIds AND Pricebook2Id = :standardPricebookId]) {
            existingByProduct.put(pbe.Product2Id, pbe);
        }

        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        List<PricebookEntry> toUpdate = new List<PricebookEntry>();
        for (Product2 p : products) {
            PricebookEntry existing = existingByProduct.get(p.Id);
            if (existing == null && p.IsActive) {
                toInsert.add(new PricebookEntry(Product2Id = p.Id, Pricebook2Id = standardPricebookId,
                    UnitPrice = 0, IsActive = true));
            } else if (existing != null && existing.IsActive != p.IsActive) {
                toUpdate.add(new PricebookEntry(Id = existing.Id, IsActive = p.IsActive));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    public static Id standardPricebookId() {
        if (Test.isRunningTest()) return Test.getStandardPricebookId();
        List<Pricebook2> books = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        return books.isEmpty() ? null : books[0].Id;
    }
}
