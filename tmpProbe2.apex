Account a = new Account(Name='Probe2', Email_Communications__c=true);
insert a;
Case c = new Case(Subject='Probe2', Status='New', AccountId=a.Id);
insert c;
c.Status = 'Reopened';
update c;

System.debug('emailInvocationsAfterUpdate=' + Limits.getEmailInvocations());

Account a2 = new Account(Name='Probe3', Email_Communications__c=true);
insert a2;
Case c2 = new Case(Subject='Probe3', Status='New', AccountId=a2.Id);
insert c2;
Case oldCase = [SELECT Id, Status FROM Case WHERE Id = :c2.Id LIMIT 1];
oldCase.Status = 'Reopened';
// just to create a real trigger context for manual input
CaseTriggerHandler.handleAfterUpdate(new List<Case>{ oldCase }, new Map<Id, Case>{ oldCase.Id => new Case(Id=oldCase.Id, Status='New') });
System.debug('emailInvocationsManual=' + Limits.getEmailInvocations());
