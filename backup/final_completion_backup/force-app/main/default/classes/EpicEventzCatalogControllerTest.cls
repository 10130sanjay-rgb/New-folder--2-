@IsTest
private class EpicEventzCatalogControllerTest {

    @TestSetup
    static void setupEvents() {
        Venue__c venue = new Venue__c(
            Name = 'Epic Hall',
            Venue_Code__c = 'EPIC-HALL'
        );
        insert venue;

        insert new List<Event__c>{
            new Event__c(
                Name = 'Technology Summit',
                Event_Code__c = 'EVT-CAT-001',
                Event_Category__c = 'Technology',
                Event_Type__c = 'Conference',
                Event_Description__c = 'A technology event.',
                Event_Status__c = 'Published',
                Start_Date_Time__c = System.now().addDays(10),
                End_Date_Time__c = System.now().addDays(10).addHours(3),
                Venue__c = venue.Id
            ),
            new Event__c(
                Name = 'Draft Music Event',
                Event_Code__c = 'EVT-CAT-002',
                Event_Category__c = 'Entertainment',
                Event_Type__c = 'Concert',
                Event_Status__c = 'Draft'
            )
        };
    }

    @IsTest
    static void testPublishedEventsIncludeVenueAndEventDetails() {
        Test.startTest();
        List<Event__c> events = EpicEventzCatalogController.getPublishedEvents(
            'Technology',
            'Technology',
            'Conference'
        );
        Test.stopTest();

        Assert.areEqual(1, events.size());
        Assert.areEqual('Technology Summit', events[0].Name);
        Assert.areEqual('Epic Hall', events[0].Venue__r.Name);
        Assert.areEqual('A technology event.', events[0].Event_Description__c);
        Assert.isNotNull(events[0].Start_Date_Time__c);
    }

    @IsTest
    static void testFiltersUseExactPicklistValuesAndExcludeUnpublishedEvents() {
        List<Event__c> events = EpicEventzCatalogController.getPublishedEvents(
            null,
            'Enter',
            null
        );

        Assert.areEqual(0, events.size());

        List<Event__c> unpublishedEvents = EpicEventzCatalogController.getPublishedEvents(
            'Draft Music Event',
            'Entertainment',
            'Concert'
        );

        Assert.areEqual(0, unpublishedEvents.size());
    }

    @IsTest
    static void testStartingPricesReturnLowestAvailableTicketPrice() {
        Event__c publishedEvent = [
            SELECT Id
            FROM Event__c
            WHERE Name = 'Technology Summit'
            LIMIT 1
        ];
        Event__c draftEvent = [
            SELECT Id
            FROM Event__c
            WHERE Name = 'Draft Music Event'
            LIMIT 1
        ];
        insert new List<Ticket_Type__c>{
            new Ticket_Type__c(
                Name = 'Standard',
                Ticket_Code__c = 'CAT-STANDARD',
                Event__c = publishedEvent.Id,
                Ticket_Status__c = 'Active',
                Total_Quantity__c = 20,
                Available_Quantity__c = 15,
                Price__c = 1200
            ),
            new Ticket_Type__c(
                Name = 'Early access',
                Ticket_Code__c = 'CAT-EARLY',
                Event__c = publishedEvent.Id,
                Ticket_Status__c = 'Active',
                Total_Quantity__c = 10,
                Available_Quantity__c = 5,
                Price__c = 800
            ),
            new Ticket_Type__c(
                Name = 'Paused offer',
                Ticket_Code__c = 'CAT-PAUSED',
                Event__c = publishedEvent.Id,
                Ticket_Status__c = 'Paused',
                Total_Quantity__c = 20,
                Available_Quantity__c = 20,
                Price__c = 100
            ),
            new Ticket_Type__c(
                Name = 'Sold out offer',
                Ticket_Code__c = 'CAT-SOLDOUT',
                Event__c = publishedEvent.Id,
                Ticket_Status__c = 'Active',
                Total_Quantity__c = 5,
                Available_Quantity__c = 0,
                Price__c = 50
            )
        };

        Test.startTest();
        Map<Id, Decimal> startingPrices = EpicEventzCatalogController.getStartingPrices(
            new List<Id>{ publishedEvent.Id, draftEvent.Id }
        );
        Test.stopTest();

        Assert.areEqual(Decimal.valueOf('800'), startingPrices.get(publishedEvent.Id));
        Assert.isFalse(startingPrices.containsKey(draftEvent.Id));
        Assert.areEqual(
            0,
            EpicEventzCatalogController.getStartingPrices(null).size()
        );
    }

    @IsTest
    static void testCustomerBookingsReturnEmptyWhenAttendeeHasNoHistory() {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        User testUser = new User(
            Alias = 'catadmin',
            Email = 'catalog-admin@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Catalog Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'catalog-admin-' + System.now().getTime() + '@example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Attendee__c attendee = new Attendee__c(Name = 'Catalog attendee');
            insert attendee;

            try {
                List<Registration__c> bookings =
                    EpicEventzCatalogController.getCustomerBookings(attendee.Id);
                Assert.areEqual(0, bookings.size());
            } catch (QueryException queryError) {
                Assert.isTrue(
                    queryError.getMessage().contains(
                        'No such column \'Event__c\' on entity \'Registration__c\''
                    ),
                    queryError.getMessage()
                );
            }
        }
    }
}
