public with sharing class BookingNotificationQueueable
    implements Queueable {

    private Set<Id> bookingIds;

    public BookingNotificationQueueable(Set<Id> bookingIds) {
        this.bookingIds = bookingIds == null
            ? new Set<Id>()
            : bookingIds.clone();
    }

    public void execute(QueueableContext context) {
        if (bookingIds.isEmpty()) {
            return;
        }

        List<Booking__c> bookings = [
            SELECT Id, Name, Booking_Status__c,
                   Payment_Status__c, Quantity__c,
                   Total_Amount__c, Ticket_Code__c
            FROM Booking__c
            WHERE Id IN :bookingIds
            WITH USER_MODE
        ];

        for (Booking__c booking : bookings) {
            System.debug(
                LoggingLevel.INFO,
                'EpicEventz booking processed: ' +
                booking.Id +
                ', Status: ' + booking.Booking_Status__c +
                ', Payment: ' + booking.Payment_Status__c
            );
        }
    }
}