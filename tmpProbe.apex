Account a = new Account(Name='Probe', Email_Communications__c=true);
insert a;
Case c = new Case(Subject='Probe', Status='New', AccountId=a.Id);
insert c;
Case q = [SELECT Id, OwnerId, AccountId, Status FROM Case WHERE Id = :c.Id LIMIT 1];
System.debug('ownerId=' + q.OwnerId);
System.debug('ownerType=' + String.valueOf(q.OwnerId).substring(0,3));
System.debug('userEmail=' + UserInfo.getUserEmail());
System.debug('ownerUserEmail=' + [SELECT Email FROM User WHERE Id = :q.OwnerId LIMIT 1].Email);
