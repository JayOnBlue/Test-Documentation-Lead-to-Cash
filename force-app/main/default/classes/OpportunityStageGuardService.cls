/**
 * Stage hygiene rules, enforced in the before-update context:
 *   - stages can't be skipped forward more than one step,
 *   - a deal can't reach Proposal without line items,
 *   - a deal can't be Closed Won without an accepted quote (checked via QuoteApprovalService),
 *   - closing requires an Amount.
 */
public with sharing class OpportunityStageGuardService {
    private static final List<String> STAGE_ORDER = new List<String>{
        'Prospecting', 'Qualification', 'Needs Analysis', 'Proposal/Price Quote', 'Negotiation/Review', 'Closed Won'
    };

    public static void enforce(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        Set<Id> needLineCheck = new Set<Id>();
        Set<Id> needQuoteCheck = new Set<Id>();
        for (Opportunity o : opps) {
            Opportunity prior = oldMap.get(o.Id);
            if (o.StageName == prior.StageName) continue;
            Integer fromIdx = STAGE_ORDER.indexOf(prior.StageName);
            Integer toIdx = STAGE_ORDER.indexOf(o.StageName);
            if (fromIdx >= 0 && toIdx > fromIdx + 1 && o.StageName != 'Closed Won') {
                o.addError('Stages cannot be skipped: move one stage at a time (from ' + prior.StageName + ').');
                continue;
            }
            if (toIdx >= STAGE_ORDER.indexOf('Proposal/Price Quote')) needLineCheck.add(o.Id);
            if (o.StageName == 'Closed Won') {
                needQuoteCheck.add(o.Id);
                if (!ValidationUtils.isPositive(o.Amount)) o.addError('Closed Won requires a positive Amount.');
            }
        }
        if (!needLineCheck.isEmpty()) {
            Set<Id> withLines = new Set<Id>();
            for (AggregateResult r : [SELECT OpportunityId oid FROM OpportunityLineItem WHERE OpportunityId IN :needLineCheck GROUP BY OpportunityId]) {
                withLines.add((Id) r.get('oid'));
            }
            for (Opportunity o : opps) {
                if (needLineCheck.contains(o.Id) && !withLines.contains(o.Id)) {
                    o.addError('Add at least one product before moving to ' + o.StageName + '.');
                }
            }
        }
        if (!needQuoteCheck.isEmpty()) {
            Set<Id> withAcceptedQuote = QuoteApprovalService.opportunitiesWithAcceptedQuote(needQuoteCheck);
            for (Opportunity o : opps) {
                if (needQuoteCheck.contains(o.Id) && !withAcceptedQuote.contains(o.Id)) {
                    o.addError('Closed Won requires an Accepted quote on this opportunity.');
                }
            }
        }
    }
}
