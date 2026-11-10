public with sharing class EpicEventzEngine {
    @AuraEnabled(cacheable=false)
    public static String processRegistration(Id eventId, Id attendeeId, String ticketTypeName) {
        if (eventId == null || attendeeId == null) {
            throw new AuraHandledException('Event and attendee are required.');
        }

        List<Event__c> targetEvents = [
            SELECT Id, Name, Max_Capacity__c, Current_Attendee_Count__c
            FROM Event__c
            WHERE Id = :eventId
            FOR UPDATE
        ];
        if (targetEvents.isEmpty()) {
            throw new AuraHandledException('Event not found.');
        }

        Event__c evt = targetEvents[0];
        List<Registration__c> duplicates = [
            SELECT Id
            FROM Registration__c
            WHERE Event__c = :eventId
                AND Attendee__c = :attendeeId
                AND Registration_Status__c != 'Cancelled'
            LIMIT 1
        ];
        if (!duplicates.isEmpty()) {
            return 'DUPLICATE_REGISTRATION';
        }

        Decimal maxCapacity = evt.Max_Capacity__c == null ? 0 : evt.Max_Capacity__c;
        Decimal currentCount = evt.Current_Attendee_Count__c == null ? 0 : evt.Current_Attendee_Count__c;
        if (currentCount >= maxCapacity) {
            insert new Waitlist__c(
                Event__c = eventId,
                Attendee__c = attendeeId,
                Status__c = 'Waiting',
                Joined_Date__c = System.now()
            );
            return 'ADDED_TO_WAITLIST';
        }

        Registration__c registration = new Registration__c(
            Event__c = eventId,
            Attendee__c = attendeeId,
            Registration_Status__c = 'Registered',
            Payment_Status__c = 'Pending',
            Registration_Date__c = System.now()
        );
        insert registration;
        return registration.Id;
    }

    @AuraEnabled
    public static void finalizeRegistration(Id regId, String paymentStatus) {
        if (regId == null || (paymentStatus != 'Paid' && paymentStatus != 'Failed')) {
            throw new AuraHandledException('A registration Id and valid payment status are required.');
        }

        Registration__c registration = [
            SELECT Id, Event__c, Attendee__c, Registration_Status__c, Payment_Status__c
            FROM Registration__c
            WHERE Id = :regId
            FOR UPDATE
        ];

        registration.Payment_Status__c = paymentStatus;
        if (paymentStatus == 'Failed') {
            registration.Registration_Status__c = 'Cancelled';
            update registration;
            return;
        }

        registration.Registration_Status__c = 'Registered';
        update registration;

        if ([
            SELECT Id
            FROM Ticket__c
            WHERE Registration__c = :regId
            LIMIT 1
        ].isEmpty()) {
            insert new Ticket__c(
                Registration__c = registration.Id,
                Attendee__c = registration.Attendee__c,
                Event__c = registration.Event__c,
                Ticket_Number__c = buildTicketNumber(),
                Ticket_Status__c = 'Issued',
                Check_In_Status__c = 'Not Checked In'
            );
        }
    }

    public static void handleRegistrationCancellation(List<Registration__c> cancelledRegistrations) {
        Set<Id> eventIds = new Set<Id>();
        for (Registration__c registration : cancelledRegistrations) {
            if (registration.Registration_Status__c == 'Cancelled' && registration.Event__c != null) {
                eventIds.add(registration.Event__c);
            }
        }
        if (eventIds.isEmpty()) {
            return;
        }

        List<Waitlist__c> waitlists = [
            SELECT Id, Event__c, Attendee__c
            FROM Waitlist__c
            WHERE Event__c IN :eventIds
                AND Status__c = 'Waiting'
            ORDER BY Joined_Date__c ASC
        ];
        Map<Id, Waitlist__c> nextInLine = new Map<Id, Waitlist__c>();
        for (Waitlist__c waitlist : waitlists) {
            if (!nextInLine.containsKey(waitlist.Event__c)) {
                nextInLine.put(waitlist.Event__c, waitlist);
            }
        }

        List<Registration__c> newRegistrations = new List<Registration__c>();
        List<Waitlist__c> waitlistsToUpdate = new List<Waitlist__c>();
        for (Waitlist__c promoted : nextInLine.values()) {
            promoted.Status__c = 'Promoted';
            waitlistsToUpdate.add(promoted);
            newRegistrations.add(new Registration__c(
                Event__c = promoted.Event__c,
                Attendee__c = promoted.Attendee__c,
                Registration_Status__c = 'Registered',
                Payment_Status__c = 'Pending',
                Registration_Date__c = System.now()
            ));
        }
        update waitlistsToUpdate;
        insert newRegistrations;
    }

    private static String buildTicketNumber() {
        String randomPart = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        while (randomPart.length() < 6) {
            randomPart = '0' + randomPart;
        }
        return 'TIC-' + randomPart.substring(0, 6);
    }
}