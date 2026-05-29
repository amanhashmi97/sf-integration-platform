@isTest
public class TestDataFactory {

    // ✅ Create standard user
    public static User createStandardUser() {
        Profile p = [
            SELECT Id FROM Profile 
            WHERE Name = 'Standard User' 
            LIMIT 1
        ];
        User u = new User(
            FirstName          = 'Test',
            LastName           = 'User',
            Email              = 'testuser@testorg.com',
            Username           = 'testuser' + DateTime.now().getTime() + '@testorg.com',
            Alias              = 'tuser',
            TimeZoneSidKey     = 'America/Los_Angeles',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id
        );
        insert u;
        return u;
    }

    // ✅ Create admin user
    public static User createAdminUser() {
        Profile p = [
            SELECT Id FROM Profile 
            WHERE Name = 'System Administrator' 
            LIMIT 1
        ];
        User u = new User(
            FirstName          = 'Admin',
            LastName           = 'User',
            Email              = 'adminuser@testorg.com',
            Username           = 'adminuser' + DateTime.now().getTime() + '@testorg.com',
            Alias              = 'auser',
            TimeZoneSidKey     = 'America/Los_Angeles',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id
        );
        insert u;
        return u;
    }

    // ✅ Create approver user and add to approver group
    public static User createApproverUser() {
        return createStandardUser(); // ✅ just create user, group assignment handled in test
    }

    // ✅ Create Account
    public static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    // ✅ Create Contact
    public static Contact createContact(String lastName, String email, Id accountId) {
        Contact con = new Contact(
            LastName  = lastName,
            Email     = email,
            AccountId = accountId
        );
        insert con;
        return con;
    }

    // ✅ Create Application
    public static Application__c createApplication(
        Id accountId, Id contactId, String status
    ) {
        Application__c app = new Application__c(
            Account__c          = accountId,
            Contact__c          = contactId,
            Priority__c         = 'High',
            Application_Type__c = 'New Account',
            Amount__c           = 10000,
            Status__c           = status
        );
        insert app;
        return app;
    }

    // ✅ Create guest application
    public static Application__c createGuestApplication(
        Id accountId, Id contactId
    ) {
        Application__c app = new Application__c(
            Account__c             = accountId,
            Contact__c             = contactId,
            Priority__c            = 'High',
            Application_Type__c    = 'New Account',
            Amount__c              = 10000,
            Status__c              = 'Draft',
            Is_Guest_Submission__c = true
        );
        insert app;
        return app;
    }

    // ✅ Create ApplicationDocument
    public static ApplicationDocument__c createApplicationDocument(
        Id appId, String fileName, String fileContent
    ) {
        ApplicationDocument__c doc = new ApplicationDocument__c(
            Application__c  = appId,
            File_Name__c    = fileName,
            File_Content__c = fileContent
        );
        insert doc;
        return doc;
    }
}