public with sharing class CaseTriggerHandler {

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCasesMap) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> ownerIds = new Set<Id>();

        for (Case c : newCases) {
            Case oldCase = oldCasesMap.get(c.Id);
            if (shouldNotify(c, oldCase)) {
                accountIds.add(c.AccountId);
                if (isUserOwner(c.OwnerId)) {
                    ownerIds.add(c.OwnerId);
                }
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> eligibleAccounts = new Map<Id, Account>(
            [SELECT Id FROM Account WHERE Id IN :accountIds AND Email_Communications__c = true WITH USER_MODE]
        );

        if (eligibleAccounts.isEmpty()) {
            return;
        }

        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'Case_Reopened_Notification'
            LIMIT 1
        ];

        Id templateId;
        if (!templates.isEmpty()) {
            templateId = templates[0].Id;
        }

        Map<Id, User> ownerUsers = new Map<Id, User>();
        if (!ownerIds.isEmpty()) {
            ownerUsers = new Map<Id, User>([
                SELECT Id, Email
                FROM User
                WHERE Id IN :ownerIds
            ]);
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (Case c : newCases) {
            Case oldCase = oldCasesMap.get(c.Id);
            if (shouldNotify(c, oldCase) && eligibleAccounts.containsKey(c.AccountId)) {
                Messaging.SingleEmailMessage email;

                if (templateId != null && isUserOwner(c.OwnerId)) {
                    email = Messaging.renderStoredEmailTemplate(templateId, c.OwnerId, c.Id);
                } else {
                    String recipientEmail = UserInfo.getUserEmail();
                    User ownerUser = ownerUsers.get(c.OwnerId);
                    if (ownerUser != null && !String.isBlank(ownerUser.Email)) {
                        recipientEmail = ownerUser.Email;
                    }

                    if (String.isBlank(recipientEmail)) {
                        continue;
                    }

                    email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new List<String>{ recipientEmail });
                    email.setSubject(Label.Case_Reopened_Email_Subject);
                    email.setPlainTextBody(Label.Case_Reopened_Email_Body);
                }

                email.setSaveAsActivity(false);
                emailsToSend.add(email);
            }
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }

    @TestVisible
    private static Boolean shouldNotify(Case newCase, Case oldCase) {
        return newCase != null && oldCase != null && newCase.Status == 'Reopened' &&
            oldCase.Status != 'Reopened' && newCase.AccountId != null;
    }

    @TestVisible
    private static Boolean isUserOwner(Id ownerId) {
        return ownerId != null && ownerId.getSObjectType() == User.sObjectType;
    }
}