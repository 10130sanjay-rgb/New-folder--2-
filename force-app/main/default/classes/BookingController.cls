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

        List<TicketOption> results = new List<TicketOption>();

        for (Ticket_Type__c ticket : [
            SELECT Id, Name, Ticket_Category__c, Description__c,
                   Price__c, Available_Quantity__c
            FROM Ticket_Type__c
            WHERE Event__c = :eventId
              AND Ticket_Status__c = 'Active'
              AND (Sales_Start__c = null OR Sales_Start__c <= :System.now())
              AND (Sales_End__c = null OR Sales_End__c >= :System.now())
              AND Available_Quantity__c > 0
            ORDER BY Price__c ASC
        ]) {
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
        if (eventId == null || ticketTypeId == null) {
            throw newAuraException('Please select an event and ticket type.');
        }
        if (quantity == null || quantity < 1 || quantity > 10) {
            throw newAuraException('Choose between 1 and 10 tickets per booking.');
        }
        // Delegate to service that resolves the authenticated Contact and handles inventory.
        return EpicEventzBookingService.createBooking(eventId, ticketTypeId, quantity);
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