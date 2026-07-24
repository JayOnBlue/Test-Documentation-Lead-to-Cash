/**
 * Tax estimation for quotes and orders via the external tax engine; failures degrade to a
 * flat conservative rate rather than blocking the transaction.
 */
public with sharing class TaxCalculationCalloutService {
    public static final Decimal FALLBACK_RATE_PCT = 10;

    public static Decimal estimateTax(Decimal amount, String billingState) {
        if (amount == null || amount <= 0) return 0;
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Tax_Engine/api/v3/estimate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{ 'amount' => amount, 'state' => billingState }));
        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return ((Decimal) parsed.get('tax')).setScale(2);
            }
        } catch (CalloutException e) {
            // fall through to the conservative fallback
        }
        return (amount * FALLBACK_RATE_PCT / 100).setScale(2);
    }
}
