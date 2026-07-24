/**
 * Margin math on top of PriceRuleEngine's floors: given sold prices, reports the
 * effective margin per family and flags lines sold at or below floor.
 */
public with sharing class MarginCalculationService {
    public class MarginLine {
        public Id lineId;
        public Decimal marginPct;
        public Boolean atFloor;
    }

    public static List<MarginLine> marginsForOrderItems(List<OrderItem> items, Map<Id, Product2> productsById) {
        List<MarginLine> out = new List<MarginLine>();
        for (OrderItem item : items) {
            Product2 product = productsById.get(item.Product2Id);
            if (product == null || item.ListPrice == null || item.ListPrice == 0) continue;
            MarginLine line = new MarginLine();
            line.lineId = item.Id;
            line.marginPct = ((item.UnitPrice / item.ListPrice) * 100).setScale(2);
            Decimal floor = PriceRuleEngine.marginFloorPrice(item.ListPrice, product.Family);
            line.atFloor = item.UnitPrice <= floor;
            out.add(line);
        }
        return out;
    }
}
