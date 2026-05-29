global class ApplicationRetryScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {

        Database.executeBatch(new ApplicationRetryBatch(), 10);
    }
}