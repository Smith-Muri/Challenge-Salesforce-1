public with sharing class CaseTriggerHandler {
  private static final String STATUS_REOPENED = 'Reopened';
  private static final String EMAIL_TEMPLATE_DEVELOPER_NAME = 'Case_Reopened_Notification';

  public static void handleAfterUpdate(
    List<Case> newCases,
    Map<Id, Case> oldCasesMap
  ) {
    List<Case> casesToNotify = new List<Case>();
    Set<Id> accountIds = new Set<Id>();
    Set<Id> ownerIds = new Set<Id>();

    for (Case caseRecord : newCases) {
      Case oldCase = oldCasesMap.get(caseRecord.Id);
      if (shouldNotify(caseRecord, oldCase)) {
        casesToNotify.add(caseRecord);
        accountIds.add(caseRecord.AccountId);
        if (isUserOwner(caseRecord.OwnerId)) {
          ownerIds.add(caseRecord.OwnerId);
        }
      }
    }

    if (casesToNotify.isEmpty()) {
      return;
    }

    Map<Id, Account> eligibleAccounts = new Map<Id, Account>(
      [
        SELECT Id
        FROM Account
        WHERE Id IN :accountIds AND Email_Communications__c = TRUE
        WITH SYSTEM_MODE
      ]
    );

    if (eligibleAccounts.isEmpty()) {
      return;
    }

    Id templateId;
    if (!ownerIds.isEmpty()) {
      List<EmailTemplate> templates = [
        SELECT Id
        FROM EmailTemplate
        WHERE DeveloperName = :EMAIL_TEMPLATE_DEVELOPER_NAME
        LIMIT 1
      ];
      if (!templates.isEmpty()) {
        templateId = templates[0].Id;
      }
    }

    Map<Id, User> ownerUsers = new Map<Id, User>();
    if (!ownerIds.isEmpty()) {
      ownerUsers = new Map<Id, User>(
        [
          SELECT Id, Email
          FROM User
          WHERE Id IN :ownerIds
          WITH USER_MODE
        ]
      );
    }

    Map<Id, Messaging.SingleEmailMessage> emailsByOwner = new Map<Id, Messaging.SingleEmailMessage>();

    for (Case caseRecord : casesToNotify) {
      if (eligibleAccounts.containsKey(caseRecord.AccountId)) {
        User ownerUser = ownerUsers.get(caseRecord.OwnerId);
        if (!emailsByOwner.containsKey(caseRecord.OwnerId)) {
          Messaging.SingleEmailMessage email = buildNotificationEmail(
            caseRecord,
            templateId,
            ownerUser
          );
          if (email != null) {
            emailsByOwner.put(caseRecord.OwnerId, email);
          }
        }
      }
    }

    if (!emailsByOwner.isEmpty()) {
      Messaging.sendEmail(emailsByOwner.values());
    }
  }

  @TestVisible
  private static Boolean shouldNotify(Case newCase, Case oldCase) {
    return newCase != null &&
      oldCase != null &&
      newCase.Status == STATUS_REOPENED &&
      oldCase.Status != STATUS_REOPENED &&
      newCase.AccountId != null;
  }

  @TestVisible
  private static Boolean isUserOwner(Id ownerId) {
    return ownerId != null && ownerId.getSObjectType() == User.sObjectType;
  }

  @TestVisible
  private static Messaging.SingleEmailMessage buildNotificationEmail(
    Case caseRecord,
    Id templateId,
    User ownerUser
  ) {
    if (
      !isUserOwner(caseRecord.OwnerId) ||
      ownerUser == null ||
      String.isBlank(ownerUser.Email)
    ) {
      return null;
    }

    Messaging.SingleEmailMessage email;
    if (templateId != null) {
      email = Messaging.renderStoredEmailTemplate(
        templateId,
        ownerUser.Id,
        caseRecord.Id
      );
      email.setTargetObjectId(ownerUser.Id);
    } else {
      email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ ownerUser.Email });
      email.setSubject(Label.Case_Reopened_Email_Subject);
      email.setPlainTextBody(Label.Case_Reopened_Email_Body);
    }
    email.setSaveAsActivity(false);
    return email;
  }
}
