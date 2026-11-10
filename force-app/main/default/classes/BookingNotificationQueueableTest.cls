@IsTest
private class BookingNotificationQueueableTest {

    @IsTest
    static void testQueueableWithEmptyBookingIds() {
        Test.startTest();

        Id jobId = System.enqueueJob(
            new BookingNotificationQueueable(new Set<Id>())
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void testQueueableWithNullBookingIds() {
        Test.startTest();

        Id jobId = System.enqueueJob(
            new BookingNotificationQueueable(null)
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void testQueueableWithNoMatchingBookings() {
        Id fakeBookingId = (Id) 'a01000000000001AAA';

        Test.startTest();

        Id jobId = System.enqueueJob(
            new BookingNotificationQueueable(
                new Set<Id>{ fakeBookingId }
            )
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }
}