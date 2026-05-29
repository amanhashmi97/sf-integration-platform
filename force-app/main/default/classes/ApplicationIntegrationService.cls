public with sharing class ApplicationIntegrationService {

    // 🔹 Original method (used by trigger/queueable)
    public static void sendToOracle(Application__c app) {
        sendToOracle(app, 0);
    }

    // 🔹 New method (used by retry)
    public static void sendToOracle(Application__c app, Decimal retryCount) {

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('name', app.Name);
        payload.put('status', app.Status__c);
        payload.put('amount', app.Amount__c);

        String requestBody = JSON.serialize(payload);

        IntegrationLog__c log = new IntegrationLog__c();
        log.Application__c = app.Id;
        log.Application_Name__c = app.Name;
        log.Direction__c = 'Outbound';
        log.System__c = 'Oracle';
        log.Request_Payload__c = requestBody;
        log.Is_Latest__c = true;
        log.Timestamp__c = System.now();
        log.Retry_Count__c = retryCount;

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Oracle_API/posts');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            String status = res.getStatus();
            String responseBody = res.getBody();

            if (statusCode == 200 || statusCode == 201) {

                app.Sync_Status__c = 'Synced';
                app.Last_Sync_Date__c = System.now();
                app.Sync_Error_Message__c = null;

                log.Status__c = 'Success';
                log.Integration_Type__c = 'Batch';
                log.Response_Payload__c = responseBody;
                log.HTTP_Status_Code__c = statusCode;
                log.Last_Attempt_Time__c = System.now();

            } else {

                String errorMsg = 'HTTP ' + statusCode + ' - ' + status;

                if (String.isNotBlank(responseBody)) {
                    errorMsg += ' | Response: ' + responseBody;
                }

                app.Sync_Status__c = 'Sync Failed';
                app.Sync_Error_Message__c = errorMsg;

                if (retryCount >= 3) {
                    log.Status__c = 'Final Failed';
                    log.Is_Retry_Eligible__c = false;

                } else {
                    log.Status__c = 'Failed';
                }

                log.Integration_Type__c = 'Retry';
                log.Response_Payload__c = responseBody;
                log.HTTP_Status_Code__c = statusCode;
                log.Error_Message__c = errorMsg;
                log.Last_Attempt_Time__c = System.now();
            }

        } catch (Exception e) {

            app.Sync_Status__c = 'Sync Failed';
            app.Sync_Error_Message__c = e.getMessage();

            if (retryCount >= 3) {
                log.Status__c = 'Final Failed';
                log.Is_Retry_Eligible__c = false;

            } else {
                log.Status__c = 'Failed';
            }
            log.Integration_Type__c = 'Retry';
            log.Error_Message__c = e.getMessage();
            log.Last_Attempt_Time__c = System.now();
        }

        insert log;

        System.debug('--- RETRY DEBUG START ---');
        System.debug('Incoming retryCount param: ' + retryCount);
        System.debug('Log Retry_Count__c from DB: ' + log.Retry_Count__c);
        System.debug('--- RETRY DEBUG END ---');

        if (log.Status__c == 'Final Failed') {
            Id supportUserId = getSupportUserId();
            sendFailureEmail(log, supportUserId);
        }

        List<IntegrationLog__c> oldLogs = [
            SELECT Id
            FROM IntegrationLog__c
            WHERE Application__c = :app.Id
            AND System__c = 'Oracle'
            AND Id != :log.Id
            AND Is_Latest__c = true
        ];

        for (IntegrationLog__c old : oldLogs) {
            old.Is_Latest__c = false;
        }

        update oldLogs;

        update app;
    }

    public static void sendToSystemB(Application__c app) {
        sendToSystemB(app, 0);
    }

    public static void sendToSystemB(Application__c app, Decimal retryCount) {

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('applicationId', app.Id);
        payload.put('status', app.Status__c);
        payload.put('message', 'Application Approved');

        String requestBody = JSON.serialize(payload);

        IntegrationLog__c log = new IntegrationLog__c();
        log.Application__c = app.Id;
        log.Application_Name__c = app.Name;
        log.Direction__c = 'Outbound';
        log.System__c = 'System B';
        log.Request_Payload__c = requestBody;
        log.Is_Latest__c = true;
        log.Timestamp__c = System.now();
        log.Retry_Count__c = retryCount;

        System.debug('--- ENTER TRY BLOCK ---');

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:SystemB_API/posts');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(requestBody);

            System.debug('--- BEFORE CALLOUT ---');

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('--- AFTER CALLOUT ---');
            System.debug('Status Code: ' + res.getStatusCode());

            Integer statusCode = res.getStatusCode();
            String status = res.getStatus();
            String responseBody = res.getBody();

            if (statusCode == 200 || statusCode == 201) {

                System.debug('--- SUCCESS BLOCK ---');

                log.Status__c = 'Success';
                log.Integration_Type__c = 'Batch';
                log.Response_Payload__c = responseBody;
                log.HTTP_Status_Code__c = statusCode;
                log.Last_Attempt_Time__c = System.now();

            } else {

                System.debug('--- FAILURE BLOCK ---');

                String errorMsg = 'HTTP ' + statusCode + ' - ' + status;

                if (String.isNotBlank(responseBody)) {
                    errorMsg += ' | Response: ' + responseBody;
                }

                if (retryCount >= 3) {
                    log.Status__c = 'Final Failed';
                    log.Is_Retry_Eligible__c = false;

                } else {
                    log.Status__c = 'Failed';
                }
                log.Integration_Type__c = 'Retry';
                log.Response_Payload__c = responseBody;
                log.HTTP_Status_Code__c = statusCode;
                log.Error_Message__c = errorMsg;
                log.Last_Attempt_Time__c = System.now();
            }

        } catch (Exception e) {

            System.debug('--- EXCEPTION BLOCK ---');

            if (retryCount >= 3) {
                log.Status__c = 'Final Failed';
                log.Is_Retry_Eligible__c = false;

            } else {
                log.Status__c = 'Failed';
            }
            log.Integration_Type__c = 'Retry';
            log.Error_Message__c = e.getMessage();
            log.Last_Attempt_Time__c = System.now();
        }

        insert log;

        System.debug('--- RETRY DEBUG START ---');
        System.debug('Incoming retryCount param: ' + retryCount);
        System.debug('Log Retry_Count__c from DB: ' + log.Retry_Count__c);
        System.debug('--- RETRY DEBUG END ---');

        if (log.Status__c == 'Final Failed') {
            Id supportUserId = getSupportUserId();
            sendFailureEmail(log, supportUserId);
        }

        List<IntegrationLog__c> oldLogs = [
            SELECT Id
            FROM IntegrationLog__c
            WHERE Application__c = :app.Id
            AND System__c = 'System B'
            AND Id != :log.Id
            AND Is_Latest__c = true
        ];

        for (IntegrationLog__c old : oldLogs) {
            old.Is_Latest__c = false;
        }

        update oldLogs;
    }

    public static void sendToSplunk(String errorMessage, String systemName, Id appId) {

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('applicationId', appId);
        payload.put('system', systemName);
        payload.put('error', errorMessage);
        payload.put('timestamp', System.now());

        String requestBody = JSON.serialize(payload);

        System.debug('Splunk Payload: ' + requestBody);

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Splunk_API/posts');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            // 🔹 Add debug here
            System.debug('Splunk Response Status: ' + res.getStatusCode());
            System.debug('Splunk Response Body: ' + res.getBody());

        } catch (Exception e) {
            System.debug('Splunk logging failed: ' + e.getMessage());
        }
    }

    public static void sendFailureEmail(IntegrationLog__c log, Id supportUserId) {

        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            Id templateId = getEmailTemplateId();

            System.debug('Template id: ' + templateId);

            if (templateId == null) {
                System.debug('Template Id is NULL — aborting email');
                return;
            }

            mail.setTargetObjectId(supportUserId);

            mail.setWhatId(log.Id);

            mail.setTemplateId(templateId);

            mail.setSaveAsActivity(false);

            System.debug('Running user: ' + UserInfo.getUserId());
            System.debug('Support user: ' + supportUserId);
            System.debug('Log Id: ' + log.Id);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        } catch (Exception e) {
            System.debug('Email failed: ' + e.getMessage());
        }
    }

    public static Id getSupportUserId() {

        try {
            Contact c = [
                SELECT Id 
                FROM Contact 
                WHERE Email = :System.Label.Support_User_Email 
                LIMIT 1
            ];
            return c.Id;

        } catch (Exception e) {
            System.debug('Support user not found: ' + e.getMessage());
            return UserInfo.getUserId(); // fallback
        }
    }

    public static Id getEmailTemplateId() {
        try {
            EmailTemplate t = [
                SELECT Id, DeveloperName
                FROM EmailTemplate
                WHERE DeveloperName = :System.Label.Email_Template_DevName
                LIMIT 1
            ];
            return t.Id;
        } catch (Exception e) {
            System.debug('Template not found: ' + e.getMessage());
            return null;
        }
    }

}