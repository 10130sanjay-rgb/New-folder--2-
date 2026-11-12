@IsTest
private class PaymentControllerTest {

    /*
     * Create test event, ticket type, and booking.
     */
    @TestSetup
    static void setupData() {

        // 1. Create the test event
        Event__c eventRecord = new Event__c(
            Name = 'Payment Test Event',
            Event_Code__c = 'PAYTEST001',
            Capacity__c = 100,
            Event_Status__c = 'Published',
            Start_Date_Time__c = System.now().addDays(5),
            End_Date_Time__c = System.now().addDays(5).addHours(2)
        );

        insert eventRecord;

        // 2. Create the ticket type
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

        // 3. Create the booking using BookingController
        BookingController.BookingResult bookingResult =
            BookingController.createBooking(
                eventRecord.Id,
                ticket.Id,
                'Test',
                'Attendee',
                'paymenttest@example.com',
                null,
                2
            );

        System.assertNotEquals(
            null,
            bookingResult.bookingId,
            'The test booking should be created successfully.'
        );

        System.assertNotEquals(
            null,
            bookingResult.ticketCode,
            'The booking should have a ticket code.'
        );
    }

    /*
     * Retrieve the booking created during test setup.
     */
    private static Booking__c getTestBooking() {

        List<Booking__c> bookings = [
            SELECT Id,
                   Booking_Status__c,
                   Payment_Status__c,
                   Total_Amount__c,
                   Ticket_Code__c,
                   Booking_Date__c,
                   Inventory_Restored__c
            FROM Booking__c
            WHERE Event__r.Name = 'Payment Test Event'
            LIMIT 1
        ];

        System.assertEquals(
            1,
            bookings.size(),
            'The test booking should exist.'
        );

        return bookings[0];
    }

    /*
     * Test 1: Retrieve payment details.
     */
    @IsTest
    static void testGetPaymentDetails() {

        Booking__c booking = getTestBooking();

        Test.startTest();

        PaymentController.PaymentDetails details =
            PaymentController.getPaymentDetails(booking.Id);

        Test.stopTest();

        System.assertEquals(booking.Id, details.bookingId);
        System.assertEquals('Payment Test Event', details.eventName);
        System.assertEquals('Test General Ticket', details.ticketName);
        System.assertEquals(1000, details.totalAmount);
        System.assertEquals('Pending', details.bookingStatus);
        System.assertEquals('Pending', details.paymentStatus);
        System.assertEquals(true, details.canPay);
        System.assertNotEquals(null, details.ticketCode);
    }

