public with sharing class CaseTriggerHandler {

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCasesMap) {
        Set<Id> caseIdsToProcess = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();

        for (Case c : newCases) {
            Case oldCase = oldCasesMap.get(c.Id);
            if (c.Status == 'Reopened' && oldCase.Status != 'Reopened' && c.AccountId != null) {
                caseIdsToProcess.add(c.Id);
                accountIds.add(c.AccountId);
            }
        }

        if (caseIdsToProcess.isEmpty()) {
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

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        List<Case> casesToNotify = [
            SELECT Id, OwnerId, AccountId
            FROM Case
            WHERE Id IN :caseIdsToProcess
            WITH USER_MODE
        ];

        for (Case c : casesToNotify) {
            if (eligibleAccounts.containsKey(c.AccountId)) {
                Messaging.SingleEmailMessage email;

                if (templateId != null && c.OwnerId != null && String.valueOf(c.OwnerId).startsWith('005')) {
                    email = Messaging.renderStoredEmailTemplate(templateId, c.OwnerId, c.Id);
                } else {
                    String recipientEmail = UserInfo.getUserEmail();
                    if (c.OwnerId != null && String.valueOf(c.OwnerId).startsWith('005')) {
                        List<User> ownerUsers = [
                            SELECT Email
                            FROM User
                            WHERE Id = :c.OwnerId
                            LIMIT 1
                        ];

                        if (!ownerUsers.isEmpty() && !String.isBlank(ownerUsers[0].Email)) {
                            recipientEmail = ownerUsers[0].Email;
                        }
                    }

                    if (String.isBlank(recipientEmail)) {
                        continue;
                    }

                    email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new List<String>{ recipientEmail });
                    email.setSubject('Case Reopened');
                    email.setPlainTextBody('A case has been reopened and requires attention.');
                }

                email.setSaveAsActivity(false);
                emailsToSend.add(email);
            }
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }
}