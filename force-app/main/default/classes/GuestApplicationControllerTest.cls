@isTest
public class GuestApplicationControllerTest {

    // ✅ Test: New guest submits — Contact + Application created
    @isTest
    static void testSubmitApplication_NewGuest() {
        Account acc = TestDataFactory.createAccount('Test Account');

        Test.startTest();
        String appId = GuestApplicationController.submitApplication(
            'John Doe',
            'john@test.com',
            acc.Id,
            '',
            'High',
            'New Account',
            10000,
            '',
            '',
            ''
        );
        Test.stopTest();

        // Verify application created
        Application__c app = [
            SELECT Id, Status__c, Is_Guest_Submission__c, Account__c
            FROM Application__c
            WHERE Id = :appId
        ];
        System.assert(
            app.Status__c == 'Draft' || app.Status__c == 'Submitted',
            'Status should be Draft or Submitted'
        );
        System.assertEquals(true, app.Is_Guest_Submission__c, 'Should be guest submission');
        System.assertEquals(acc.Id, app.Account__c, 'Account should match');

        // Verify Contact created
        List<Contact> contacts = [
            SELECT Id, Email FROM Contact WHERE Email = 'john@test.com'
        ];
        System.assertEquals(1, contacts.size(), 'Contact should be created');
    }

    // ✅ Test: Submit with new account name — Account created
    @isTest
    static void testSubmitApplication_NewAccount() {
        Test.startTest();
        String appId = GuestApplicationController.submitApplication(
            'Jane Doe',
            'jane@test.com',
            '',
            'New Test Company',
            'Medium',
            'Amendment',
            5000,
            '',
            '',
            ''
        );
        Test.stopTest();

        Application__c app = [
            SELECT Id, Account__c FROM Application__c WHERE Id = :appId
        ];

        Account acc = [
            SELECT Id, Name FROM Account WHERE Id = :app.Account__c
        ];
        System.assertEquals('New Test Company', acc.Name, 'New account should be created');
    }

    // ✅ Test: Returning guest — existing Contact reused
    @isTest
    static void testSubmitApplication_ExistingContact() {
        Account acc = TestDataFactory.createAccount('Existing Account');
        TestDataFactory.createContact('Existing', 'existing@test.com', acc.Id);

        Test.startTest();
        GuestApplicationController.submitApplication(
            'Existing User',
            'existing@test.com',
            acc.Id,
            '',
            'Low',
            'Renewal',
            2000,
            '',
            '',
            ''
        );
        Test.stopTest();

        // Only 1 contact should exist
        List<Contact> contacts = [
            SELECT Id FROM Contact WHERE Email = 'existing@test.com'
        ];
        System.assertEquals(1, contacts.size(), 'Should reuse existing Contact');
    }

    // ✅ Test: getApplicationDetails — returns correct status
    @isTest
    static void testGetApplicationDetails_Found() {
        Account acc = TestDataFactory.createAccount('Detail Account');
        Contact con = TestDataFactory.createContact('Detail', 'detail@test.com', acc.Id);
        Application__c app = TestDataFactory.createGuestApplication(acc.Id, con.Id);

        Test.startTest();
        Map<String, String> result = GuestApplicationController.getApplicationDetails('detail@test.com');
        Test.stopTest();

        String status = result.get('status');
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(app.Id, result.get('id'), 'App Id should match');
        System.assert(status == 'Draft' || status == 'Submitted', 'Status should be Draft or Submitted, was: ' + status);
    }

    // ✅ Test: getApplicationDetails — no application found
    @isTest
    static void testGetApplicationDetails_NotFound() {
        Test.startTest();
        Map<String, String> result = GuestApplicationController.getApplicationDetails('nobody@test.com');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for unknown email');
    }

    // ✅ Test: searchAccounts — returns matching accounts
    @isTest
    static void testSearchAccounts() {
        TestDataFactory.createAccount('Salesforce Corp');
        TestDataFactory.createAccount('Salesforce Inc');
        TestDataFactory.createAccount('Oracle Ltd');

        Test.startTest();
        List<Map<String, String>> results = GuestApplicationController.searchAccounts('Salesforce');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 Salesforce accounts');
    }

    // ✅ Test: searchAccounts — too short search term
    @isTest
    static void testSearchAccounts_ShortTerm() {
        Test.startTest();
        List<Map<String, String>> results = GuestApplicationController.searchAccounts('S');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty for short term');
    }

    // ✅ Test: checkExistingApplication — found
    @isTest
    static void testCheckExistingApplication_Found() {
        Account acc = TestDataFactory.createAccount('Check Account');
        Contact con = TestDataFactory.createContact('Check', 'check@test.com', acc.Id);
        Application__c app = TestDataFactory.createGuestApplication(acc.Id, con.Id);

        Test.startTest();
        Map<String, String> result = GuestApplicationController.checkExistingApplication(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should find existing application');
        System.assertEquals(app.Id, result.get('id'), 'App Id should match');
    }

    // ✅ Test: checkExistingApplication — not found
    @isTest
    static void testCheckExistingApplication_NotFound() {
        Account acc = TestDataFactory.createAccount('Empty Account');

        Test.startTest();
        Map<String, String> result = GuestApplicationController.checkExistingApplication(acc.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for account with no application');
    }

    // ✅ Test: resubmitApplication — new application created
    @isTest
    static void testResubmitApplication() {
        Account acc = TestDataFactory.createAccount('Resubmit Account');
        Contact con = TestDataFactory.createContact('Resubmit', 'resubmit@test.com', acc.Id);
        Application__c original = TestDataFactory.createApplication(acc.Id, con.Id, 'Rejected');

        Test.startTest();
        String newAppId = GuestApplicationController.resubmitApplication(
            original.Id,
            'testDoc.pdf',
            'dGVzdA==', // base64 for "test"
            'application/pdf'
        );
        Test.stopTest();

        System.assertNotEquals(null, newAppId, 'New app Id should be returned');
        System.assertNotEquals(original.Id, newAppId, 'Should be a different application');

        Application__c newApp = [
            SELECT Status__c, Is_Resubmission__c, Is_Guest_Submission__c
            FROM Application__c
            WHERE Id = :newAppId
        ];
        System.assert(
            newApp.Status__c == 'Draft' || newApp.Status__c == 'Submitted',
            'Status should be Draft or Submitted'
        );
        System.assertEquals(true, newApp.Is_Resubmission__c, 'Should be marked resubmission');
        System.assertEquals(true, newApp.Is_Guest_Submission__c, 'Should be guest submission');
    }

    // ✅ Test: resubmitApplication — original not found
    @isTest
    static void testResubmitApplication_NotFound() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            GuestApplicationController.resubmitApplication(
                'a00gK000000000AAAQ',
                'test.pdf',
                'dGVzdA==',
                'application/pdf'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, exceptionThrown, 'Exception should have been thrown');
    }
}