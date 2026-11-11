@IsTest
private class BookingControllerTest {

    @TestSetup
    static void setupTestData() {
        EpicEventzCustomerTestFactory.createCustomer(
            'booking-owner',
            false
        );
        EpicEventzCustomerTestFactory.createCustomer(
            'booking-other',
            false
        );

        Event__c eventRecord = new Event__c(
            Name = 'Tech Innovators Summit',
            Capacity__c = 500,
            Event_Code__c = 'EVT-TIS-2026',
            Event_Status__c = 'Published',
            Start_Date_Time__c = Datetime.now().addDays(5),
            End_Date_Time__c = Datetime.now().addDays(6)
        );
        insert eventRecord;

        insert new Ticket_Type__c(
            Name = 'General Admission',
            Event__c = eventRecord.Id,
            Ticket_Code__c = 'GA-TIS-001',
            Total_Quantity__c = 100,
            Available_Quantity__c = 10,
            Price__c = 250,
            Ticket_Status__c = 'Active',
            Sales_Start__c = Datetime.now().addDays(-1),
            Sales_End__c = Datetime.now().addDays(2)
        );
    }

    private static User getCustomer(String customerKey) {
        return [
            SELECT Id, ContactId
            FROM User
            WHERE Contact.LastName = :('Customer ' + customerKey)
            LIMIT 1
        ];
    }

    private static Event__c getEvent() {
        return [SELECT Id FROM Event__c LIMIT 1];
    }

    private static Ticket_Type__c getTicket() {
        return [
            SELECT Id, Available_Quantity__c, Price__c
            FROM Ticket_Type__c
            LIMIT 1
        ];
    }

    @IsTest
    static void testBookingUsesAuthenticatedContactAndReducesInventory() {
        User customer = getCustomer('booking-owner');
        Event__c eventRecord = getEvent();
        Ticket_Type__c ticket = getTicket();

        Test.startTest();
        BookingController.BookingResult result;
        System.runAs(customer) {
            result = BookingController.createBooking(
                eventRecord.Id,
                ticket.Id,
                3
            );
        }
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.isNotNull(result.bookingId);
        Assert.areEqual(750, result.totalAmount);

        Ticket_Type__c updatedTicket = [
            SELECT Available_Quantity__c
            FROM Ticket_Type__c
            WHERE Id = :ticket.Id
        ];
        Assert.areEqual(7, updatedTicket.Available_Quantity__c);

        Booking__c createdBooking = [
            SELECT Attendee__c, Quantity__c, Total_Amount__c,
                   Booking_Status__c, Payment_Status__c,
                   Inventory_Processed__c
            FROM Booking__c
            WHERE Id = :result.bookingId
        ];
        Assert.areEqual(customer.ContactId, createdBooking.Attendee__c);
        Assert.areEqual(3, createdBooking.Quantity__c);
        Assert.areEqual(750, createdBooking.Total_Amount__c);
        Assert.areEqual('Pending', createdBooking.Booking_Status__c);
        Assert.areEqual('Pending', createdBooking.Payment_Status__c);
        Assert.isTrue(createdBooking.Inventory_Processed__c);
    }

    @IsTest
    static void testMissingContactIsRejected() {
        Event__c eventRecord = getEvent();
        Ticket_Type__c ticket = getTicket();
        Boolean exceptionCaught = false;

        try {
            BookingController.createBooking(eventRecord.Id, ticket.Id, 1);
        } catch (AuraHandledException ex) {
            exceptionCaught = true;
            Assert.isTrue(ex.getMessage().contains('not linked'));
        }
        Assert.isTrue(exceptionCaught);
    }

