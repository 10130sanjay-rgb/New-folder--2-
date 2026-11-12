public with sharing class BookingController {

    public class TicketOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal availableQuantity;

        public TicketOption(Ticket_Type__c ticket) {
            id = ticket.Id;
            name = ticket.Name;
            category = ticket.Ticket_Category__c;
            description = ticket.Description__c;
            price = ticket.Price__c;
            availableQuantity = ticket.Available_Quantity__c;
        }
    }

    public class BookingResult {
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String ticketCode;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static List<TicketOption> getTicketTypes(Id eventId) {
        if (eventId == null) {
            throw newAuraException('Please select an event.');
        }

        List<TicketOption> results = new List<TicketOption>();

        for (Ticket_Type__c ticket : [
            SELECT Id, Name, Ticket_Category__c, Description__c,
                   Price__c, Available_Quantity__c
            FROM Ticket_Type__c
            WHERE Event__c = :eventId
              AND Ticket_Status__c = 'Active'
              AND (Sales_Start__c = null OR Sales_Start__c <= :System.now())
              AND (Sales_End__c = null OR Sales_End__c >= :System.now())
              AND Available_Quantity__c > 0
            ORDER BY Price__c ASC
        ]) {
            results.add(new TicketOption(ticket));
        }

        return results;
    }

    @AuraEnabled
    public static BookingResult createBooking(
        Id eventId,
        Id ticketTypeId,
        String firstName,
        String lastName,
        String email,
        String phone,
        Integer quantity
    ) {
        if (eventId == null || ticketTypeId == null) {
            throw newAuraException(
                'Please select an event and ticket type.'
            );
        }

        if (String.isBlank(lastName) || String.isBlank(email)) {
            throw newAuraException(
                'Last name and email are required.'
            );
        }

        if (quantity == null || quantity < 1 || quantity > 10) {
            throw newAuraException(
                'Choose between 1 and 10 tickets per booking.'
            );
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // 1. Lock and validate the selected event.
            Event__c selectedEvent = [
                SELECT Id, Name, Event_Status__c
                FROM Event__c
                WHERE Id = :eventId
                LIMIT 1
                FOR UPDATE
            ];

            if (
                selectedEvent.Event_Status__c != 'Published' &&
                selectedEvent.Event_Status__c != 'Registration Open'
            ) {
                throw newAuraException(
                    'This event is not accepting bookings.'
                );
            }

            // 2. Lock and validate the selected ticket.
            Ticket_Type__c ticket = [
                SELECT Id, Name, Event__c, Price__c,
                       Available_Quantity__c, Ticket_Status__c,
                       Sales_Start__c, Sales_End__c
                FROM Ticket_Type__c
                WHERE Id = :ticketTypeId
                LIMIT 1
                FOR UPDATE
            ];

            if (ticket.Event__c != selectedEvent.Id) {
                throw newAuraException(
                    'The selected ticket does not belong to this event.'
                );
            }

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

            // 3. Find the attendee Contact using the email address.
            // If no Contact exists, create one.
            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email, Phone
                FROM Contact
                WHERE Email = :email
                LIMIT 1
            ];

            Contact attendee;

            if (!contacts.isEmpty()) {
                attendee = contacts[0];
            } else {
                attendee = new Contact(
                    FirstName = String.isBlank(firstName)
                        ? null
                        : firstName.trim(),
                    LastName = lastName.trim(),
                    Email = email.trim(),
                    Phone = String.isBlank(phone)
                        ? null
                        : phone.trim()
                );

                insert attendee;
            }

            // 4. Calculate the booking amount and generate a ticket code.
            Decimal total = ticket.Price__c * quantity;

            String code = 'EE-' +
                EncodingUtil.convertToHex(
                    Crypto.generateAesKey(128)
                ).toUpperCase();

            // 5. Create the booking and link it to the Contact.
            Booking__c booking = new Booking__c(
                Attendee__c = attendee.Id,

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

            insert booking;

            // 6. Reduce the available ticket inventory.
            update new Ticket_Type__c(
                Id = ticket.Id,
                Available_Quantity__c =
                    ticket.Available_Quantity__c - quantity
            );

            // 7. Return the booking details to the attendee page.
            BookingResult result = new BookingResult();

            result.bookingId = booking.Id;
            result.ticketCode = code;
            result.totalAmount = total;

            result.message =
                'Booking created. Complete payment to confirm your tickets.';

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

    private static AuraHandledException newAuraException(
        String message
    ) {
        AuraHandledException ex =
            new AuraHandledException(message);

        ex.setMessage(message);

        return ex;
    }
}