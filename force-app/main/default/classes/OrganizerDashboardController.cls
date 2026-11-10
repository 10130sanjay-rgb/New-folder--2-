public with sharing class OrganizerDashboardController {

    public class DashboardData {
        @AuraEnabled public Integer totalEvents { get; set; }
        @AuraEnabled public Integer upcomingEvents { get; set; }
        @AuraEnabled public Integer totalBookings { get; set; }
        @AuraEnabled public Integer confirmedBookings { get; set; }
        @AuraEnabled public Integer ticketsSold { get; set; }
        @AuraEnabled public Decimal totalRevenue { get; set; }
        @AuraEnabled public List<EventSummary> recentEvents { get; set; }

        public DashboardData() {
            totalEvents = 0;
            upcomingEvents = 0;
            totalBookings = 0;
            confirmedBookings = 0;
            ticketsSold = 0;
            totalRevenue = 0;
            recentEvents = new List<EventSummary>();
        }
    }

    public class EventSummary {
        @AuraEnabled public Id eventId { get; set; }
        @AuraEnabled public String eventName { get; set; }
        @AuraEnabled public String eventStatus { get; set; }
        @AuraEnabled public String displayStatus { get; set; }
        @AuraEnabled public Datetime startDateTime { get; set; }
        @AuraEnabled public String venueName { get; set; }

        @AuraEnabled public Decimal capacity { get; set; }
        @AuraEnabled public Integer ticketsBooked { get; set; }
        @AuraEnabled public Integer ticketsAvailable { get; set; }
        @AuraEnabled public Decimal bookingPercentage { get; set; }
        public Datetime endDateTime { get; set; }

        public EventSummary(Event__c eventRecord) {
            eventId = eventRecord.Id;
            eventName = eventRecord.Name;
            eventStatus = eventRecord.Event_Status__c;
            startDateTime = eventRecord.Start_Date_Time__c;
            endDateTime = eventRecord.End_Date_Time__c;

            venueName = eventRecord.Venue__r != null
                ? eventRecord.Venue__r.Name
                : 'Venue not specified';

            capacity = eventRecord.Capacity__c != null
                ? eventRecord.Capacity__c
                : 0;

            ticketsBooked = 0;
            ticketsAvailable = capacity.intValue();
            bookingPercentage = 0;
            displayStatus = 'Upcoming';
        }
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {

        DashboardData result = new DashboardData();
        Datetime nowTime = System.now();

        // Overall event statistics
        result.totalEvents = [
            SELECT COUNT()
            FROM Event__c
        ];

        result.upcomingEvents = [
            SELECT COUNT()
            FROM Event__c
            WHERE Start_Date_Time__c > :nowTime
              AND Event_Status__c != 'Cancelled'
              AND Event_Status__c != 'Completed'
        ];

        // Overall booking statistics
        result.totalBookings = [
            SELECT COUNT()
            FROM Booking__c
        ];

        result.confirmedBookings = [
            SELECT COUNT()
            FROM Booking__c
            WHERE Booking_Status__c = 'Confirmed'
        ];

        // Overall tickets sold
        AggregateResult ticketTotals = [
            SELECT SUM(Quantity__c) totalQuantity
            FROM Booking__c
            WHERE Booking_Status__c = 'Confirmed'
        ];

        Object ticketQuantity = ticketTotals.get('totalQuantity');

        if (ticketQuantity != null) {
            result.ticketsSold =
                Decimal.valueOf(String.valueOf(ticketQuantity)).intValue();
        }

        // Overall successful payment revenue
        AggregateResult revenueTotals = [
            SELECT SUM(Amount__c) totalAmount
            FROM Payment__c
            WHERE Payment_Status__c = 'Successful'
        ];

        Object revenueAmount = revenueTotals.get('totalAmount');

        if (revenueAmount != null) {
            result.totalRevenue =
                Decimal.valueOf(String.valueOf(revenueAmount));
        }

        // Retrieve all events
        List<Event__c> eventRecords = [
            SELECT Id,
                   Name,
                   Event_Status__c,
                   Start_Date_Time__c,
                   End_Date_Time__c,
                   Capacity__c,
                   Venue__r.Name
            FROM Event__c
            ORDER BY Start_Date_Time__c DESC NULLS LAST
        ];

        Map<Id, EventSummary> eventSummaryMap =
            new Map<Id, EventSummary>();

        for (Event__c eventRecord : eventRecords) {
            EventSummary summary = new EventSummary(eventRecord);
            eventSummaryMap.put(eventRecord.Id, summary);
            result.recentEvents.add(summary);
        }

        // Calculate confirmed tickets for every event
        if (!eventSummaryMap.isEmpty()) {
            for (AggregateResult bookingResult : [
                SELECT Event__c eventId,
                       SUM(Quantity__c) totalTickets
                FROM Booking__c
                WHERE Event__c IN :eventSummaryMap.keySet()
                  AND Booking_Status__c = 'Confirmed'
                GROUP BY Event__c
            ]) {
                Id eventId = (Id) bookingResult.get('eventId');
                Object totalTickets = bookingResult.get('totalTickets');

                EventSummary summary = eventSummaryMap.get(eventId);

                if (summary != null && totalTickets != null) {
                    summary.ticketsBooked =
                        Decimal.valueOf(
                            String.valueOf(totalTickets)
                        ).intValue();
                }
            }
        }

        // Calculate availability, progress and display status
        for (EventSummary summary : result.recentEvents) {

            Integer eventCapacity = summary.capacity.intValue();

            summary.ticketsAvailable = Math.max(
                0,
                eventCapacity - summary.ticketsBooked
            );

            // Round percentage to the nearest whole number
            if (eventCapacity > 0) {
    Decimal percentage =
        (Decimal.valueOf(summary.ticketsBooked)
        / summary.capacity) * 100;

    summary.bookingPercentage =
        percentage.setScale(1, RoundingMode.HALF_UP);
} else {
    summary.bookingPercentage = 0;
}

            // Status priority:
            // Cancelled > Completed > Sold Out > Active > Upcoming

            if (summary.eventStatus == 'Cancelled') {

                summary.displayStatus = 'Cancelled';

            } else if (
                summary.eventStatus == 'Completed' ||
                (
                    summary.endDateTime != null &&
                    summary.endDateTime <= nowTime
                )
            ) {

                summary.displayStatus = 'Completed';

            } else if (
                eventCapacity > 0 &&
                summary.ticketsBooked >= eventCapacity
            ) {

                summary.displayStatus = 'Sold Out';

            } else if (
                summary.startDateTime != null &&
                summary.startDateTime <= nowTime &&
                summary.endDateTime != null &&
                summary.endDateTime > nowTime
            ) {

                summary.displayStatus = 'Active';

            } else if (
                summary.startDateTime != null &&
                summary.startDateTime <= nowTime &&
                summary.endDateTime == null
            ) {

                // Without an end time, rely on the stored event status.
                summary.displayStatus =
                    summary.eventStatus == 'Completed'
                    ? 'Completed'
                    : 'Active';

            } else {

                summary.displayStatus = 'Upcoming';

            }
        }

        return result;
    }
}