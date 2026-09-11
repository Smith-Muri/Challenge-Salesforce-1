@isTest
private class CaseTriggerTest {
  @testSetup
  static void setupData() {
    Database.insert(
      new List<Account>{
        new Account(Name = 'Opted In Account', Email_Communications__c = true),
        new Account(Name = 'Opted Out Account', Email_Communications__c = false)
      },
      AccessLevel.SYSTEM_MODE
    );
  }

  @isTest
  static void testReopenedCaseWithEmailOptIn() {
    Account accountRecord = getAccount('Opted In Account');
    User ownerUser = createOwner('owner1', 'case-owner-1@example.com');
    Case caseRecord = new Case(
      Subject = 'Opt-in case',
      Status = 'New',
      AccountId = accountRecord.Id,
      OwnerId = ownerUser.Id
    );
    insert caseRecord;
    caseRecord.Status = 'Reopened';

    Test.startTest();
    update caseRecord;
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      1,
      invocations,
      'Debe invocarse el envio para una cuenta autorizada.'
    );
    Messaging.SingleEmailMessage email = CaseTriggerHandler.buildNotificationEmail(
      caseRecord,
      null,
      ownerUser
    );
    Assert.areEqual(
      new List<String>{ ownerUser.Email },
      email.getToAddresses()
    );
  }

  @isTest
  static void testEmailBuilderUsesOwnerRecipient() {
    User ownerUser = new User(
      Id = UserInfo.getUserId(),
      Email = 'builder-owner@example.com'
    );
    Case caseRecord = new Case(OwnerId = ownerUser.Id);

    Messaging.SingleEmailMessage email = CaseTriggerHandler.buildNotificationEmail(
      caseRecord,
      null,
      ownerUser
    );

    Assert.isNotNull(
      email,
      'Debe construirse un email para un owner User valido.'
    );
    Assert.areEqual(
      new List<String>{ ownerUser.Email },
      email.getToAddresses()
    );
    Assert.isFalse(
      email.getSaveAsActivity(),
      'El email no debe guardarse como actividad.'
    );
    Assert.areEqual(Label.Case_Reopened_Email_Subject, email.getSubject());
    Assert.areEqual(Label.Case_Reopened_Email_Body, email.getPlainTextBody());
  }

  @isTest
  static void testAlreadyReopenedDoesNotSend() {
    Account accountRecord = getAccount('Opted In Account');
    Case caseRecord = new Case(
      Subject = 'Already reopened',
      Status = 'Reopened',
      AccountId = accountRecord.Id
    );
    insert caseRecord;

    Test.startTest();
    update caseRecord;
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      0,
      invocations,
      'No debe enviarse si el Case ya estaba Reopened.'
    );
  }

  @isTest
  static void testNonReopenedTransitionDoesNotSend() {
    Account accountRecord = getAccount('Opted In Account');
    Case caseRecord = new Case(
      Subject = 'Working case',
      Status = 'New',
      AccountId = accountRecord.Id
    );
    insert caseRecord;
    caseRecord.Status = 'Working';

    Test.startTest();
    update caseRecord;
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      0,
      invocations,
      'No debe enviarse si el estado nuevo no es Reopened.'
    );
  }

  @isTest
  static void testOptOutDoesNotSend() {
    Account accountRecord = getAccount('Opted Out Account');
    Case caseRecord = new Case(
      Subject = 'Opt-out case',
      Status = 'New',
      AccountId = accountRecord.Id
    );
    insert caseRecord;
    caseRecord.Status = 'Reopened';

    Test.startTest();
    update caseRecord;
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      0,
      invocations,
      'No debe enviarse si la cuenta no autoriza comunicaciones.'
    );
  }

  @isTest
  static void testWithoutAccountDoesNotSend() {
    Case caseRecord = new Case(Subject = 'No account case', Status = 'New');
    insert caseRecord;
    caseRecord.Status = 'Reopened';

    Test.startTest();
    update caseRecord;
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      0,
      invocations,
      'No debe enviarse sin una cuenta asociada.'
    );
  }

  @isTest
  static void testQueueOwnerDoesNotSend() {
    Account accountRecord = getAccount('Opted In Account');
    Id queueId;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Group queue = new Group(Name = 'Case Notification Queue', Type = 'Queue');
      insert queue;
      insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Case');
      queueId = queue.Id;
    }

    Case caseRecord = new Case(
      Subject = 'Queue case',
      Status = 'New',
      AccountId = accountRecord.Id,
      OwnerId = queueId
    );
    insert caseRecord;
    caseRecord.Status = 'Reopened';

    Test.startTest();
    update caseRecord;
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      0,
      invocations,
      'Los Queue owners no reciben notificaciones en este challenge.'
    );
  }

  @isTest
  static void testMixedBulkDataSendsOnlyOptedInCases() {
    Account optedIn = getAccount('Opted In Account');
    Account optedOut = getAccount('Opted Out Account');
    User ownerUser = createOwner('bulkown', 'bulk-owner@example.com');
    List<Case> casesToUpdate = new List<Case>();
    for (Integer index = 0; index < 100; index++) {
      casesToUpdate.add(
        new Case(
          Subject = 'Opted-in bulk ' + index,
          Status = 'New',
          AccountId = optedIn.Id,
          OwnerId = ownerUser.Id
        )
      );
      casesToUpdate.add(
        new Case(
          Subject = 'Opted-out bulk ' + index,
          Status = 'New',
          AccountId = optedOut.Id,
          OwnerId = ownerUser.Id
        )
      );
    }
    insert casesToUpdate;

    for (Case caseRecord : casesToUpdate) {
      caseRecord.Status = 'Reopened';
    }

    Test.startTest();
    update casesToUpdate;
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      1,
      invocations,
      'El envio bulk debe usar una sola invocacion.'
    );
  }

  @isTest
  static void testMultipleOwnersReceiveTheirOwnMessages() {
    Account accountRecord = getAccount('Opted In Account');
    User firstOwner = createOwner('owner1', 'case-owner-1@example.com');
    User secondOwner = createOwner('owner2', 'case-owner-2@example.com');

    List<Case> casesToUpdate = new List<Case>{
      new Case(
        Subject = 'First owner case',
        Status = 'New',
        AccountId = accountRecord.Id,
        OwnerId = firstOwner.Id
      ),
      new Case(
        Subject = 'Second owner case',
        Status = 'New',
        AccountId = accountRecord.Id,
        OwnerId = secondOwner.Id
      )
    };
    insert casesToUpdate;
    for (Case caseRecord : casesToUpdate) {
      caseRecord.Status = 'Reopened';
    }

    Test.startTest();
    update casesToUpdate;
    Test.stopTest();

    Messaging.SingleEmailMessage firstEmail = CaseTriggerHandler.buildNotificationEmail(
      casesToUpdate[0],
      null,
      firstOwner
    );
    Messaging.SingleEmailMessage secondEmail = CaseTriggerHandler.buildNotificationEmail(
      casesToUpdate[1],
      null,
      secondOwner
    );
    Assert.areEqual(
      new List<String>{ firstOwner.Email },
      firstEmail.getToAddresses()
    );
    Assert.areEqual(
      new List<String>{ secondOwner.Email },
      secondEmail.getToAddresses()
    );
  }

  private static Account getAccount(String accountName) {
    return [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1];
  }

  private static User createOwner(String alias, String email) {
    Profile currentProfile = [
      SELECT Id
      FROM Profile
      WHERE Id = :UserInfo.getProfileId()
    ];
    User ownerUser = new User(
      Alias = alias,
      Email = email,
      EmailEncodingKey = 'UTF-8',
      LastName = 'Case Owner',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = currentProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = alias + '-' + DateTime.now().getTime() + '@example.com'
    );
    insert ownerUser;
    return ownerUser;
  }
}
