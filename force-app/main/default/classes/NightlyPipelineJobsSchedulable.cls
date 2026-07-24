/**
 * One scheduler to own the nightly jobs, in dependency-safe order. Schedule once with:
 * System.schedule('Nightly sales jobs', '0 0 3 * * ?', new NightlyPipelineJobsSchedulable());
 */
public with sharing class NightlyPipelineJobsSchedulable implements Schedulable {
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new LeadNurtureBatch(), 200);
        Database.executeBatch(new StaleOpportunityBatch(), 100);
        Database.executeBatch(new QuoteExpiryBatch(), 100);
        Database.executeBatch(new PipelineSnapshotBatch(), 500);
    }
}
