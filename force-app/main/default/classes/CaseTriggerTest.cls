@isTest
private class CaseTriggerTest {

    @testSetup
    static void setupData() {
        insert new List<Account>{
            new Account(Name = 'Opted In Account', Email_Communications__c = true),
            new Account(Name = 'Opted Out Account', Email_Communications__c = false)
        };
    }

    @isTest
    static void testReopenedCaseWithEmailOptIn() {
        Account accOptedIn = getAccount('Opted In Account');

        Case c = new Case(Subject = 'Test Case 1', Status = 'New', AccountId = accOptedIn.Id);
        insert c;

        c.Status = 'Reopened';

        Test.startTest();
        update c;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, invocations, 'Debe enviarse un correo cuando la cuenta acepta comunicaciones.');
    }

    @isTest
    static void testReopenedCaseWithEmailOptOut() {
        Account accOptedOut = getAccount('Opted Out Account');

        Case c = new Case(Subject = 'Test Case 2', Status = 'New', AccountId = accOptedOut.Id);
        insert c;

        c.Status = 'Reopened';

        Test.startTest();
        update c;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(0, invocations, 'No debe enviarse correo si la cuenta no acepta comunicaciones.');
    }

    @isTest
    static void testStatusChangedToOtherStatus() {
        Account accOptedIn = getAccount('Opted In Account');

        Case c = new Case(Subject = 'Test Case 3', Status = 'New', AccountId = accOptedIn.Id);
        insert c;

        c.Status = 'Working';

        Test.startTest();
        update c;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(0, invocations, 'No debe enviarse correo si el estado no es Reopened.');
    }

    @isTest
    static void testReopenedCasesInBulk() {
        Account accOptedOut = getAccount('Opted Out Account');
        List<Case> casesToUpdate = new List<Case>();
        for (Integer index = 0; index < 200; index++) {
            casesToUpdate.add(new Case(
                Subject = 'Bulk Case ' + index,
                Status = 'New',
                AccountId = accOptedOut.Id
            ));
        }
        insert casesToUpdate;

        for (Case c : casesToUpdate) {
            c.Status = 'Reopened';
        }

        Test.startTest();
        update casesToUpdate;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(0, invocations, 'El procesamiento bulk no debe enviar correos para cuentas excluidas.');
    }

    @isTest
    static void testReopenedCaseWithoutAccount() {
        Case c = new Case(Subject = 'No Account Case', Status = 'New');
        insert c;
        c.Status = 'Reopened';

        Test.startTest();
        update c;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(0, invocations, 'No debe enviarse correo sin una cuenta asociada.');
    }

    private static Account getAccount(String accountName) {
        return [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1];
    }
}