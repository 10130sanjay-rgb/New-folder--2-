@IsTest
private class BookingExpirationBatchTest {

    private static Event__c createEvent() {
        Event__c eventRecord = new Event__c(
            Name = 'Batch Test Event',
            Capacity__c = 100,
            Event_Code__c = 'EVT-BATCH-001',
            Event_Status__c = 'Published',
            Start_Date_Time__c = System.now().addDays(5),
            End_Date_Time__c = System.now().addDays(6)
        );

        insert eventRecord;
        return eventRecord;
    }

    private static Ticket_Type__c createTicket(Event__c eventRecord) {
        Ticket_Type__c ticket = new Ticket_Type__c(
            Name = 'Batch Test Ticket',
            Event__c = eventRecord.Id,
            Ticket_Code__c = 'TKT-BATCH-001',
            Total_Quantity__c = 100,
            Available_Quantity__c = 10,
            Price__c = 250,
            Ticket_Status__c = 'Active',
            Sales_Start__c = System.now().addDays(-1),
            Sales_End__c = System.now().addDays(2)
        );

        insert ticket;
        return ticket;
    }

    private static Booking__c createBooking(
        Event__c eventRecord,
        Ticket_Type__c ticket,
        String email,
        String status,
        String paymentStatus,
        Datetime bookingDate
    ) {
        Contact attendee = new Contact(
            LastName = 'Batch Attendee',
            Email = email
        );
        insert attendee;

        Booking__c booking = new Booking__c(
            Attendee__c = attendee.Id,
            Event__c = eventRecord.Id,
            Ticket_Type__c = ticket.Id,
            Quantity__c = 2,
            Total_Amount__c = 500,
            Booking_Date__c = bookingDate,
            Booking_Status__c = status,
            Payment_Status__c = paymentStatus,
            Inventory_Processed__c = true,
            Inventory_Restored__c = false,
            Discount_Applied__c = false,
            Discount_Amount__c = 0,
            Ticket_Code__c = 'EE-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '0')
        );

        insert booking;
        return booking;
    }

    @IsTest
    static void testBatchExpiresOldUnpaidBooking() {
        Event__c eventRecord = createEvent();
        Ticket_Type__c ticket = createTicket(eventRecord);

        Booking__c booking = createBooking(
            eventRecord,
            ticket,
            'batch.expire@example.com',
            'Pending',
            'Pending',
            System.now().addMinutes(-45)
        );

        Test.startTest();
        Id jobId = Database.executeBatch(new BookingExpirationBatch(30), 100);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);

        Booking__c updatedBooking = [
            SELECT Booking_Status__c, Inventory_Restored__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];

        System.assertEquals('Cancelled', updatedBooking.Booking_Status__c);
        System.assertEquals(true, updatedBooking.Inventory_Restored__c);

        Ticket_Type__c updatedTicket = [
            SELECT Available_Quantity__c
            FROM Ticket_Type__c
            WHERE Id = :ticket.Id
        ];

        System.assertEquals(12, updatedTicket.Available_Quantity__c);
    }

    @IsTest
    static void testBatchDoesNotCancelSuccessfulPayment() {
        Event__c eventRecord = createEvent();
        Ticket_Type__c ticket = createTicket(eventRecord);

        Booking__c booking = createBooking(
            eventRecord,
            ticket,
            'batch.paid@example.com',
            'Pending',
            'Pending',
            System.now().addMinutes(-45)
        );

        insert new Payment__c(
            Booking__c = booking.Id,
            Amount__c = 500,
            Payment_Status__c = 'Successful',
            Payment_Method__c = 'Credit Card',
            Transaction_ID__c = 'TXN-BATCH-PAID-001'
        );

        Test.startTest();
        Id jobId = Database.executeBatch(new BookingExpirationBatch(30), 100);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);

        Booking__c updatedBooking = [
            SELECT Booking_Status__c, Inventory_Restored__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];

        System.assertNotEquals('Cancelled', updatedBooking.Booking_Status__c);
        System.assertNotEquals(true, updatedBooking.Inventory_Restored__c);
    }

    @IsTest
    static void testBatchDefaultsInvalidExpirationTime() {
        Test.startTest();

        Id jobId = Database.executeBatch(
            new BookingExpirationBatch(null),
            100
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }
}