    /*
     * Test 2: Successful payment.
     */
    @IsTest
    static void testSuccessfulPayment() {

        Booking__c booking = getTestBooking();

        Test.startTest();

        PaymentController.PaymentResult result =
            PaymentController.simulatePayment(
                booking.Id,
                'UPI',
                true
            );

        Test.stopTest();

        Booking__c updatedBooking = [
            SELECT Booking_Status__c, Payment_Status__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];

        Payment__c payment = [
            SELECT Payment_Status__c,
                   Amount__c,
                   Payment_Method__c,
                   Payment_Gateway__c,
                   Transaction_ID__c
            FROM Payment__c
            WHERE Booking__c = :booking.Id
            LIMIT 1
        ];

        System.assertEquals('Successful', payment.Payment_Status__c);
        System.assertEquals(1000, payment.Amount__c);
        System.assertEquals('UPI', payment.Payment_Method__c);
        System.assertEquals('Other', payment.Payment_Gateway__c);

        System.assertEquals('Paid', updatedBooking.Payment_Status__c);
        System.assertEquals('Confirmed', updatedBooking.Booking_Status__c);

        System.assertNotEquals(null, result.paymentId);
        System.assertNotEquals(null, result.transactionId);
        System.assertEquals('Successful', result.paymentStatus);
        System.assertEquals('Confirmed', result.bookingStatus);

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Payment__c
                WHERE Booking__c = :booking.Id
            ]
        );
    }

    /*
     * Test 3: Failed payment.
     */
    @IsTest
    static void testFailedPayment() {

        Booking__c booking = getTestBooking();

        Test.startTest();

        PaymentController.PaymentResult result =
            PaymentController.simulatePayment(
                booking.Id,
                'Credit Card',
                false
            );

        Test.stopTest();

        Booking__c updatedBooking = [
            SELECT Booking_Status__c, Payment_Status__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];

        Payment__c payment = [
            SELECT Payment_Status__c,
                   Payment_Method__c,
                   Amount__c
            FROM Payment__c
            WHERE Booking__c = :booking.Id
            LIMIT 1
        ];

        System.assertEquals('Failed', payment.Payment_Status__c);
        System.assertEquals('Credit Card', payment.Payment_Method__c);
        System.assertEquals(1000, payment.Amount__c);

        System.assertEquals('Pending', updatedBooking.Payment_Status__c);
        System.assertEquals('Pending', updatedBooking.Booking_Status__c);

        System.assertEquals('Failed', result.paymentStatus);

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Payment__c
                WHERE Booking__c = :booking.Id
            ]
        );
    }

    /*
     * Test 4: Retry after a failed payment.
     */
    @IsTest
    static void testRetryAfterFailedPayment() {

        Booking__c booking = getTestBooking();

        Test.startTest();

        PaymentController.PaymentResult firstResult =
            PaymentController.simulatePayment(
                booking.Id,
                'UPI',
                false
            );

        PaymentController.PaymentResult retryResult =
            PaymentController.simulatePayment(
                booking.Id,
                'Debit Card',
                true
            );

        Test.stopTest();

        Booking__c updatedBooking = [
            SELECT Booking_Status__c, Payment_Status__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];

        System.assertEquals('Failed', firstResult.paymentStatus);
        System.assertEquals('Successful', retryResult.paymentStatus);

        System.assertEquals('Paid', updatedBooking.Payment_Status__c);
        System.assertEquals('Confirmed', updatedBooking.Booking_Status__c);

        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM Payment__c
                WHERE Booking__c = :booking.Id
            ]
        );

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Payment__c
                WHERE Booking__c = :booking.Id
                AND Payment_Status__c = 'Successful'
            ]
        );
    }

    /*
     * Test 5: Reject a second successful payment.
     */
    @IsTest
    static void testDuplicateSuccessfulPaymentRejected() {

        Booking__c booking = getTestBooking();

        Test.startTest();

        PaymentController.PaymentResult firstResult =
            PaymentController.simulatePayment(
                booking.Id,
                'UPI',
                true
            );

        Boolean exceptionThrown = false;

        try {
            PaymentController.simulatePayment(
                booking.Id,
                'UPI',
                true
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals('Successful', firstResult.paymentStatus);

        System.assertEquals(
            true,
            exceptionThrown,
            'A second successful payment attempt must be rejected.'
        );

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Payment__c
                WHERE Booking__c = :booking.Id
            ]
        );
    }

    /*
     * Test 6: Reject payment for an expired booking.
     */
    @IsTest
    static void testExpiredBookingRejected() {

        Booking__c booking = getTestBooking();

        booking.Booking_Date__c = System.now().addMinutes(-31);
        update booking;

        Test.startTest();

        Boolean exceptionThrown = false;

        try {
            PaymentController.simulatePayment(
                booking.Id,
                'UPI',
                true
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Expired bookings must not accept payment.'
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Payment__c
                WHERE Booking__c = :booking.Id
            ]
        );
    }

    /*
     * Test 7: Reject a null booking ID.
     */
    @IsTest
    static void testNullBookingIdRejected() {

        Test.startTest();

        Boolean exceptionThrown = false;

        try {
            PaymentController.getPaymentDetails(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'A null booking ID must be rejected.'
        );
    }
}