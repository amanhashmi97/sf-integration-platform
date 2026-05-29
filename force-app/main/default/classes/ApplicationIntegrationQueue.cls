public with sharing class ApplicationIntegrationQueue implements Queueable, Database.AllowsCallouts {

    private Id applicationId;

    public ApplicationIntegrationQueue(Id applicationId) {
        this.applicationId = applicationId;
    }

    public void execute(QueueableContext context) {

        Application__c app = [
            SELECT Id, Name, Status__c, Amount__c, Sync_Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        ApplicationIntegrationService.sendToOracle(app);
    }
}