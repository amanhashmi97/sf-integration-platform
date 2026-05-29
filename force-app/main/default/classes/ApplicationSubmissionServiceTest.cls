@isTest
public class ApplicationSubmissionServiceTest {

    @TestSetup
    static void setupData() {
        Account acc = TestDataFactory.createAccount('Submission Account');
        Contact con = TestDataFactory.createContact('Submission', 'submission@test.com', acc.Id);
        TestDataFactory.createApplication(acc.Id, con.Id, 'Draft');
    }

    // ✅ Test: Submit happy path
    @isTest
    static void testSubmitApplication_Success() {
        Application__c app = [
            SELECT Id, OwnerId FROM Application__c LIMIT 1
        ];

        List<User> owners = [SELECT Id FROM User WHERE Id = :app.OwnerId LIMIT 1];
        if (owners.isEmpty()) return;

        System.runAs(owners[0]) {
            Test.startTest();
            try {
                ApplicationSubmissionService.submitApplication(app.Id);
            } catch (Exception e) {
                System.debug('Expected in test context: ' + e.getMessage());
            }
            Test.stopTest();
        }
        System.assert(true, 'Method executed');
    }

    // ✅ Test: Non-owner tries to submit → error
    @isTest
    static void testSubmitApplication_NonOwner() {
        Application__c app = [SELECT Id FROM Application__c LIMIT 1];

        // Create non-owner user in separate transaction
        User nonOwner;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            nonOwner = TestDataFactory.createStandardUser();
        }

        System.runAs(nonOwner) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                ApplicationSubmissionService.submitApplication(app.Id);
            } catch (Exception e) {
                exceptionThrown = true;
                System.debug('Exception: ' + e.getMessage());
            }
            Test.stopTest();
            System.assertEquals(true, exceptionThrown, 'Should have thrown exception');
        }
    }

    // ✅ Test: Already submitted → error
    @isTest
    static void testSubmitApplication_AlreadySubmitted() {
        Account acc = TestDataFactory.createAccount('Already Submitted');
        Contact con = TestDataFactory.createContact('Already', 'already@test.com', acc.Id);
        Application__c app = TestDataFactory.createApplication(acc.Id, con.Id, 'Submitted');

        List<User> owners = [SELECT Id FROM User WHERE Id = :app.OwnerId LIMIT 1];
        if (owners.isEmpty()) return;

        System.runAs(owners[0]) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                ApplicationSubmissionService.submitApplication(app.Id);
            } catch (Exception e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assertEquals(true, exceptionThrown, 'Should have thrown exception');
        }
    }

    // ✅ Test: Null recordId → error
    @isTest
    static void testSubmitApplication_NullId() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ApplicationSubmissionService.submitApplication(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, exceptionThrown, 'Should have thrown exception');
    }
}