public with sharing class EpicEventzCatalogController {
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getPublishedEvents(String searchKey, String category, String city) {
        Map<String, Schema.SObjectField> fields = Event__c.SObjectType.getDescribe().fields.getMap();
        List<String> selectedFields = new List<String>{ 'Id', 'Name' };
        for (String fieldName : new List<String>{
            'Category__c', 'City__c', 'Start_Date_Time__c', 'Start_Date__c',
            'Base_Price__c', 'Poster_URL__c', 'Status__c'
        }) {
            if (fields.containsKey(fieldName)) {
                selectedFields.add(fieldName);
            }
        }

        List<String> conditions = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();
        String publishedStatus = 'Published';
        if (fields.containsKey('Status__c')
            && fields.get('Status__c').getDescribe().getType() == Schema.DisplayType.Picklist) {
            conditions.add('Status__c = :publishedStatus');
            binds.put('publishedStatus', publishedStatus);
        }

        addTextFilter(fields, conditions, binds, 'Name', searchKey, 'searchKey');
        addTextFilter(fields, conditions, binds, 'Category__c', category, 'category');
        addTextFilter(fields, conditions, binds, 'City__c', city, 'city');

        String query = 'SELECT ' + String.join(selectedFields, ', ')
            + ' FROM Event__c';
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        query += ' ORDER BY CreatedDate DESC LIMIT 100';

        return (List<Event__c>) Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
    }

    @AuraEnabled(cacheable=true)
    public static List<Registration__c> getCustomerBookings(Id attendeeId) {
        if (attendeeId == null) {
            return new List<Registration__c>();
        }

        Map<String, Schema.SObjectField> fields = Registration__c.SObjectType.getDescribe().fields.getMap();
        List<String> selectedFields = new List<String>{ 'Id', 'Name' };
        for (String fieldName : new List<String>{ 'Event__c', 'Registration_Status__c', 'Status__c' }) {
            if (fields.containsKey(fieldName)) {
                selectedFields.add(fieldName);
            }
        }

        String relationshipField = fields.containsKey('Event__c') ? 'Event__c' : null;
        if (relationshipField == null || !fields.containsKey('Attendee__c')) {
            return new List<Registration__c>();
        }

        String query = 'SELECT ' + String.join(selectedFields, ', ')
            + ', Event__r.Name FROM Registration__c'
            + ' WHERE Attendee__c = :attendeeId'
            + ' ORDER BY CreatedDate DESC LIMIT 100';
        return (List<Registration__c>) Database.queryWithBinds(
            query,
            new Map<String, Object>{ 'attendeeId' => attendeeId },
            AccessLevel.USER_MODE
        );
    }

    private static void addTextFilter(
        Map<String, Schema.SObjectField> fields,
        List<String> conditions,
        Map<String, Object> binds,
        String fieldName,
        String value,
        String bindName
    ) {
        if (String.isBlank(value) || !fields.containsKey(fieldName)) {
            return;
        }
        conditions.add(fieldName + ' LIKE :' + bindName);
        binds.put(bindName, '%' + String.escapeSingleQuotes(value.trim()) + '%');
    }
}
