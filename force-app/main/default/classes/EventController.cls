public with sharing class EventController {

    public class EventCard {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String eventCode;
        @AuraEnabled public String eventCategory;
        @AuraEnabled public String eventType;
        @AuraEnabled public String eventStatus;
        @AuraEnabled public String eventDescription;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime endDateTime;
        @AuraEnabled public Decimal capacity;
        @AuraEnabled public Boolean isSoldOut;
        @AuraEnabled public Boolean isCompleted;
        @AuraEnabled public Boolean isCancelled;
        @AuraEnabled public Boolean canBook;
    }

    @AuraEnabled(cacheable=true)
    public static List<EventCard> getEvents() {

        Datetime nowTime = System.now();

        List<Event__c> eventRecords = [
            SELECT Id,
                   Name,
                   Event_Code__c,
                   Event_Category__c,
                   Event_Type__c,
                   Event_Status__c,
                   Event_Description__c,
                   Start_Date_Time__c,
                   End_Date_Time__c,
                   Capacity__c
            FROM Event__c
            WHERE Event_Status__c IN (
                'Published',
                'Registration Open',
                'Registration Closed',
                'Completed',
                'Sold Out',
                'Cancelled'
            )
            ORDER BY Start_Date_Time__c ASC
            LIMIT 100
        ];

        Set<Id> eventIds = new Set<Id>();

        for (Event__c ev : eventRecords) {
            eventIds.add(ev.Id);
        }

        Map<Id, Boolean> hasAvailableTickets =
            new Map<Id, Boolean>();

        for (Id eventId : eventIds) {
            hasAvailableTickets.put(eventId, false);
        }

        if (!eventIds.isEmpty()) {
            for (Ticket_Type__c ticket : [
                SELECT Id, Event__c
                FROM Ticket_Type__c
                WHERE Event__c IN :eventIds
                  AND Ticket_Status__c = 'Active'
                  AND Available_Quantity__c > 0
                  AND (
                      Sales_Start__c = null
                      OR Sales_Start__c <= :nowTime
                  )
                  AND (
                      Sales_End__c = null
                      OR Sales_End__c >= :nowTime
                  )
            ]) {
                hasAvailableTickets.put(ticket.Event__c, true);
            }
        }

        List<EventCard> bookableEvents =
            new List<EventCard>();

        List<EventCard> unavailableEvents =
            new List<EventCard>();

        for (Event__c ev : eventRecords) {

            EventCard card = new EventCard();

            card.Id = ev.Id;
            card.Name = ev.Name;
            card.eventCode = ev.Event_Code__c;
            card.eventCategory = ev.Event_Category__c;
            card.eventType = ev.Event_Type__c;
            card.eventStatus = ev.Event_Status__c;
            card.eventDescription = ev.Event_Description__c;
            card.startDateTime = ev.Start_Date_Time__c;
            card.endDateTime = ev.End_Date_Time__c;
            card.capacity = ev.Capacity__c;

            // Detect cancelled events.
            card.isCancelled =
                ev.Event_Status__c == 'Cancelled';

            // Detect completed events.
            card.isCompleted =
                ev.Event_Status__c == 'Completed' ||
                (
                    ev.End_Date_Time__c != null &&
                    ev.End_Date_Time__c <= nowTime
                );

            // Detect sold-out events.
            card.isSoldOut =
                !card.isCompleted &&
                !card.isCancelled &&
                (
                    ev.Event_Status__c == 'Sold Out' ||
                    (
                        (
                            ev.Event_Status__c == 'Published' ||
                            ev.Event_Status__c == 'Registration Open'
                        ) &&
                        !hasAvailableTickets.get(ev.Id)
                    )
                );

            // Determine whether the event can be booked.
            card.canBook =
                !card.isCancelled &&
                !card.isCompleted &&
                !card.isSoldOut &&
                hasAvailableTickets.get(ev.Id) &&
                (
                    ev.Event_Status__c == 'Published' ||
                    ev.Event_Status__c == 'Registration Open'
                );

            // Group bookable events before unavailable events.
            if (card.canBook) {
                bookableEvents.add(card);
            } else {
                unavailableEvents.add(card);
            }
        }

        // Both groups retain their original start-date ordering.
        List<EventCard> sortedEvents = new List<EventCard>();

        sortedEvents.addAll(bookableEvents);
        sortedEvents.addAll(unavailableEvents);

        return sortedEvents;
    }
}