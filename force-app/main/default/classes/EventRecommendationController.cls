public with sharing class EventRecommendationController {
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getRecommendations(Id eventId) {
        if (eventId == null) {
            throw new AuraHandledException('An event Id is required.');
        }

        return [
            SELECT Id, Name, CreatedDate
            FROM Event__c
            WHERE Id != :eventId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 3
        ];
    }
}
