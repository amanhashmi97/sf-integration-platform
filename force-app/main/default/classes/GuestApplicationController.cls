public without sharing class GuestApplicationController {

    @AuraEnabled
    public static Map<String, String> getApplicationDetails(String email) {
        // First find Contact by email
        List<Contact> contacts = [
            SELECT Id FROM Contact WHERE Email = :email LIMIT 1
        ];
        if (contacts.isEmpty()) return null;

        // Then find Application by Contact
        List<Application__c> apps = [
            SELECT Id, Name, Status__c, Rejection_Reason__c
            FROM Application__c
            WHERE Contact__c = :contacts[0].Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (apps.isEmpty()) return null;

        return new Map<String, String>{
            'id'              => apps[0].Id,
            'name'            => apps[0].Name,
            'status'          => apps[0].Status__c,
            'rejectionReason' => apps[0].Rejection_Reason__c != null 
                                ? apps[0].Rejection_Reason__c : ''
        };
    }

    @AuraEnabled
    public static List<Map<String, String>> searchAccounts(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) return results;
        String query = '%' + searchTerm + '%';
        for (Account acc : [
            SELECT Id, Name FROM Account
            WHERE Name LIKE :query
            ORDER BY Name LIMIT 10
        ]) {
            results.add(new Map<String, String>{
                'id' => acc.Id, 'name' => acc.Name
            });
        }
        return results;
    }

    @AuraEnabled
    public static Map<String, String> checkExistingApplication(Id accountId) {
        List<Application__c> apps = [
            SELECT Id, Status__c, Name
            FROM Application__c
            WHERE Account__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (apps.isEmpty()) return null;
        return new Map<String, String>{
            'id'     => apps[0].Id,
            'status' => apps[0].Status__c,
            'name'   => apps[0].Name
        };
    }

    @AuraEnabled
    public static String submitApplication(String applicantName, String email, String accountId, String newAccountName, String priority, String applicationType, Decimal amount, String fileName, String fileContent, String fileType ) {
        System.debug('=== submitApplication called ===');
        System.debug('fileName: ' + fileName);
        System.debug('fileContent length: ' + (fileContent != null ? fileContent.length() : 0));
        System.debug('fileContent blank: ' + String.isBlank(fileContent));
        try {
            Id resolvedAccountId;
            if (String.isNotBlank(accountId)) {
                resolvedAccountId = (Id) accountId;
            } else {
                Account newAcc = new Account(Name = newAccountName);
                insert newAcc;
                resolvedAccountId = newAcc.Id;
            }

            List<Contact> contacts = [
                SELECT Id FROM Contact WHERE Email = :email LIMIT 1
            ];
            Contact con;
            if (!contacts.isEmpty()) {
                con = contacts[0];
            } else {
                con = new Contact(
                    LastName  = applicantName,
                    Email     = email,
                    AccountId = resolvedAccountId
                );
                insert con;
            }

            Application__c app = new Application__c(
                Account__c             = resolvedAccountId,
                Contact__c             = con.Id,
                Priority__c            = priority,
                Application_Type__c    = applicationType,
                Amount__c              = amount,
                Status__c              = 'Draft',
                Is_Guest_Submission__c = true
            );
            insert app;

            System.debug('fileContent blank check: ' + String.isBlank(fileContent));
            System.debug('fileName blank check: ' + String.isBlank(fileName));
            System.debug('condition result: ' + (String.isNotBlank(fileContent) && String.isNotBlank(fileName)));
            // ✅ File handled in same transaction
            if (String.isNotBlank(fileContent) && String.isNotBlank(fileName)) {
                System.debug('=== calling linkFile ===');
                SystemFileUpload.linkFile(app.Id, fileName, fileContent);
                System.debug('=== linkFile called ===');
            }

            return app.Id;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Submission failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String resubmitApplication(Id originalAppId, String fileName, String fileContent, String fileType) {
        try {
            // ✅ Debug — remove after testing
            if (String.isBlank(fileContent)) {
                throw new AuraHandledException('DEBUG: fileContent empty in resubmit');
            }
            if (String.isBlank(fileName)) {
                throw new AuraHandledException('DEBUG: fileName empty in resubmit');
            }

            List<Application__c> originals = [
                SELECT Account__c, Contact__c, Priority__c,
                    Application_Type__c, Amount__c
                FROM Application__c
                WHERE Id = :originalAppId
                LIMIT 1
            ];

            if (originals.isEmpty()) {
                throw new AuraHandledException('Original application not found.');
            }
            Application__c original = originals[0];

            Application__c newApp = new Application__c(
                Account__c             = original.Account__c,
                Contact__c             = original.Contact__c,
                Priority__c            = original.Priority__c,
                Application_Type__c    = original.Application_Type__c,
                Amount__c              = original.Amount__c,
                Status__c              = 'Draft',
                Is_Guest_Submission__c = true,
                Is_Resubmission__c     = true
            );
            insert newApp;

            if (String.isNotBlank(fileContent) && String.isNotBlank(fileName)) {
                SystemFileUpload.linkFile(newApp.Id, fileName, fileContent);
            }

            return newApp.Id;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Resubmission failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void uploadFile(Id appId, String fileName,
            String fileContent, String fileType) {
        if (String.isBlank(fileContent)) {
            throw new AuraHandledException('DEBUG: fileContent is empty');
        }
        if (String.isBlank(fileName)) {
            throw new AuraHandledException('DEBUG: fileName is empty');
        }
        try {
            SystemFileUpload.linkFile(String.valueOf(appId), fileName, fileContent);
        } catch (Exception e) {
            throw new AuraHandledException('File upload failed: ' + e.getMessage());
        }
    }
}