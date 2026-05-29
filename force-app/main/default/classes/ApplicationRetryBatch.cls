public class ApplicationRetryBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    // 🔹 Backoff logic
    private Integer getBackoffMinutes(Integer retryCount) {
        if (retryCount == 1) return 5;
        if (retryCount == 2) return 10;
        if (retryCount == 3) return 20;
        return 0;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id, Application__c, System__c, Retry_Count__c,
                   Status__c, Last_Attempt_Time__c
            FROM IntegrationLog__c
            WHERE Status__c = 'Failed'
            AND Direction__c = 'Outbound'
            AND Retry_Count__c < 3
        ]);
    }

    public void execute(Database.BatchableContext bc, List<IntegrationLog__c> logs) {

        List<IntegrationLog__c> logsToUpdate = new List<IntegrationLog__c>();

        for (IntegrationLog__c log : logs) {

            try {

                if (log.Application__c == null) continue;

                // 🔹 Safe retry count handling
                Integer currentRetry = (log.Retry_Count__c == null)
                    ? 0
                    : Integer.valueOf(log.Retry_Count__c);

                Integer nextRetry = currentRetry + 1;

                // 🔴 Stop after 3 retries
                if (nextRetry > 3) {
                    log.Status__c = 'Final Failed';
                    log.Is_Retry_Eligible__c = false;
                    logsToUpdate.add(log);
                    continue;
                }

                // 🔥 Backoff logic
                Integer waitMinutes = getBackoffMinutes(nextRetry);

                if (log.Last_Attempt_Time__c != null) {

                    Datetime nextAllowedTime =
                        log.Last_Attempt_Time__c.addMinutes(waitMinutes);

                    if (System.now() < nextAllowedTime) {
                        continue; // ⛔ skip retry (too early)
                    }
                }

                // 🔹 Fetch application
                Application__c app = [
                    SELECT Id, Name, Status__c, Amount__c, Sync_Status__c
                    FROM Application__c
                    WHERE Id = :log.Application__c
                    LIMIT 1
                ];

                // 🔹 Retry integration
                if (log.System__c == 'Oracle') {

                    ApplicationIntegrationService.sendToOracle(app, nextRetry);

                } else if (log.System__c == 'System B') {

                    ApplicationIntegrationService.sendToSystemB(app, nextRetry);
                }

                // 🔹 Update retry metadata
                log.Retry_Count__c = nextRetry;
                log.Last_Attempt_Time__c = System.now();

                logsToUpdate.add(log);

            } catch (Exception e) {

                log.Error_Message__c = e.getMessage();
                log.Retry_Count__c = (log.Retry_Count__c == null ? 1 : log.Retry_Count__c + 1);
                log.Last_Attempt_Time__c = System.now();

                logsToUpdate.add(log);
            }
        }

        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Retry Batch Completed');
    }
}