    @IsTest
    static void testInsufficientInventoryIsRejectedWithoutBooking() {
        User customer = getCustomer('booking-owner');
        Event__c eventRecord = getEvent();
        Ticket_Type__c ticket = getTicket();
        update new Ticket_Type__c(
            Id = ticket.Id,
            Available_Quantity__c = 2
        );

        Boolean exceptionCaught = false;
        System.runAs(customer) {
            try {
                BookingController.createBooking(
                    eventRecord.Id,
                    ticket.Id,
                    3
                );
            } catch (AuraHandledException ex) {
                exceptionCaught = true;
                Assert.isTrue(
                    ex.getMessage().contains('not enough tickets')
                );
            }
        }

        Assert.isTrue(exceptionCaught);
        Assert.areEqual(
            2,
            [SELECT Available_Quantity__c FROM Ticket_Type__c WHERE Id = :ticket.Id]
                .Available_Quantity__c
        );
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Booking__c WHERE Ticket_Type__c = :ticket.Id]
        );
    }

    @IsTest
    static void testInvalidQuantitiesAndRequiredIdsAreRejected() {
        User customer = getCustomer('booking-owner');
        Event__c eventRecord = getEvent();
        Ticket_Type__c ticket = getTicket();

        System.runAs(customer) {
            for (Integer invalidQuantity : new List<Integer>{ 0, -1, 11 }) {
                Boolean rejected = false;
                try {
                    BookingController.createBooking(
                        eventRecord.Id,
                        ticket.Id,
                        invalidQuantity
                    );
                } catch (AuraHandledException ex) {
                    rejected = true;
                }
                Assert.isTrue(rejected);
            }

            Boolean missingEventRejected = false;
            try {
                BookingController.createBooking(null, ticket.Id, 1);
            } catch (AuraHandledException ex) {
                missingEventRejected = true;
            }
            Assert.isTrue(missingEventRejected);
        }
    }

    @IsTest
    static void testConsecutiveBookingsCannotOversell() {
        User customer = getCustomer('booking-owner');
        Event__c eventRecord = getEvent();
        Ticket_Type__c ticket = getTicket();
        update new Ticket_Type__c(
            Id = ticket.Id,
            Available_Quantity__c = 3
        );

        System.runAs(customer) {
            BookingController.BookingResult first =
                BookingController.createBooking(
                    eventRecord.Id,
                    ticket.Id,
                    2
                );
            Assert.isNotNull(first.bookingId);

            Boolean secondRejected = false;
            try {
                BookingController.createBooking(
                    eventRecord.Id,
                    ticket.Id,
                    2
                );
            } catch (AuraHandledException ex) {
                secondRejected = true;
            }
            Assert.isTrue(secondRejected);

            BookingController.BookingResult lastTicket =
                BookingController.createBooking(
                    eventRecord.Id,
                    ticket.Id,
                    1
                );
            Assert.isNotNull(lastTicket.bookingId);

            Boolean soldOutRejected = false;
            try {
                BookingController.createBooking(
                    eventRecord.Id,
                    ticket.Id,
                    1
                );
            } catch (AuraHandledException ex) {
                soldOutRejected = true;
            }
            Assert.isTrue(soldOutRejected);
        }

        Assert.areEqual(
            0,
            [SELECT Available_Quantity__c FROM Ticket_Type__c WHERE Id = :ticket.Id]
                .Available_Quantity__c
        );
    }

    @IsTest
    static void testCustomerBookingsReturnOnlyAuthenticatedContactRecords() {
        User owner = getCustomer('booking-owner');
        User other = getCustomer('booking-other');
        Event__c eventRecord = getEvent();
        Ticket_Type__c ticket = getTicket();
        System.runAs(owner) {
            BookingController.createBooking(eventRecord.Id, ticket.Id, 1);
        }
        System.runAs(other) {
            BookingController.createBooking(eventRecord.Id, ticket.Id, 1);
        }

        System.runAs(owner) {
            List<Booking__c> bookings = BookingController.getMyBookings();
            Assert.areEqual(1, bookings.size());
            Assert.areEqual(owner.ContactId, bookings[0].Attendee__c);
        }

        System.runAs(other) {
            List<Booking__c> bookings = BookingController.getMyBookings();
            Assert.areEqual(1, bookings.size());
            Assert.areEqual(other.ContactId, bookings[0].Attendee__c);
        }
    }

    @IsTest
    static void testMyBookingsRejectsUserWithoutContact() {
        Boolean exceptionCaught = false;
        try {
            BookingController.getMyBookings();
        } catch (AuraHandledException ex) {
            exceptionCaught = true;
            Assert.isTrue(ex.getMessage().contains('not linked'));
        }
        Assert.isTrue(exceptionCaught);
    }

    @IsTest
    static void testGetTicketTypesRequiresEventAndReturnsActiveTickets() {
        User customer = getCustomer('booking-owner');
        Event__c eventRecord = getEvent();

        System.runAs(customer) {
            List<BookingController.TicketOption> options =
                BookingController.getTicketTypes(eventRecord.Id);
            Assert.areEqual(1, options.size());
            Assert.areEqual('General Admission', options[0].name);
            Assert.areEqual(250, options[0].price);

            Boolean exceptionCaught = false;
            try {
                BookingController.getTicketTypes(null);
            } catch (AuraHandledException ex) {
                exceptionCaught = true;
            }
            Assert.isTrue(exceptionCaught);
        }
    }
}
