public with sharing class ApprovalHelper {

    @AuraEnabled(cacheable=true)
    public static Boolean isUserInApproverGroup() {
        try {
            String groupDevName = System.Label.Approver_Group_Name;

            Group g = [
                SELECT Id FROM Group
                WHERE DeveloperName = :groupDevName
                LIMIT 1
            ];

            List<GroupMember> gm = [
                SELECT Id FROM GroupMember
                WHERE UserOrGroupId = :UserInfo.getUserId()
                AND GroupId = :g.Id
            ];

            return !gm.isEmpty();

        } catch (Exception e) {
            return false;
        }
    }

    public static Id getApproverGroupId() {
        String groupDevName = System.Label.Approver_Group_Name;
        List<Group> groups = [
            SELECT Id FROM Group
            WHERE DeveloperName = :groupDevName
            LIMIT 1
        ];
        return groups.isEmpty() ? null : groups[0].Id;
    }

    public static void shareWithApproverGroup(Set<Id> appIds) {
        Id groupId = getApproverGroupId();
        if (groupId == null) return;

        Set<Id> alreadyShared = new Set<Id>();
        for (Application__Share existing : [
            SELECT ParentId FROM Application__Share
            WHERE ParentId IN :appIds
            AND UserOrGroupId = :groupId
            AND RowCause = :Schema.Application__Share.RowCause.Manual
        ]) {
            alreadyShared.add(existing.ParentId);
        }

        List<Application__Share> shares = new List<Application__Share>();
        for (Id appId : appIds) {
            if (!alreadyShared.contains(appId)) {
                shares.add(new Application__Share(
                    ParentId      = appId,
                    UserOrGroupId = groupId,
                    AccessLevel   = 'Read',
                    RowCause      = Schema.Application__Share.RowCause.Manual
                ));
            }
        }
        if (!shares.isEmpty()) insert shares;
    }
}