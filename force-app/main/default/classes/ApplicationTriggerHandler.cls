public with sharing class ApplicationTriggerHandler {

    public static void handleAfterInsert(List<Application__c> newList) {

        Set<Id> appIds = new Set<Id>();

        for (Application__c rec : newList) {
            if (rec.Status__c == 'Approved') {
                appIds.add(rec.Id);
            }
        }

        enqueue(appIds);
    }

    public static void handleAfterUpdate(List<Application__c> newList, Map<Id, Application__c> oldMap) {

        Set<Id> appIds = new Set<Id>();

        for (Application__c newRec : newList) {

            Application__c oldRec = oldMap.get(newRec.Id);
            if (oldRec == null) continue;

            if (newRec.Status__c == 'Approved' &&
                oldRec.Status__c != 'Approved') {

                appIds.add(newRec.Id);
            }
        }

        if (!appIds.isEmpty()) {

            // Share with approver group
            ApprovalHelper.shareWithApproverGroup(appIds);

            // Trigger async processing (if needed)
            enqueue(appIds);
        }
    }

    private static void enqueue(Set<Id> appIds) {

        if (appIds.isEmpty()) return;

        System.enqueueJob(new ApplicationIntegrationOrchestrator(appIds));
    }
}