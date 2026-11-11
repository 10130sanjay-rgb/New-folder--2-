@IsTest
private class PaymentControllerTest {

    @TestSetup
    static void setupData() {
        EpicEventzCustomerTestFactory.createCustomer(
            'payment-owner',
            true
        );
        EpicEventzCustomerTestFactory.createCustomer(
            'payment-other',
            false
        );

        Event__c eventRecord = new Event__c(
            Name = 'Payment Test Event',
            Event_Code__c = 'PAYTEST001',
            Capacity__c = 100,
            Event_Status__c = 'Published',
            Start_Date_Time__c = System.now().addDays(5),
            End_Date_Time__c = System.now().addDays(5).addHours(2)
        );
        insert eventRecord;

        Ticket_Type__c ticket = new Ticket_Type__c(
            Name = 'Test General Ticket',
            Ticket_Code__c = 'PAYTICKET001',
            Event__c = eventRecord.Id,
            Price__c = 500,
            Total_Quantity__c = 100,
            Available_Quantity__c = 100,
            Ticket_Status__c = 'Active',
            Sales_Start__c = System.now().addDays(-1),
            Sales_End__c = System.now().addDays(10)
        );
        insert ticket;

        User owner = getCustomer('payment-owner');
        User other = getCustomer('payment-other');
        System.runAs(owner) {
            BookingController.createBooking(eventRecord.Id, ticket.Id, 2);
        }
        System.runAs(other) {
            BookingController.createBooking(eventRecord.Id, ticket.Id, 2);
        }
    }

    private static User getCustomer(String customerKey) {
        return [
            SELECT Id, ContactId
            FROM User
            WHERE Contact.LastName = :('Customer ' + customerKey)
            LIMIT 1
        ];
    }

    private static Booking__c getBooking(String customerKey) {
        User customer = getCustomer(customerKey);
        return [
            SELECT Id, Booking_Status__c, Payment_Status__c,
                   Total_Amount__c, Booking_Date__c,
                   Inventory_Restored__c, Attendee__c
            FROM Booking__c
            WHERE Attendee__c = :customer.ContactId
            LIMIT 1
        ];
    }

    @IsTest
    static void testCustomerCanReadOnlyOwnBookingDetails() {
        User owner = getCustomer('payment-owner');
        Booking__c ownBooking = getBooking('payment-owner');
        Booking__c otherBooking = getBooking('payment-other');

        System.runAs(owner) {
            PaymentController.PaymentDetails details =
                PaymentController.getPaymentDetails(ownBooking.Id);
            Assert.areEqual(ownBooking.Id, details.bookingId);
            Assert.areEqual('Payment Test Event', details.eventName);
            Assert.areEqual('Test General Ticket', details.ticketName);
            Assert.areEqual(1000, details.totalAmount);
            Assert.areEqual('Pending', details.bookingStatus);
            Assert.areEqual('Pending', details.paymentStatus);
            Assert.isTrue(details.canUseSimulator);
            Assert.isTrue(details.canPay);

            Boolean otherCustomerRejected = false;
            try {
                PaymentController.getPaymentDetails(otherBooking.Id);
            } catch (AuraHandledException ex) {
                otherCustomerRejected = true;
                Assert.areEqual('Booking not found.', ex.getMessage());
            }
            Assert.isTrue(otherCustomerRejected);

            Boolean otherPaymentRejected = false;
            try {
                PaymentController.simulatePayment(
                    otherBooking.Id,
                    'UPI',
                    true
                );
            } catch (AuraHandledException ex) {
                otherPaymentRejected = true;
                Assert.areEqual('Booking not found.', ex.getMessage());
            }
            Assert.isTrue(otherPaymentRejected);
        }
    }

