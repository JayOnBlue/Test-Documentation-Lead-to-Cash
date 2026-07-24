/**
 * Read-only aggregates for the pipeline dashboard: funnel by stage, top open deals, and
 * lead-source conversion counts. All @AuraEnabled, all cacheable.
 */
public with sharing class SalesMetricsService {
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> pipelineByStage() {
        Map<String, Decimal> out = new Map<String, Decimal>();
        for (AggregateResult r : [SELECT StageName st, SUM(Amount) total FROM Opportunity
                                  WHERE IsClosed = false GROUP BY StageName]) {
            out.put((String) r.get('st'), (Decimal) r.get('total'));
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> topOpenDeals() {
        return [SELECT Id, Name, Amount, StageName, Account.Name FROM Opportunity
                WHERE IsClosed = false AND Amount != null ORDER BY Amount DESC LIMIT 10];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> leadCountBySource() {
        Map<String, Integer> out = new Map<String, Integer>();
        for (AggregateResult r : [SELECT LeadSource src, COUNT(Id) cnt FROM Lead
                                  WHERE IsConverted = false GROUP BY LeadSource]) {
            String src = (String) r.get('src');
            out.put(src == null ? 'Unknown' : src, (Integer) r.get('cnt'));
        }
        return out;
    }
}
