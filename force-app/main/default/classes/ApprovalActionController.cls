public with sharing class ApprovalActionController {

    @AuraEnabled(cacheable=true)
    public static Boolean canUserAct() {
        return ApprovalHelper.isUserInApproverGroup();
    }

    @AuraEnabled
    public static void processApproval(Id recordId, String action, String comments) {
        try {
            if (!ApprovalHelper.isUserInApproverGroup()) {
                throw new AuraHandledException('Not authorised to approve.');
            }

            ProcessInstanceWorkitem workitem = [
                SELECT Id FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                LIMIT 1
            ];

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workitem.Id);
            req.setAction(action);
            req.setComments(comments);
            Approval.process(req);

            // ✅ If rejected — write reason to field directly
            if (action == 'Reject') {
                update new Application__c(
                    Id = recordId,
                    Rejection_Reason__c = comments
                );
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, String> getApprovalDetails(Id recordId) {
        Map<String, String> result = new Map<String, String>();
        try {
            List<ProcessInstance> instances = [
                SELECT Id,
                    (SELECT ActorId, Actor.Name, Comments, StepStatus
                     FROM StepsAndWorkitems
                     WHERE StepStatus IN ('Approved', 'Rejected')
                     ORDER BY CreatedDate DESC
                     LIMIT 1)
                FROM ProcessInstance
                WHERE TargetObjectId = :recordId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!instances.isEmpty() && !instances[0].StepsAndWorkitems.isEmpty()) {
                ProcessInstanceHistory step = instances[0].StepsAndWorkitems[0];
                result.put('actorName', step.Actor.Name);
                result.put('comments', step.Comments);
            }
        } catch (Exception e) {}
        return result;
    }
}