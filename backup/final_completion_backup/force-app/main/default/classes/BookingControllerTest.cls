@isTest
private class BookingControllerTest {

    @testSetup
    static void setupTestData() {
        Event__c evt = new Event__c(
            Name = 'Tech Innovators Summit',
            Capacity__c = 500,
            Event_Code__c = 'EVT-TIS-2026',
            Event_Status__c = 'Published',
            Start_Date_Time__c = Datetime.now().addDays(5),
            End_Date_Time__c = Datetime.now().addDays(6)
        );
        insert evt;

        Ticket_Type__c ticket = new Ticket_Type__c(
            Name = 'General Admission',
            Event__c = evt.Id,
            Ticket_Code__c = 'GA-TIS-001',
            Total_Quantity__c = 100,
            Available_Quantity__c = 10,
            Price__c = 250,
            Ticket_Status__c = 'Active',
            Sales_Start__c = Datetime.now().addDays(-1),
            Sales_End__c = Datetime.now().addDays(2)
        );
        insert ticket;
    }

    @isTest
    static void testSuccessfulBookingReducesInventory() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Ticket_Type__c ticket = [SELECT Id, Available_Quantity__c, Price__c FROM Ticket_Type__c LIMIT 1];

        Test.startTest();
        BookingController.BookingResult result = BookingController.createBooking(
            evt.Id,
            ticket.Id,
            'John',
            'Doe',
            'johndoe@example.com',
            '9876543210',
            3
        );
        Test.stopTest();

        Assert.isNotNull(result, 'BookingResult should not be null');
        Assert.isNotNull(result.bookingId, 'Booking ID should be populated');
        Assert.isNotNull(result.ticketCode, 'Ticket code should be generated');
        Assert.areEqual(750, result.totalAmount, 'Total amount should equal price * quantity');

        Ticket_Type__c updatedTicket = [
            SELECT Available_Quantity__c
            FROM Ticket_Type__c
            WHERE Id = :ticket.Id
        ];
        Assert.areEqual(7, updatedTicket.Available_Quantity__c, 'Available quantity should decrease by booked quantity');

