/**
 * The single pricing brain. Every surface that prices a line — opportunity products,
 * quote lines, order items — routes through here so a discount is computed exactly one
 * way everywhere. Rules, in the order applied:
 *   1. volume discount by quantity band (per product family),
 *   2. customer-tier discount (from Account.Rating),
 *   3. product-family strategic adjustment,
 *   4. margin floor: the final price never drops below the family's floor percentage
 *      of list, no matter what the stacked discounts said.
 */
public with sharing class PriceRuleEngine {
    public static final Decimal DEFAULT_MARGIN_FLOOR_PCT = 60;

    public class PriceContext {
        public Decimal listPrice;
        public Decimal quantity;
        public String productFamily;
        public String accountTier;
        public PriceContext(Decimal listPrice, Decimal quantity, String productFamily, String accountTier) {
            this.listPrice = listPrice;
            this.quantity = quantity;
            this.productFamily = productFamily;
            this.accountTier = accountTier;
        }
    }

    public class PriceResult {
        public Decimal unitPrice;
        public Decimal discountPct;
        public Boolean flooredByMargin;
        public List<String> appliedRules = new List<String>();
    }

    public static PriceResult price(PriceContext ctx) {
        PriceResult result = new PriceResult();
        Decimal discount = 0;

        Decimal volume = volumeDiscountPct(ctx.productFamily, ctx.quantity);
        if (volume > 0) { discount += volume; result.appliedRules.add('volume:' + volume + '%'); }

        Decimal tier = tierDiscountPct(ctx.accountTier);
        if (tier > 0) { discount += tier; result.appliedRules.add('tier:' + tier + '%'); }

        Decimal strategic = familyAdjustmentPct(ctx.productFamily);
        if (strategic != 0) { discount += strategic; result.appliedRules.add('family:' + strategic + '%'); }

        discount = capDiscount(discount);
        Decimal proposed = ctx.listPrice * (1 - discount / 100);
        Decimal floor = marginFloorPrice(ctx.listPrice, ctx.productFamily);
        if (proposed < floor) {
            proposed = floor;
            result.flooredByMargin = true;
            result.appliedRules.add('margin-floor');
            discount = (1 - proposed / ctx.listPrice) * 100;
        }
        result.unitPrice = proposed.setScale(2);
        result.discountPct = discount.setScale(2);
        return result;
    }

    public static Decimal volumeDiscountPct(String family, Decimal quantity) {
        if (quantity == null) return 0;
        if (family == 'Hardware') {
            if (quantity >= 500) return 18;
            if (quantity >= 100) return 12;
            if (quantity >= 25) return 6;
            return 0;
        }
        if (family == 'Software' || family == 'Subscription') {
            if (quantity >= 1000) return 25;
            if (quantity >= 250) return 15;
            if (quantity >= 50) return 8;
            return 0;
        }
        if (quantity >= 100) return 10;
        if (quantity >= 20) return 5;
        return 0;
    }

    public static Decimal tierDiscountPct(String accountTier) {
        if (accountTier == 'Hot') return 8;
        if (accountTier == 'Warm') return 4;
        return 0;
    }

    public static Decimal familyAdjustmentPct(String family) {
        if (family == 'Subscription') return 2;    // land-and-expand: lean in
        if (family == 'Services') return -3;       // services margin is protected
        return 0;
    }

    public static Decimal capDiscount(Decimal discount) {
        return Math.max(0, Math.min(discount, 40));
    }

    public static Decimal marginFloorPrice(Decimal listPrice, String family) {
        Decimal floorPct = family == 'Services' ? 75 : family == 'Hardware' ? 55 : DEFAULT_MARGIN_FLOOR_PCT;
        return (listPrice * floorPct / 100).setScale(2);
    }

    public static Boolean requiresApproval(Decimal discountPct, Decimal dealAmount) {
        if (discountPct == null) return false;
        if (discountPct > 30) return true;
        if (discountPct > 20 && dealAmount != null && dealAmount > 100000) return true;
        return false;
    }

    public static String accountTierFor(Id accountId) {
        if (accountId == null) return null;
        List<Account> accounts = [SELECT Rating FROM Account WHERE Id = :accountId LIMIT 1];
        return accounts.isEmpty() ? null : accounts[0].Rating;
    }
}
