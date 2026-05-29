trigger ApplicationTrigger on Application__c (after insert, after update) {

    if (Trigger.isInsert) {
        ApplicationTriggerHandler.handleAfterInsert(Trigger.new);
    }

    if (Trigger.isUpdate) {
        ApplicationTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}