@isTest
private class BookingValidationTriggerTest {

    @testSetup
    static void setupTestData() {
        Event__c eventRecord = new Event__c(
            Name = 'Trigger Test Event',
            Capacity__c = 100,
            Event_Code__c = 'EVT-TRIGGER-01',
            Event_Status__c = 'Published',
            Start_Date_Time__c = Datetime.now().addDays(5),
            End_Date_Time__c = Datetime.now().addDays(6)
        );
        insert eventRecord;

        Ticket_Type__c ticket = new Ticket_Type__c(
            Name = 'Trigger Test Ticket',
            Event__c = eventRecord.Id,
            Ticket_Code__c = 'TRG-TICKET-01',
            Total_Quantity__c = 100,
            Available_Quantity__c = 50,
            Price__c = 100,
            Ticket_Status__c = 'Active',
            Sales_Start__c = Datetime.now().addDays(-1),
            Sales_End__c = Datetime.now().addDays(2)
        );
        insert ticket;

        Contact attendee = new Contact(
            FirstName = 'Test',
            LastName = 'Attendee',
            Email = 'trigger.test@example.com'
        );
        insert attendee;
    }

    private static Booking__c validBooking() {
        Event__c eventRecord = [
            SELECT Id FROM Event__c
            WHERE Event_Code__c = 'EVT-TRIGGER-01'
            LIMIT 1
        ];

        Ticket_Type__c ticket = [
            SELECT Id FROM Ticket_Type__c
            WHERE Ticket_Code__c = 'TRG-TICKET-01'
            LIMIT 1
        ];

        Contact attendee = [
            SELECT Id FROM Contact
            WHERE Email = 'trigger.test@example.com'
            LIMIT 1
        ];

        return new Booking__c(
            Event__c = eventRecord.Id,
            Ticket_Type__c = ticket.Id,
            Attendee__c = attendee.Id,
            Quantity__c = 1,
            Booking_Status__c = 'Pending',
            Payment_Status__c = 'Pending',
            Booking_Date__c = System.now(),
            Total_Amount__c = 100,
            Inventory_Processed__c = false
        );
    }

    @isTest
    static void testInsertRejectsZeroQuantity() {
        Booking__c booking = validBooking();
        booking.Quantity__c = 0;

        Database.SaveResult result = Database.insert(booking, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains(
                'Booking quantity must be greater than zero.'
            )
        );
    }

    @isTest
    static void testInsertRejectsMissingEvent() {
        Booking__c booking = validBooking();
        booking.Event__c = null;

        Database.SaveResult result = Database.insert(booking, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains(
                'Please select an event for this booking.'
            )
        );
    }

    @isTest
    static void testInsertRejectsMissingTicketType() {
        Booking__c booking = validBooking();
        booking.Ticket_Type__c = null;

        Database.SaveResult result = Database.insert(booking, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains(
                'Please select a ticket type for this booking.'
            )
        );
    }

    @isTest
    static void testUpdateRejectsInvalidQuantity() {
        Booking__c booking = validBooking();
        insert booking;

        booking.Quantity__c = -1;

        Database.SaveResult result = Database.update(booking, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains(
                'Booking quantity must be greater than zero.'
            )
        );
    }

    @isTest
    static void testUpdateRejectsRemovingEvent() {
        Booking__c booking = validBooking();
        insert booking;

        booking.Event__c = null;

        Database.SaveResult result = Database.update(booking, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains(
                'Please select an event for this booking.'
            )
        );
    }

    @isTest
    static void testUpdateRejectsRemovingTicketType() {
        Booking__c booking = validBooking();
        insert booking;

        booking.Ticket_Type__c = null;

        Database.SaveResult result = Database.update(booking, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains(
                'Please select a ticket type for this booking.'
            )
        );
    }

    @isTest
    static void testUnrelatedUpdateDoesNotTriggerValidationErrors() {
        Booking__c booking = validBooking();
        insert booking;

        booking.Cancellation_Reason__c = 'Updated test note';

        Database.SaveResult result = Database.update(booking, false);

        Assert.isTrue(
            result.isSuccess(),
            'Updating an unrelated field should not fail trigger validation.'
        );
    }
}