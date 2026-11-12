public with sharing class BookingInventoryWriter {
    private static void reserve(Id ticketId, Integer quantity) {
        if (ticketId == null || quantity == null || quantity <= 0) {
            throw new IllegalArgumentException('A ticket and positive quantity are required.');
        }

        Ticket_Type__c ticket = [
            SELECT Id, Available_Quantity__c
            FROM Ticket_Type__c
            WHERE Id = :ticketId
            FOR UPDATE
        ];

        if (ticket.Available_Quantity__c == null ||
            ticket.Available_Quantity__c < quantity) {
            throw new IllegalArgumentException('Insufficient ticket inventory.');
        }

        ticket.Available_Quantity__c -= quantity;
        Database.update(ticket, AccessLevel.SYSTEM_MODE);
    }
}