        Booking__c createdBooking = [
            SELECT Quantity__c, Total_Amount__c, Booking_Status__c,
                   Payment_Status__c, Inventory_Processed__c
            FROM Booking__c
            WHERE Id = :result.bookingId
        ];
        Assert.areEqual(3, createdBooking.Quantity__c, 'Quantity should be 3');
        Assert.areEqual(750, createdBooking.Total_Amount__c, 'Total amount should be 750');
        Assert.areEqual('Pending', createdBooking.Booking_Status__c, 'Status should be Pending');
        Assert.areEqual('Pending', createdBooking.Payment_Status__c, 'Payment status should be Pending');
        Assert.isTrue(createdBooking.Inventory_Processed__c, 'Inventory should be marked as processed');

        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email
            FROM Contact
            WHERE Email = 'johndoe@example.com'
        ];
        Assert.areEqual(1, contacts.size(), 'Contact should be created');
    }

    @isTest
    static void testExistingContactReusedOnBooking() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Ticket_Type__c ticket = [SELECT Id FROM Ticket_Type__c LIMIT 1];

        Contact existingContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'janesmith@example.com'
        );
        insert existingContact;

        Test.startTest();
        BookingController.BookingResult result = BookingController.createBooking(
            evt.Id,
            ticket.Id,
            'Jane',
            'Smith',
            'janesmith@example.com',
            '1122334455',
            1
        );
        Test.stopTest();

        Booking__c createdBooking = [
            SELECT Attendee__c
            FROM Booking__c
            WHERE Id = :result.bookingId
        ];
        Assert.areEqual(existingContact.Id, createdBooking.Attendee__c, 'Existing contact should be reused');
    }

    @isTest
    static void testRejectionWhenQuantityExceedsAvailableInventory() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Ticket_Type__c ticket = [SELECT Id FROM Ticket_Type__c LIMIT 1];

        update new Ticket_Type__c(Id = ticket.Id, Available_Quantity__c = 2);

        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            BookingController.createBooking(
                evt.Id,
                ticket.Id,
                'Alice',
                'Brown',
                'alice@example.com',
                '9988776655',
                3
            );
        } catch (AuraHandledException ex) {
            exceptionCaught = true;
            Assert.isTrue(ex.getMessage().contains('There are not enough tickets available.'),
                'Expected not enough tickets exception');
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Exception should be thrown when quantity exceeds availability');

        Ticket_Type__c ticketAfter = [SELECT Available_Quantity__c FROM Ticket_Type__c WHERE Id = :ticket.Id];
        Assert.areEqual(2, ticketAfter.Available_Quantity__c, 'Inventory must not decrease on failed booking');

        List<Booking__c> bookings = [SELECT Id FROM Booking__c WHERE Ticket_Type__c = :ticket.Id];
        Assert.areEqual(0, bookings.size(), 'No booking record should exist');
    }

    @isTest
    static void testRejectionForZeroOrNegativeQuantity() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Ticket_Type__c ticket = [SELECT Id FROM Ticket_Type__c LIMIT 1];

        Boolean zeroCaught = false;
        try {
            BookingController.createBooking(
                evt.Id,
                ticket.Id,
                'Bob',
                'Zero',
                'bob@example.com',
                '1234567890',
                0
            );
        } catch (AuraHandledException ex) {
            zeroCaught = true;
        }
        Assert.isTrue(zeroCaught, 'Zero quantity should be rejected');

        Boolean negativeCaught = false;
        try {
            BookingController.createBooking(
                evt.Id,
                ticket.Id,
                'Bob',
                'Negative',
                'bob@example.com',
                '1234567890',
                -1
            );
        } catch (AuraHandledException ex) {
            negativeCaught = true;
        }
        Assert.isTrue(negativeCaught, 'Negative quantity should be rejected');

        Ticket_Type__c ticketAfter = [SELECT Available_Quantity__c FROM Ticket_Type__c WHERE Id = :ticket.Id];
        Assert.areEqual(10, ticketAfter.Available_Quantity__c, 'Inventory should remain 10');
    }

    @isTest
    static void testRejectionForMissingRequiredFields() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Ticket_Type__c ticket = [SELECT Id FROM Ticket_Type__c LIMIT 1];

        Boolean nullEventCaught = false;
        try {
            BookingController.createBooking(null, ticket.Id, 'A', 'B', 'a@b.com', '123', 1);
        } catch (AuraHandledException ex) {
            nullEventCaught = true;
        }
        Assert.isTrue(nullEventCaught, 'Null event should be rejected');

        Boolean nullEmailCaught = false;
        try {
            BookingController.createBooking(evt.Id, ticket.Id, 'A', 'B', '', '123', 1);
        } catch (AuraHandledException ex) {
            nullEmailCaught = true;
        }
        Assert.isTrue(nullEmailCaught, 'Blank email should be rejected');
    }

    @isTest
    static void testConsecutiveBookingsPreventOverselling() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Ticket_Type__c ticket = [SELECT Id FROM Ticket_Type__c LIMIT 1];

        update new Ticket_Type__c(Id = ticket.Id, Available_Quantity__c = 3);

        Test.startTest();
        // Booking 1: Request 2 tickets -> succeeds
        BookingController.BookingResult r1 = BookingController.createBooking(
            evt.Id, ticket.Id, 'User', 'One', 'user1@example.com', '111', 2
        );
        Assert.isNotNull(r1.bookingId, 'Booking 1 should succeed');

        Ticket_Type__c t1 = [SELECT Available_Quantity__c FROM Ticket_Type__c WHERE Id = :ticket.Id];
        Assert.areEqual(1, t1.Available_Quantity__c, '1 ticket should remain after Booking 1');

        // Booking 2: Request 2 tickets -> fails (only 1 available)
        Boolean b2Failed = false;
        try {
            BookingController.createBooking(
                evt.Id, ticket.Id, 'User', 'Two', 'user2@example.com', '222', 2
            );
        } catch (AuraHandledException ex) {
            b2Failed = true;
        }
        Assert.isTrue(b2Failed, 'Booking 2 must fail due to insufficient inventory');

        // Booking 3: Request 1 ticket -> succeeds (takes the last ticket)
        BookingController.BookingResult r3 = BookingController.createBooking(
            evt.Id, ticket.Id, 'User', 'Three', 'user3@example.com', '333', 1
        );
        Assert.isNotNull(r3.bookingId, 'Booking 3 should succeed');

        Ticket_Type__c t3 = [SELECT Available_Quantity__c FROM Ticket_Type__c WHERE Id = :ticket.Id];
        Assert.areEqual(0, t3.Available_Quantity__c, '0 tickets should remain');

        // Booking 4: Request 1 ticket -> fails (inventory is 0)
        Boolean b4Failed = false;
        try {
            BookingController.createBooking(
                evt.Id, ticket.Id, 'User', 'Four', 'user4@example.com', '444', 1
            );
        } catch (AuraHandledException ex) {
            b4Failed = true;
        }
        Assert.isTrue(b4Failed, 'Booking 4 must fail because tickets are sold out');
        Test.stopTest();
    }

    @isTest
    static void testGetTicketTypes() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];

        Test.startTest();
        List<BookingController.TicketOption> options = BookingController.getTicketTypes(evt.Id);
        Test.stopTest();

        Assert.areEqual(1, options.size(), 'Should return 1 ticket option');
        Assert.areEqual('General Admission', options[0].name);
        Assert.areEqual(250, options[0].price);

        Boolean nullEventCaught = false;
        try {
            BookingController.getTicketTypes(null);
        } catch (AuraHandledException ex) {
            nullEventCaught = true;
        }
        Assert.isTrue(nullEventCaught, 'Null event ID should throw AuraHandledException');
    }
}