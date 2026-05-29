@isTest
public class ApprovalHelperTest {

    @TestSetup
    static void setupData() {
        // Create approver group member
        TestDataFactory.createApproverUser();
    }

    // ✅ Test: User in approver group → returns true
    @isTest
    static void testIsUserInApproverGroup_True() {
        User approver = [
            SELECT Id FROM User 
            WHERE Email = 'testuser@testorg.com' 
            LIMIT 1
        ];

        System.runAs(approver) {
            Test.startTest();
            Boolean result = ApprovalHelper.isUserInApproverGroup();
            Test.stopTest();

            System.assertEquals(true, result, 'Approver should be in group');
        }
    }

    // ✅ Test: User not in approver group → returns false
    @isTest
    static void testIsUserInApproverGroup_False() {
        User nonApprover = TestDataFactory.createAdminUser();

        System.runAs(nonApprover) {
            Test.startTest();
            Boolean result = ApprovalHelper.isUserInApproverGroup();
            Test.stopTest();

            System.assertEquals(false, result, 'Non-approver should not be in group');
        }
    }

    // ✅ Test: getApproverGroupId — returns valid Id
    @isTest
    static void testGetApproverGroupId() {
        Test.startTest();
        Id groupId = ApprovalHelper.getApproverGroupId();
        Test.stopTest();

        System.assertNotEquals(null, groupId, 'Group Id should not be null');
    }

    // ✅ Test: shareWithApproverGroup — shares created
    @isTest
    static void testShareWithApproverGroup() {
        Account acc = TestDataFactory.createAccount('Share Account');
        Contact con = TestDataFactory.createContact('Share', 'share@test.com', acc.Id);
        Application__c app = TestDataFactory.createApplication(acc.Id, con.Id, 'Draft');

        Test.startTest();
        ApprovalHelper.shareWithApproverGroup(new Set<Id>{ app.Id });
        Test.stopTest();

        List<Application__Share> shares = [
            SELECT Id FROM Application__Share
            WHERE ParentId = :app.Id
            AND RowCause = :Schema.Application__Share.RowCause.Manual
        ];
        System.assertEquals(1, shares.size(), 'Share should be created');
    }

    // ✅ Test: shareWithApproverGroup — no duplicate shares
    @isTest
    static void testShareWithApproverGroup_NoDuplicate() {
        Account acc = TestDataFactory.createAccount('Dup Share Account');
        Contact con = TestDataFactory.createContact('Dup', 'dup@test.com', acc.Id);
        Application__c app = TestDataFactory.createApplication(acc.Id, con.Id, 'Draft');

        Test.startTest();
        ApprovalHelper.shareWithApproverGroup(new Set<Id>{ app.Id });
        ApprovalHelper.shareWithApproverGroup(new Set<Id>{ app.Id }); // ✅ second call
        Test.stopTest();

        List<Application__Share> shares = [
            SELECT Id FROM Application__Share
            WHERE ParentId = :app.Id
            AND RowCause = :Schema.Application__Share.RowCause.Manual
        ];
        System.assertEquals(1, shares.size(), 'Should not create duplicate shares');
    }
}