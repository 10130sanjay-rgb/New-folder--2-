@IsTest
private class BookingExpirationSchedulerTest {

    @IsTest
    static void testSchedulerExecutesBatch() {
        Test.startTest();

        String cronExpression = '0 0 2 * * ?';

        String jobId = System.schedule(
            'EpicEventz Scheduler Test',
            cronExpression,
            new BookingExpirationScheduler()
        );

        Test.stopTest();

        System.assertNotEquals(
            null,
            jobId,
            'The scheduler should return a scheduled job ID.'
        );

        CronTrigger scheduledJob = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals(
            cronExpression,
            scheduledJob.CronExpression
        );
    }

    @IsTest
static void testScheduleJobsCreatesOneHourlyJobWithoutDuplicates() {
    Test.startTest();

    BookingExpirationScheduler.scheduleJobs();
    BookingExpirationScheduler.scheduleJobs();

    Test.stopTest();

    List<CronTrigger> jobs = [
        SELECT Id, CronJobDetail.Name, CronExpression
        FROM CronTrigger
        WHERE CronJobDetail.Name =
            'EpicEventz Unpaid Booking Expiration Hourly'
    ];

    System.assertEquals(
        1,
        jobs.size(),
        'Only one hourly expiration job should exist.'
    );

    System.assertEquals(
        '0 0 * * * ?',
        jobs[0].CronExpression,
        'The expiration job should run once per hour.'
    );
}

    @IsTest
    static void testAbortJobs() {
        String jobName = 'EpicEventz Unpaid Booking Expiration Test';

        String jobId = System.schedule(
            jobName,
            '0 10 3 * * ?',
            new BookingExpirationScheduler()
        );

        Test.startTest();

        BookingExpirationScheduler.abortJobs();

        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals(
            0,
            jobs.size(),
            'The test job should be removed after aborting.'
        );
    }
}