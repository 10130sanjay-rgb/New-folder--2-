public without sharing class EpicEventzPublicCatalogData {

    public static List<Ticket_Type__c> getAvailableTickets(Id eventId) {
        return [
            SELECT Id, Name, Ticket_Category__c, Description__c,
                   Price__c, Available_Quantity__c
            FROM Ticket_Type__c
            WHERE Event__c = :eventId
              AND Event__r.Event_Status__c IN ('Published', 'Registration Open')
              AND Ticket_Status__c = 'Active'
              AND (Sales_Start__c = null OR Sales_Start__c <= :System.now())
              AND (Sales_End__c = null OR Sales_End__c >= :System.now())
              AND Available_Quantity__c > 0
            WITH SYSTEM_MODE
            ORDER BY Price__c ASC
        ];
    }

    public static Event__c getEventForBooking(Id eventId) {
        List<Event__c> events = [
            SELECT Id, Name, Event_Status__c
            FROM Event__c
            WHERE Id = :eventId
            WITH SYSTEM_MODE
            FOR UPDATE
        ];
        return events.isEmpty() ? null : events[0];
    }

    public static Ticket_Type__c getTicketForBooking(
        Id ticketTypeId,
        Id eventId
    ) {
        List<Ticket_Type__c> tickets = [
            SELECT Id, Name, Price__c, Available_Quantity__c,
                   Ticket_Status__c, Sales_Start__c, Sales_End__c
            FROM Ticket_Type__c
            WHERE Id = :ticketTypeId
              AND Event__c = :eventId
            WITH SYSTEM_MODE
            FOR UPDATE
        ];
        return tickets.isEmpty() ? null : tickets[0];
    }
}
