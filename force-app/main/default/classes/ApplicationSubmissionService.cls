public with sharing class ApplicationSubmissionService {

    @AuraEnabled
    public static void submitApplication(Id appId) {
        submitApplicationBulk(new List<Id>{ appId });
    }

    @InvocableMethod(label='Submit Application' description='Submits Application__c records for approval')
    public static void submitApplicationFromFlow(List<Id> appIds) {
        submitApplicationBulk(appIds);
    }

    // ✅ Single private method — one SOQL, one DML, bulk Approval call
    private static void submitApplicationBulk(List<Id> appIds) {
        
        List<Application__c> apps = [
            SELECT Id, Status__c, OwnerId
            FROM Application__c
            WHERE Id IN :appIds
        ];

        List<Application__c> toUpdate = new List<Application__c>();
        List<Approval.ProcessSubmitRequest> approvalRequests = 
            new List<Approval.ProcessSubmitRequest>();

        for (Application__c app : apps) {

            // 🔒 Owner check
            if (app.OwnerId != UserInfo.getUserId()) {
                throw new AuraHandledException(
                    'Only the owner can submit this application.'
                );
            }

            // 🔒 Status check
            if (app.Status__c != 'Draft') {
                throw new AuraHandledException(
                    'Only Draft applications can be submitted.'
                );
            }

            app.Status__c = 'Submitted';
            toUpdate.add(app);

            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(app.Id);
            approvalRequests.add(req);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;                          // ✅ 1 DML
            Approval.process(approvalRequests);       // ✅ 1 bulk approval call
        }
    }
}