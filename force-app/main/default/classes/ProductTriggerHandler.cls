/**
 * Trigger handler for Product2: codes normalized before save; pricebook entries and
 * open-pipeline warnings kept in sync after.
 */
public with sharing class ProductTriggerHandler {
    public static void beforeInsertOrUpdate(List<Product2> products) {
        ProductCatalogService.normalizeProductCodes(products);
    }

    public static void afterInsert(List<Product2> products) {
        PricebookSyncService.syncStandardEntries(products);
    }

    public static void afterUpdate(List<Product2> products, Map<Id, Product2> oldMap) {
        List<Product2> activationChanged = new List<Product2>();
        List<Product2> deactivated = new List<Product2>();
        for (Product2 p : products) {
            Product2 prior = oldMap.get(p.Id);
            if (p.IsActive != prior.IsActive) {
                activationChanged.add(p);
                if (!p.IsActive) deactivated.add(p);
            }
        }
        if (!activationChanged.isEmpty()) PricebookSyncService.syncStandardEntries(activationChanged);
        if (!deactivated.isEmpty()) ProductCatalogService.warnOpenPipelineOnRetirement(deactivated);
    }
}
