public with sharing class BookingController {

    public class TicketOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal availableQuantity;

        public TicketOption(Ticket_Type__c ticket) {
            id = ticket.Id;
            name = ticket.Name;
            category = ticket.Ticket_Category__c;
            description = ticket.Description__c;
            price = ticket.Price__c;
            availableQuantity = ticket.Available_Quantity__c;
        }
    }

    public class BookingResult {
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String ticketCode;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static List<TicketOption> getTicketTypes(Id eventId) {
        if (eventId == null) {
            throw newAuraException('Please select an event.');
        }

        List<Ticket_Type__c> tickets =
            EpicEventzPublicCatalogData.getAvailableTickets(eventId);
        List<Ticket_Type__c> readableTickets =
            (List<Ticket_Type__c>) Security.stripInaccessible(
                AccessType.READABLE,
                tickets
            ).getRecords();
        List<TicketOption> results = new List<TicketOption>();
        for (Ticket_Type__c ticket : readableTickets) {
            results.add(new TicketOption(ticket));
        }

        return results;
    }

    @AuraEnabled
    public static BookingResult createBooking(
        Id eventId,
        Id ticketTypeId,
        Integer quantity
    ) {
        return EpicEventzBookingService.createBooking(
            eventId,
            ticketTypeId,
            quantity
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<Booking__c> getMyBookings() {
        Id contactId = EpicEventzCustomerContext.requireContactId();
        return [
            SELECT Id, Name, Attendee__c, Event__c, Event__r.Name,
                   Event__r.Start_Date_Time__c, Ticket_Type__c,
                   Ticket_Type__r.Name, Quantity__c, Total_Amount__c,
                   Booking_Date__c, Booking_Status__c, Payment_Status__c,
                   Ticket_Code__c
            FROM Booking__c
            WHERE Attendee__c = :contactId
            WITH USER_MODE
            ORDER BY Booking_Date__c DESC
            LIMIT 100
        ];
    }

    private static AuraHandledException newAuraException(
        String message
    ) {
        AuraHandledException ex =
            new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
