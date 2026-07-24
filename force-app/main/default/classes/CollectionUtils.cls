/**
 * Small, heavily reused collection helpers. Kept generic so every domain service can share
 * one implementation instead of re-rolling maps and id sets.
 */
public inherited sharing class CollectionUtils {
    public static Set<Id> extractIds(List<SObject> records, String field) {
        Set<Id> out = new Set<Id>();
        for (SObject r : records) {
            Object v = r.get(field);
            if (v != null) out.add((Id) v);
        }
        return out;
    }

    public static Map<Id, List<SObject>> groupByIdField(List<SObject> records, String field) {
        Map<Id, List<SObject>> out = new Map<Id, List<SObject>>();
        for (SObject r : records) {
            Id key = (Id) r.get(field);
            if (key == null) continue;
            if (!out.containsKey(key)) out.put(key, new List<SObject>());
            out.get(key).add(r);
        }
        return out;
    }

    public static Map<String, List<SObject>> groupByStringField(List<SObject> records, String field) {
        Map<String, List<SObject>> out = new Map<String, List<SObject>>();
        for (SObject r : records) {
            String key = String.valueOf(r.get(field));
            if (String.isBlank(key)) continue;
            if (!out.containsKey(key)) out.put(key, new List<SObject>());
            out.get(key).add(r);
        }
        return out;
    }

    public static List<Decimal> pluckDecimals(List<SObject> records, String field) {
        List<Decimal> out = new List<Decimal>();
        for (SObject r : records) {
            Object v = r.get(field);
            if (v != null) out.add((Decimal) v);
        }
        return out;
    }

    public static Decimal sum(List<Decimal> values) {
        Decimal total = 0;
        for (Decimal v : values) total += v;
        return total;
    }

    public static Boolean isNullOrEmpty(List<Object> values) {
        return values == null || values.isEmpty();
    }
}
