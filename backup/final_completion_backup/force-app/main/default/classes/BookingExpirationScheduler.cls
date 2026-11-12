public with sharing class BookingExpirationScheduler
    implements Schedulable {

    private static final String JOB_NAME =
        'EpicEventz Unpaid Booking Expiration Hourly';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(
            new BookingExpirationBatch(30),
            100
        );
    }

    public static void scheduleJobs() {
        List<CronTrigger> existingJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
              AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING')
            LIMIT 1
        ];

        if (existingJobs.isEmpty()) {
            System.schedule(
                JOB_NAME,
                '0 0 * * * ?',
                new BookingExpirationScheduler()
            );
        }
    }

    public static void abortJobs() {
        List<CronTrigger> activeJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE
                'EpicEventz Unpaid Booking Expiration%'
              AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING')
        ];

        for (CronTrigger job : activeJobs) {
            System.abortJob(job.Id);
        }
    }
}