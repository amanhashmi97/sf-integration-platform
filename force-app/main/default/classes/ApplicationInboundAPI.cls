@RestResource(urlMapping='/application')
global with sharing class ApplicationInboundAPI {

    @HttpPost
    global static String updateApplication() {

        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();

        // 🔹 Create log (before processing)
        IntegrationLog__c log = new IntegrationLog__c();
        log.Direction__c = 'Inbound';
        log.System__c = 'External System';
        log.Timestamp__c = System.now();
        log.Request_Payload__c = requestBody;
        log.Status__c = 'In Progress';

        try {
            // 🔹 Parse JSON
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

            String externalId = (String) data.get('externalId');
            String status = (String) data.get('status');
            Decimal amount = (Decimal) data.get('amount');

            // 🔹 Validate External ID
            if (String.isBlank(externalId)) {
                log.Status__c = 'Failed';
                log.Error_Message__c = 'External ID is required';
                log.Response_Payload__c = 'External ID is required';

                insert log;
                return 'Error: External ID is required';
            }

            // 🔹 Query using External ID
            List<Application__c> apps = [
                SELECT Id, Name, External_ID__c, Status__c, Amount__c
                FROM Application__c
                WHERE External_ID__c = :externalId
                LIMIT 1
            ];

            if (apps.isEmpty()) {
                log.Status__c = 'Failed';
                log.Error_Message__c = 'No application found for given External ID';
                log.Response_Payload__c = 'No application found for given External ID';

                insert log;
                return 'Error: No application found';
            }

            Application__c app = apps[0];

            // 🔹 Link log to application
            log.Application__c = app.Id;

            // 🔹 Partial updates (safe)
            if (status != null) {
                app.Status__c = status;
            }

            if (amount != null) {
                app.Amount__c = amount;
            }

            // 🔹 Update record
            update app;

            // 🔹 Success log
            log.Status__c = 'Success';
            log.Response_Payload__c = 'Application updated successfully';

            insert log;

            return 'Success';

        } catch (Exception e) {

            // 🔹 Failure log
            log.Status__c = 'Failed';
            log.Error_Message__c = e.getMessage();
            log.Response_Payload__c = e.getMessage();

            insert log;

            return 'Error: ' + e.getMessage();
        }
    }
}