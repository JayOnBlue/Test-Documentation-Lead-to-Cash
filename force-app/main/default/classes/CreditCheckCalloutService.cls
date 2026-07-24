/**
 * Outbound credit check against the finance provider — the one place order activation
 * touches the network, so it is the one place to mock.
 */
public with sharing class CreditCheckCalloutService {
    public static Boolean passesCreditCheck(Id accountId, Decimal orderTotal) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Credit_Bureau/api/v1/check');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{ 'accountId' => accountId, 'amount' => orderTotal }));
        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) return false;
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return parsed.get('approved') == true;
        } catch (CalloutException e) {
            return false;
        }
    }
}
