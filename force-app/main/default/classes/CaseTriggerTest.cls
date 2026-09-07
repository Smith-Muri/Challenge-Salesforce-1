@isTest
private class CaseTriggerTest {

    @isTest(SeeAllData=true)
    static void testReopenedCaseWithEmailOptIn() {
        Account accOptedIn = new Account(Name = 'Opted In Account', Email_Communications__c = true);
        insert accOptedIn;

        Case c = new Case(Subject = 'Test Case 1', Status = 'New', AccountId = accOptedIn.Id);
        insert c;

        c.Status = 'Reopened';

        Test.startTest();
        update c;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, invocations, 'Debe enviarse un correo cuando la cuenta acepta comunicaciones.');
    }

    @isTest
    static void testReopenedCaseWithEmailOptOut() {
        Account accOptedOut = new Account(Name = 'Opted Out Account', Email_Communications__c = false);
        insert accOptedOut;

        Case c = new Case(Subject = 'Test Case 2', Status = 'New', AccountId = accOptedOut.Id);
        insert c;

        c.Status = 'Reopened';

        Test.startTest();
        update c;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(0, invocations, 'No debe enviarse correo si la cuenta no acepta comunicaciones.');
    }

    @isTest
    static void testStatusChangedToOtherStatus() {
        Account accOptedIn = new Account(Name = 'Opted In Account 2', Email_Communications__c = true);
        insert accOptedIn;

        Case c = new Case(Subject = 'Test Case 3', Status = 'New', AccountId = accOptedIn.Id);
        insert c;

        c.Status = 'Working';

        Test.startTest();
        update c;
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(0, invocations, 'No debe enviarse correo si el estado no es Reopened.');
    }
}