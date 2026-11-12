public with sharing class PaymentController {

    public class PaymentDetails {
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String ticketName;
        @AuraEnabled public String bookingStatus;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public String ticketCode;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Boolean canPay;
    }

    public class PaymentResult {
        @AuraEnabled public Id paymentId;
        @AuraEnabled public String transactionId;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public String bookingStatus;
        @AuraEnabled public String message;
    }

    /**
     * Returns the details required by the payment screen.
     */
    @AuraEnabled
    public static PaymentDetails getPaymentDetails(Id bookingId) {

        if (bookingId == null) {
            throw newAuraException('Booking ID is required.');
        }

        Booking__c booking = getBooking(bookingId);

        PaymentDetails details = new PaymentDetails();
        details.bookingId = booking.Id;
        details.eventName = booking.Event__r.Name;
        details.ticketName = booking.Ticket_Type__r.Name;
        details.bookingStatus = booking.Booking_Status__c;
        details.paymentStatus = booking.Payment_Status__c;
        details.ticketCode = booking.Ticket_Code__c;
        details.quantity = booking.Quantity__c;
        details.totalAmount = booking.Total_Amount__c;

        details.canPay =
            booking.Booking_Status__c == 'Pending' &&
            booking.Payment_Status__c == 'Pending' &&
            booking.Inventory_Restored__c != true &&
            booking.Booking_Date__c != null &&
            booking.Booking_Date__c > System.now().addMinutes(-30);

        return details;
    }

    /**
     * Simulates a successful or failed payment.
     *
     * This is for development and demonstration only.
     * It does not collect real money.
     */
    @AuraEnabled
    public static PaymentResult simulatePayment(
        Id bookingId,
        String paymentMethod,
        Boolean simulateSuccess
    ) {

        if (bookingId == null) {
            throw newAuraException('Booking ID is required.');
        }

        Set<String> allowedMethods = new Set<String>{
            'UPI',
            'Credit Card',
            'Debit Card',
            'Net Banking',
            'Wallet'
        };

        if (String.isBlank(paymentMethod) ||
            !allowedMethods.contains(paymentMethod)) {
            throw newAuraException('Select a valid payment method.');
        }

        if (simulateSuccess == null) {
            throw newAuraException('Select a payment outcome.');
        }

        Savepoint savepoint = Database.setSavepoint();

        try {
            Booking__c booking = [
                SELECT Id, Event__c, Ticket_Type__c,
                       Booking_Status__c, Payment_Status__c,
                       Booking_Date__c, Total_Amount__c,
                       Inventory_Restored__c
                FROM Booking__c
                WHERE Id = :bookingId
                LIMIT 1
                FOR UPDATE
            ];

            if (booking.Booking_Status__c != 'Pending' ||
                booking.Payment_Status__c != 'Pending') {
                throw newAuraException(
                    'This booking is no longer awaiting payment.'
                );
            }

            if (booking.Inventory_Restored__c == true) {
                throw newAuraException(
                    'This booking has expired. Please book again.'
                );
            }

            if (booking.Booking_Date__c == null ||
                booking.Booking_Date__c <= System.now().addMinutes(-30)) {
                throw newAuraException(
                    'This booking has expired. Please book again.'
                );
            }

            if (booking.Total_Amount__c == null ||
                booking.Total_Amount__c < 0) {
                throw newAuraException(
                    'The booking amount is invalid.'
                );
            }

            List<Payment__c> existingSuccessfulPayments = [
                SELECT Id
                FROM Payment__c
                WHERE Booking__c = :booking.Id
                  AND Payment_Status__c = 'Successful'
                LIMIT 1
            ];

            if (!existingSuccessfulPayments.isEmpty()) {
                throw newAuraException(
                    'A successful payment already exists for this booking.'
                );
            }

            String transactionId = 'DEMO-' +
                EncodingUtil.convertToHex(
                    Crypto.generateAesKey(128)
                ).toUpperCase();

            Payment__c payment = new Payment__c(
                Booking__c = booking.Id,
                Amount__c = booking.Total_Amount__c,
                Payment_Method__c = paymentMethod,
                Payment_Gateway__c = 'Other',
                Transaction_ID__c = transactionId,
                Payment_Date__c = System.now(),
                Refund_Amount__c = 0,
                Payment_Status__c =
                    simulateSuccess ? 'Successful' : 'Failed'
            );

            insert payment;

            if (simulateSuccess) {
                booking.Payment_Status__c = 'Paid';
                booking.Booking_Status__c = 'Confirmed';
                update booking;
            }

            PaymentResult result = new PaymentResult();
            result.paymentId = payment.Id;
            result.transactionId = transactionId;
            result.paymentStatus = payment.Payment_Status__c;
            result.bookingStatus = booking.Booking_Status__c;
            result.message = simulateSuccess
                ? 'Simulated payment successful. Your booking is confirmed.'
                : 'Simulated payment failed. You may retry while the booking remains valid.';

            return result;

        } catch (Exception ex) {
            Database.rollback(savepoint);

            if (ex instanceof AuraHandledException) {
                throw (AuraHandledException) ex;
            }

            throw newAuraException(
                'Unable to process the simulated payment. Please try again.'
            );
        }
    }

    private static Booking__c getBooking(Id bookingId) {

        List<Booking__c> bookings = [
            SELECT Id, Event__r.Name, Ticket_Type__r.Name,
                   Booking_Status__c, Payment_Status__c,
                   Ticket_Code__c, Quantity__c, Total_Amount__c,
                   Booking_Date__c, Inventory_Restored__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        if (bookings.isEmpty()) {
            throw newAuraException('Booking not found.');
        }

        return bookings[0];
    }

    private static AuraHandledException newAuraException(
        String message
    ) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}