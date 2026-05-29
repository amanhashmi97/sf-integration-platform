public class ApplicationIntegrationBatch implements Database.Batchable<Id>, Database.AllowsCallouts {

    private Set<Id> appIds;

    public ApplicationIntegrationBatch(Set<Id> appIds) {
        this.appIds = appIds;
    }

    public Iterable<Id> start(Database.BatchableContext bc) {
        return appIds;
    }

    public void execute(Database.BatchableContext bc, List<Id> scope) {

        for (Id appId : scope) {

            System.enqueueJob(new ApplicationIntegrationQueue(appId));
            System.enqueueJob(new ApplicationIntegrationQueue_SystemB(appId));
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Integration Batch Completed');
    }
}