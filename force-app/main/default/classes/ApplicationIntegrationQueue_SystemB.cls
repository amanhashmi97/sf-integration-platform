public with sharing class ApplicationIntegrationQueue_SystemB implements Queueable, Database.AllowsCallouts {

    private Id applicationId;

    public ApplicationIntegrationQueue_SystemB(Id applicationId) {
        this.applicationId = applicationId;
    }

    public void execute(QueueableContext context) {

        Application__c app = [
            SELECT Id, Name, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        ApplicationIntegrationService.sendToSystemB(app);
    }
}