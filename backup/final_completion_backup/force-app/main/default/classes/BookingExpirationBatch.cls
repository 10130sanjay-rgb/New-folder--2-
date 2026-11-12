public without sharing class BookingExpirationBatch
    implements Database.Batchable<SObject> {

    private Integer expirationMinutes;

    public BookingExpirationBatch(Integer expirationMinutes) {
        this.expirationMinutes =
            expirationMinutes == null || expirationMinutes <= 0
            ? 30
            : expirationMinutes;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        Datetime cutoff = System.now().addMinutes(-expirationMinutes);

        return Database.getQueryLocator([
            SELECT Id
            FROM Booking__c
            WHERE Booking_Status__c = 'Pending'
              AND Payment_Status__c = 'Pending'
              AND Booking_Date__c <= :cutoff
              AND Id NOT IN (
                  SELECT Booking__c
                  FROM Payment__c
                  WHERE Payment_Status__c = 'Successful'
              )
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<SObject> scope
    ) {
        Set<Id> bookingIds = new Set<Id>();

        for (SObject record : scope) {
            bookingIds.add((Id) record.get('Id'));
        }

        if (bookingIds.isEmpty()) {
            return;
        }

        Map<Id, Booking__c> bookings = new Map<Id, Booking__c>([
            SELECT Id, Booking_Status__c, Payment_Status__c,
                   Ticket_Type__c, Quantity__c,
                   Inventory_Processed__c, Inventory_Restored__c,
                   Cancellation_Reason__c,
                   (SELECT Id FROM Payments__r
                    WHERE Payment_Status__c = 'Successful')
            FROM Booking__c
            WHERE Id IN :bookingIds
            FOR UPDATE
        ]);

        List<Booking__c> bookingsToUpdate = new List<Booking__c>();
        Map<Id, Decimal> quantitiesToRestore = new Map<Id, Decimal>();

        for (Booking__c booking : bookings.values()) {
            if (booking.Booking_Status__c != 'Pending' ||
                booking.Payment_Status__c != 'Pending' ||
                !booking.Payments__r.isEmpty()) {
                continue;
            }

            if (booking.Inventory_Processed__c == true &&
                booking.Inventory_Restored__c != true &&
                booking.Ticket_Type__c != null &&
                booking.Quantity__c != null &&
                booking.Quantity__c > 0) {

                quantitiesToRestore.put(
                    booking.Ticket_Type__c,
                    (quantitiesToRestore.containsKey(booking.Ticket_Type__c)
                        ? quantitiesToRestore.get(booking.Ticket_Type__c)
                        : 0) + booking.Quantity__c
                );

                booking.Inventory_Restored__c = true;
            }

            booking.Booking_Status__c = 'Cancelled';
            booking.Cancellation_Reason__c = 'Reservation expired due to unpaid booking.';
            bookingsToUpdate.add(booking);
        }

        if (bookingsToUpdate.isEmpty()) {
            return;
        }

        Map<Id, Ticket_Type__c> tickets = new Map<Id, Ticket_Type__c>();

        if (!quantitiesToRestore.isEmpty()) {
            tickets = new Map<Id, Ticket_Type__c>([
                SELECT Id, Available_Quantity__c, Total_Quantity__c
                FROM Ticket_Type__c
                WHERE Id IN :quantitiesToRestore.keySet()
                FOR UPDATE
            ]);
        }

        for (Id ticketId : quantitiesToRestore.keySet()) {
            Ticket_Type__c ticket = tickets.get(ticketId);

            if (ticket == null) {
                continue;
            }

            Decimal available = ticket.Available_Quantity__c == null
                ? 0 : ticket.Available_Quantity__c;

            Decimal total = ticket.Total_Quantity__c == null
                ? available : ticket.Total_Quantity__c;

            ticket.Available_Quantity__c = Math.min(
                available + quantitiesToRestore.get(ticketId),
                total
            );
        }

        update bookingsToUpdate;

        if (!tickets.isEmpty()) {
            update tickets.values();
        }
    }

    public void finish(Database.BatchableContext context) {
        System.debug(
            LoggingLevel.INFO,
            'EpicEventz booking expiration batch completed.'
        );
    }
}