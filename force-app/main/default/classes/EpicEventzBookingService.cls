public without sharing class EpicEventzBookingService {

    public static BookingController.BookingResult createBooking(
        Id eventId,
        Id ticketTypeId,
        Integer quantity
    ) {
        if (eventId == null || ticketTypeId == null) {
            throw newAuraException(
                'Please select an event and ticket type.'
            );
        }
        if (quantity == null || quantity < 1 || quantity > 10) {
            throw newAuraException(
                'Choose between 1 and 10 tickets per booking.'
            );
        }

        Id contactId = EpicEventzCustomerContext.requireContactId();
        Savepoint sp = Database.setSavepoint();
        try {
            Event__c selectedEvent =
                EpicEventzPublicCatalogData.getEventForBooking(eventId);
            if (selectedEvent == null) {
                throw newAuraException('This event is not available.');
            }
            selectedEvent =
                (Event__c) Security.stripInaccessible(
                    AccessType.READABLE,
                    new List<Event__c>{ selectedEvent }
                ).getRecords()[0];

            if (
                selectedEvent.Event_Status__c != 'Published' &&
                selectedEvent.Event_Status__c != 'Registration Open'
            ) {
                throw newAuraException(
                    'This event is not accepting bookings.'
                );
            }

            Ticket_Type__c ticket =
                EpicEventzPublicCatalogData.getTicketForBooking(
                    ticketTypeId,
                    selectedEvent.Id
                );
            if (ticket == null) {
                throw newAuraException(
                    'The selected ticket does not belong to this event or is not available.'
                );
            }
            ticket =
                (Ticket_Type__c) Security.stripInaccessible(
                    AccessType.READABLE,
                    new List<Ticket_Type__c>{ ticket }
                ).getRecords()[0];

            Datetime nowTime = System.now();
            if (
                ticket.Ticket_Status__c != 'Active' ||
                (
                    ticket.Sales_Start__c != null &&
                    ticket.Sales_Start__c > nowTime
                ) ||
                (
                    ticket.Sales_End__c != null &&
                    ticket.Sales_End__c < nowTime
                )
            ) {
                throw newAuraException(
                    'This ticket type is not currently available.'
                );
            }
            if (ticket.Price__c == null || ticket.Price__c < 0) {
                throw newAuraException(
                    'The ticket price is not configured correctly.'
                );
            }
            if (
                ticket.Available_Quantity__c == null ||
                ticket.Available_Quantity__c < quantity
            ) {
                throw newAuraException(
                    'There are not enough tickets available.'
                );
            }

            Decimal total = ticket.Price__c * quantity;
            String code = 'EE-' +
                EncodingUtil.convertToHex(
                    Crypto.generateAesKey(128)
                ).toUpperCase();
            Booking__c booking = new Booking__c(
                OwnerId = UserInfo.getUserId(),
                Attendee__c = contactId,
                Event__c = selectedEvent.Id,
                Ticket_Type__c = ticket.Id,
                Quantity__c = quantity,
                Total_Amount__c = total,
                Booking_Date__c = nowTime,
                Booking_Status__c = 'Pending',
                Payment_Status__c = 'Pending',
                Check_In_Status__c = 'Not Checked In',
                Inventory_Processed__c = true,
                Discount_Applied__c = false,
                Discount_Amount__c = 0,
                Ticket_Code__c = code
            );

            // Customer booking writes are server-authorized and Contact-bound.
            Database.insert(booking, AccessLevel.SYSTEM_MODE);
            ticket.Available_Quantity__c -= quantity;
            Database.update(ticket, AccessLevel.SYSTEM_MODE);

            BookingController.BookingResult result =
                new BookingController.BookingResult();
            result.bookingId = booking.Id;
            result.ticketCode = code;
            result.totalAmount = total;
            result.message =
                'Booking created. Payment confirmation is not available yet.';
            return result;
        } catch (Exception ex) {
            Database.rollback(sp);
            if (ex instanceof AuraHandledException) {
                throw (AuraHandledException) ex;
            }
            throw newAuraException(
                'Unable to create the booking: ' + ex.getMessage()
            );
        }
    }

    private static AuraHandledException newAuraException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
