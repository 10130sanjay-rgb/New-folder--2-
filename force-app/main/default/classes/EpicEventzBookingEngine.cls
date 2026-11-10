public with sharing class EpicEventzBookingEngine {
    public class TransactionResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String status;
        @AuraEnabled public String referenceId;

        public TransactionResponse(Boolean success, String status, String referenceId) {
            this.success = success;
            this.status = status;
            this.referenceId = referenceId;
        }
    }

    @AuraEnabled
    public static TransactionResponse executeTransaction(Id eventId, Id attendeeId, Integer ticketCount) {
        Savepoint transactionSavepoint = Database.setSavepoint();
        try {
            if (eventId == null || attendeeId == null || ticketCount == null || ticketCount < 1) {
                return new TransactionResponse(false, 'INVALID_INPUT', null);
            }

            List<Event__c> events = [
                SELECT Id, Name
                FROM Event__c
                WHERE Id = :eventId
                FOR UPDATE
            ];
            if (events.isEmpty()) {
                return new TransactionResponse(false, 'EVENT_NOT_FOUND', null);
            }

            Map<String, Schema.SObjectField> registrationFields =
                Registration__c.SObjectType.getDescribe().fields.getMap();
            if (!registrationFields.containsKey('Event__c')
                || !registrationFields.containsKey('Attendee__c')) {
                return new TransactionResponse(false, 'REGISTRATION_SCHEMA_UNAVAILABLE', null);
            }

            String statusField = registrationFields.containsKey('Status__c')
                ? 'Status__c'
                : registrationFields.containsKey('Registration_Status__c')
                    ? 'Registration_Status__c'
                    : null;
            if (statusField == null) {
                return new TransactionResponse(false, 'REGISTRATION_STATUS_UNAVAILABLE', null);
            }

            List<Registration__c> duplicateRegistrations = [
                SELECT Id
                FROM Registration__c
                WHERE Event__c = :eventId
                    AND Attendee__c = :attendeeId
                LIMIT 1
            ];
            if (!duplicateRegistrations.isEmpty()) {
                return new TransactionResponse(false, 'DUPLICATE_REGISTRATION', duplicateRegistrations[0].Id);
            }

            SObject registration = Registration__c.SObjectType.newSObject();
            registration.put('Event__c', eventId);
            registration.put('Attendee__c', attendeeId);
            registration.put(statusField, getPendingStatus(registrationFields.get(statusField)));
            if (registrationFields.containsKey('Registration_Date__c')) {
                registration.put('Registration_Date__c', System.now());
            }
            insert registration;
            return new TransactionResponse(true, 'PENDING_PAYMENT', (String) registration.get('Id'));
        } catch (Exception exceptionValue) {
            Database.rollback(transactionSavepoint);
            throw new AuraHandledException('Booking could not be completed: ' + exceptionValue.getMessage());
        }
    }

    private static String getPendingStatus(Schema.SObjectField field) {
        if (field.getDescribe().getType() != Schema.DisplayType.Picklist) {
            return 'Pending Payment';
        }
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == 'Pending Payment') {
                return 'Pending Payment';
            }
        }
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == 'Pending') {
                return 'Pending';
            }
        }
        throw new AuraHandledException('No pending payment status is configured.');
    }
}
