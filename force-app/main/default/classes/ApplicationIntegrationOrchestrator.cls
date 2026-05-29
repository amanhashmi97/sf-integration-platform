public class ApplicationIntegrationOrchestrator implements Queueable {

    private Set<Id> appIds;

    public ApplicationIntegrationOrchestrator(Set<Id> appIds) {
        this.appIds = appIds;
    }

    public void execute(QueueableContext context) {

        // 🔥 SCALING DECISION HERE
        if (appIds.size() > 25) {

            // Large data → Batch
            Database.executeBatch(
                new ApplicationIntegrationBatch(appIds),
                10
            );

        } else {

            // Normal → Queueables
            for (Id appId : appIds) {

                System.enqueueJob(new ApplicationIntegrationQueue(appId));
                System.enqueueJob(new ApplicationIntegrationQueue_SystemB(appId));
            }
        }
    }
}