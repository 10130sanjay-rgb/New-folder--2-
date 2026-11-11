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
        @AuraEnabled public Boolean canUseSimulator;
    }

    public class PaymentResult {
        @AuraEnabled public String simulationOutcome;
        @AuraEnabled public String bookingStatus;
        @AuraEnabled public String message;
        @AuraEnabled public String simulationReference;
    }

    @AuraEnabled
    public static PaymentDetails getPaymentDetails(Id bookingId) {
        if (bookingId == null) {
            throw newAuraException('Booking ID is required.');
        }

        Booking__c booking = getCustomerBooking(bookingId);
        Boolean canUseSimulator = FeatureManagement.checkPermission(
            'EpicEventz_Run_Payment_Simulator'
        );

        PaymentDetails details = new PaymentDetails();
        details.bookingId = booking.Id;
        details.eventName = booking.Event__r.Name;
        details.ticketName = booking.Ticket_Type__r.Name;
        details.bookingStatus = booking.Booking_Status__c;
        details.paymentStatus = booking.Payment_Status__c;
        details.ticketCode = booking.Ticket_Code__c;
        details.quantity = booking.Quantity__c;
        details.totalAmount = booking.Total_Amount__c;
        details.canUseSimulator = canUseSimulator;
        details.canPay = canUseSimulator &&
            booking.Booking_Status__c == 'Pending' &&
            booking.Payment_Status__c == 'Pending' &&
            booking.Inventory_Restored__c != true &&
            booking.Booking_Date__c != null &&
            booking.Booking_Date__c > System.now().addMinutes(-30);
        return details;
    }

    @AuraEnabled
    public static PaymentResult simulatePayment(
        Id bookingId,
        String paymentMethod,
        Boolean simulateSuccess
    ) {
        if (!FeatureManagement.checkPermission(
            'EpicEventz_Run_Payment_Simulator'
        )) {
            throw newAuraException(
                'The payment simulator is restricted to authorized development and testing users.'
            );
        }

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
            throw newAuraException('Select a simulation outcome.');
        }

        Booking__c booking = getCustomerBooking(bookingId);

        if (booking.Booking_Status__c != 'Pending' ||
            booking.Payment_Status__c != 'Pending') {
            throw newAuraException(
                'This booking is no longer awaiting payment.'
            );
        }
        if (booking.Inventory_Restored__c == true ||
            booking.Booking_Date__c == null ||
            booking.Booking_Date__c <= System.now().addMinutes(-30)) {
            throw newAuraException(
                'This booking has expired. Please book again.'
            );
        }
        if (booking.Total_Amount__c == null ||
            booking.Total_Amount__c < 0) {
            throw newAuraException('The booking amount is invalid.');
        }

        PaymentResult result = new PaymentResult();
        result.simulationOutcome = simulateSuccess ? 'Success' : 'Failure';
        result.bookingStatus = booking.Booking_Status__c;
        result.simulationReference = 'SIM-' +
            EncodingUtil.convertToHex(
                Crypto.generateAesKey(128)
            ).toUpperCase();
        result.message = simulateSuccess
            ? 'The payment simulation succeeded. No funds were received, and the booking remains pending until trusted payment confirmation is available.'
            : 'The payment simulation failed. No funds were received, and the booking remains pending.';
        return result;
    }

    private static Booking__c getCustomerBooking(Id bookingId) {
        Id contactId = EpicEventzCustomerContext.requireContactId();
        List<Booking__c> bookings = [
            SELECT Id, Event__r.Name, Ticket_Type__r.Name,
                   Booking_Status__c, Payment_Status__c,
                   Ticket_Code__c, Quantity__c, Total_Amount__c,
                   Booking_Date__c, Inventory_Restored__c
            FROM Booking__c
            WHERE Id = :bookingId
              AND Attendee__c = :contactId
            WITH USER_MODE
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
