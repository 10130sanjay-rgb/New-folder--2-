public with sharing class EpicEventzCustomerContext {

    public static Id requireContactId() {
        if (UserInfo.getUserType() == 'Guest') {
            throw handledException(
                'Sign in with a linked customer account to continue.'
            );
        }

        User currentUser = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (currentUser.ContactId == null) {
            throw handledException(
                'Your Salesforce user is not linked to a customer Contact.'
            );
        }
        return currentUser.ContactId;
    }

    private static AuraHandledException handledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
