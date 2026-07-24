/**
 * Trigger handler for Lead. Before-insert: dedupe + score. Before-update: rescore when
 * scoring inputs changed. After-update: auto-convert leads that just went Hot.
 */
public with sharing class LeadTriggerHandler {
    public static void beforeInsert(List<Lead> leads) {
        LeadDedupeService.flagDuplicates(leads);
        LeadScoringService.scoreLeads(leads);
        LeadAssignmentService.assignOwners(leads);
    }

    public static void beforeUpdate(List<Lead> leads, Map<Id, Lead> oldMap) {
        List<Lead> toRescore = new List<Lead>();
        for (Lead l : leads) {
            Lead prior = oldMap.get(l.Id);
            if (l.Email != prior.Email || l.Industry != prior.Industry
                || l.AnnualRevenue != prior.AnnualRevenue || l.NumberOfEmployees != prior.NumberOfEmployees) {
                toRescore.add(l);
            }
        }
        if (!toRescore.isEmpty()) LeadScoringService.scoreLeads(toRescore);
    }

    public static void afterUpdate(List<Lead> leads, Map<Id, Lead> oldMap) {
        if (TriggerControl.isBypassed('Lead')) return;
        List<Lead> nowHot = new List<Lead>();
        for (Lead l : leads) {
            if (l.Rating == 'Hot' && oldMap.get(l.Id).Rating != 'Hot' && !l.IsConverted) nowHot.add(l);
        }
        if (!nowHot.isEmpty()) {
            TriggerControl.bypass('Lead');
            LeadConversionService.convertQualified(nowHot);
            TriggerControl.clearBypass('Lead');
        }
    }
}
