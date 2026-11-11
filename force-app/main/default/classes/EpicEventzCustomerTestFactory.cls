@IsTest
public class EpicEventzCustomerTestFactory {

    public class CustomerContext {
        public Id userId;
        public Id contactId;
    }

    public static CustomerContext createCustomer(
        String customerKey,
        Boolean grantSimulator
    ) {
        String uniqueValue = String.valueOf(Datetime.now().getTime()) +
            String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        UserRole portalRole = [
            SELECT Id
            FROM UserRole
            LIMIT 1
        ];
        Profile internalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        User accountOwner = new User(
            Alias = 'eeowner',
            Email = 'ee-owner-' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'EpicEventz Test Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = internalProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserRoleId = portalRole.Id,
            Username = 'ee-owner-' + uniqueValue + '@example.com'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert accountOwner;
        }

        Account accountRecord = new Account(
            Name = 'EpicEventz Test Account ' + customerKey,
            OwnerId = accountOwner.Id
        );
        Contact customerContact = new Contact(
            AccountId = accountRecord.Id,
            Email = 'ee-' + customerKey + '-' + uniqueValue + '@example.com',
            LastName = 'Customer ' + customerKey
        );
        System.runAs(accountOwner) {
            insert accountRecord;
            customerContact.AccountId = accountRecord.Id;
            insert customerContact;
        }

        Profile customerProfile = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'PowerCustomerSuccess'
              AND Name LIKE '%Community Plus User'
            LIMIT 1
        ];
        User customerUser = new User(
            Alias = 'eecust',
            ContactId = customerContact.Id,
            Email = customerContact.Email,
            EmailEncodingKey = 'UTF-8',
            LastName = customerContact.LastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = customerProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'ee-customer-' + uniqueValue + '@example.com',
            CommunityNickname = 'eecustomer' + uniqueValue
        );
        System.runAs(accountOwner) {
            insert customerUser;
        }

        PermissionSet customerAccess = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'EpicEventz_Customer_Access'
            LIMIT 1
        ];
        List<PermissionSetAssignment> assignments =
            new List<PermissionSetAssignment>{
                new PermissionSetAssignment(
                    AssigneeId = customerUser.Id,
                    PermissionSetId = customerAccess.Id
                )
            };
        if (grantSimulator) {
            PermissionSet simulatorAccess = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = 'EpicEventz_Payment_Simulator_Developer'
                LIMIT 1
            ];
            assignments.add(new PermissionSetAssignment(
                AssigneeId = customerUser.Id,
                PermissionSetId = simulatorAccess.Id
            ));
        }
        System.runAs(accountOwner) {
            insert assignments;
        }

        CustomerContext context = new CustomerContext();
        context.userId = customerUser.Id;
        context.contactId = customerContact.Id;
        return context;
    }
}