    @IsTest
    static void testClientSelectedSuccessDoesNotSettlePaymentOrConfirmBooking() {
        User owner = getCustomer('payment-owner');
        Booking__c booking = getBooking('payment-owner');
        PaymentController.PaymentResult result;

        Test.startTest();
        System.runAs(owner) {
            result = PaymentController.simulatePayment(
                booking.Id,
                'UPI',
                true
            );
        }
        Test.stopTest();

        Booking__c unchangedBooking = [
            SELECT Booking_Status__c, Payment_Status__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];
        Assert.areEqual('Success', result.simulationOutcome);
        Assert.areEqual('Pending', result.bookingStatus);
        Assert.isTrue(result.message.contains('No funds were received'));
        Assert.areEqual('Pending', unchangedBooking.Booking_Status__c);
        Assert.areEqual('Pending', unchangedBooking.Payment_Status__c);
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Payment__c WHERE Booking__c = :booking.Id]
        );
    }

    @IsTest
    static void testFailedSimulationDoesNotCreatePaymentOrChangeBooking() {
        User owner = getCustomer('payment-owner');
        Booking__c booking = getBooking('payment-owner');
        PaymentController.PaymentResult result;

        System.runAs(owner) {
            result = PaymentController.simulatePayment(
                booking.Id,
                'Credit Card',
                false
            );
        }

        Booking__c unchangedBooking = [
            SELECT Booking_Status__c, Payment_Status__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];
        Assert.areEqual('Failure', result.simulationOutcome);
        Assert.areEqual('Pending', result.bookingStatus);
        Assert.areEqual('Pending', unchangedBooking.Booking_Status__c);
        Assert.areEqual('Pending', unchangedBooking.Payment_Status__c);
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Payment__c WHERE Booking__c = :booking.Id]
        );
    }

    @IsTest
    static void testSimulatorPermissionIsRequiredEvenForOwnBooking() {
        User customerWithoutSimulator = getCustomer('payment-other');
        Booking__c ownBooking = getBooking('payment-other');

        System.runAs(customerWithoutSimulator) {
            PaymentController.PaymentDetails details =
                PaymentController.getPaymentDetails(ownBooking.Id);
            Assert.isFalse(details.canUseSimulator);
            Assert.isFalse(details.canPay);

            Boolean rejected = false;
            try {
                PaymentController.simulatePayment(
                    ownBooking.Id,
                    'UPI',
                    true
                );
            } catch (AuraHandledException ex) {
                rejected = true;
                Assert.isTrue(ex.getMessage().contains('restricted'));
            }
            Assert.isTrue(rejected);
        }
    }

    @IsTest
    static void testMissingContactIsRejectedForPaymentAccess() {
        Booking__c booking = getBooking('payment-owner');
        Boolean rejected = false;

        try {
            PaymentController.getPaymentDetails(booking.Id);
        } catch (AuraHandledException ex) {
            rejected = true;
            Assert.isTrue(ex.getMessage().contains('not linked'));
        }
        Assert.isTrue(rejected);
    }

    @IsTest
    static void testExpiredBookingAndInvalidInputAreRejected() {
        User owner = getCustomer('payment-owner');
        Booking__c booking = getBooking('payment-owner');
        booking.Booking_Date__c = System.now().addMinutes(-31);
        update booking;

        System.runAs(owner) {
            Boolean expiredRejected = false;
            try {
                PaymentController.simulatePayment(
                    booking.Id,
                    'UPI',
                    true
                );
            } catch (AuraHandledException ex) {
                expiredRejected = true;
                Assert.isTrue(ex.getMessage().contains('expired'));
            }
            Assert.isTrue(expiredRejected);

            Boolean invalidMethodRejected = false;
            try {
                PaymentController.simulatePayment(
                    booking.Id,
                    'Cash',
                    true
                );
            } catch (AuraHandledException ex) {
                invalidMethodRejected = true;
            }
            Assert.isTrue(invalidMethodRejected);
        }
    }

    @IsTest
    static void testNullBookingIdIsRejected() {
        User owner = getCustomer('payment-owner');
        System.runAs(owner) {
            Boolean rejected = false;
            try {
                PaymentController.getPaymentDetails(null);
            } catch (AuraHandledException ex) {
                rejected = true;
            }
            Assert.isTrue(rejected);
        }
    }
}
