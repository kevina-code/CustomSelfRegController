/**
 * Author: Kevin Antonioli
 * Created: 03.15.2022
 *
 * Description: provides apex unit test coverage for apex class CustomSelfRegController.cls
 */
@isTest
public class CustomSelfRegControllerTest {
  @isTest
  static void test_createUser() {
    Account accRecord = new account();
    accRecord.Name = 'Test Acc1114';
    insert accRecord;

    Account accRecord2 = new account();
    accRecord2.Name = 'Test Acc2';
    insert accRecord2;

    contact conRecord = new contact();
    conRecord.AccountId = accRecord.id;
    conrecord.lastname = 'TestCon1114';
    insert conRecord;

    AccountContactRelation acr = new AccountContactRelation();
    acr.Accountid = accRecord2.id;
    acr.Contactid = conRecord.id;
    insert acr;

    String personAcctRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
      .get('Person Account')
      .getRecordTypeId();
    Account thePersonAccount = new Account(Id = accRecord.Id);
    thePersonAccount.recordTypeId = personAcctRecordTypeId;
    update thePersonAccount;

    Profile portalProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Your Portal Profile Name Here'
    ];

    Schema.DescribeFieldResult userNameDescribe = User.UserName.getDescribe();
    Schema.SObjectField userNameField = userNameDescribe.getSObjectField();

    Schema.DescribeFieldResult emailDescribe = User.Email.getDescribe();
    Schema.SObjectField emailField = emailDescribe.getSObjectField();

    String uniqueUserName =
      'standarduser' +
      DateTime.now().getTime() +
      '@testorg.com';
    Map<SObjectField, String> fieldMap = new Map<SObjectField, String>();
    fieldMap.put(userNameField, uniqueUserName);
    fieldMap.put(emailField, 'test+Todd@testorg.com');

    Test.startTest();
    CustomSelfRegController CustomSelfRegController = new CustomSelfRegController();
    CustomSelfRegController.createUser(
      thePersonAccount.Id,
      portalProfile.Id,
      fieldMap,
      'Password123!'
    );
    Test.stopTest();
  }

  @isTest
  static void test_NoContactFoundException() {
    String userEmail = 'test+Todd@testorg.com';
    Account account = new Account(Name = 'Todd Hamilton');
    Profile portalProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Your Portal Profile Name Here'
    ];

    Schema.DescribeFieldResult userNameDescribe = User.UserName.getDescribe();
    Schema.SObjectField userNameField = userNameDescribe.getSObjectField();

    Schema.DescribeFieldResult emailDescribe = User.Email.getDescribe();
    Schema.SObjectField emailField = emailDescribe.getSObjectField();

    String uniqueUserName =
      'standarduser' +
      DateTime.now().getTime() +
      '@testorg.com';
    Map<SObjectField, String> fieldMap = new Map<SObjectField, String>();
    fieldMap.put(userNameField, uniqueUserName);
    fieldMap.put(emailField, 'test+Todd@testorg.com');

    Test.startTest();
    CustomSelfRegController CustomSelfRegController = new CustomSelfRegController();
    try {
      CustomSelfRegController.createUser(
        account.Id,
        portalProfile.Id,
        fieldMap,
        'Password123!'
      );
    } catch (Exception e) {
      System.debug(e);
      System.assertEquals(
        e.getMessage().contains('Unable to find associated Contact record'),
        true
      );
    }
    Test.stopTest();
  }

  @isTest
  static void test_DuplicateUserException() {
    Account accRecord = new account();
    accRecord.Name = 'Test Acc1114';
    insert accRecord;

    Account accRecord2 = new account();
    accRecord2.Name = 'Test Acc2';
    insert accRecord2;

    contact conRecord = new contact();
    conRecord.AccountId = accRecord.id;
    conrecord.lastname = 'TestCon1114';
    insert conRecord;

    AccountContactRelation acr = new AccountContactRelation();
    acr.Accountid = accRecord2.id;
    acr.Contactid = conRecord.id;
    insert acr;

    String personAcctRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
      .get('Person Account')
      .getRecordTypeId();
    Account thePersonAccount = new Account(Id = accRecord.Id);
    thePersonAccount.recordTypeId = personAcctRecordTypeId;
    update thePersonAccount;

    Profile portalProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Your Portal Profile Name Here'
    ];

    Schema.DescribeFieldResult userNameDescribe = User.UserName.getDescribe();
    Schema.SObjectField userNameField = userNameDescribe.getSObjectField();

    Schema.DescribeFieldResult emailDescribe = User.Email.getDescribe();
    Schema.SObjectField emailField = emailDescribe.getSObjectField();

    String uniqueUserName =
      'standarduser' +
      DateTime.now().getTime() +
      '@testorg.com';
    Map<SObjectField, String> fieldMap = new Map<SObjectField, String>();
    fieldMap.put(userNameField, uniqueUserName);
    fieldMap.put(emailField, 'test+Todd@testorg.com');

    User u = new User();
    u.Username = uniqueUserName;
    u.lastName = 'Todd';
    u.Alias = 'Hamilton';
    u.ProfileId = portalProfile.id;
    u.CommunityNickname = 'testu';
    u.Email = 'test+Todd@testorg.com';
    u.contactid = conRecord.id;
    u.languagelocalekey = 'en_US';
    u.localesidkey = 'en_US';
    u.timezonesidkey = 'America/Los_Angeles';
    u.emailencodingkey = 'UTF-8';
    insert u;

    Test.startTest();
    CustomSelfRegController CustomSelfRegController = new CustomSelfRegController();
    try {
      CustomSelfRegController.createUser(
        thePersonAccount.Id,
        portalProfile.Id,
        fieldMap,
        'Password123!'
      );
    } catch (Exception e) {
      System.debug(e);
      System.assertEquals(e.getMessage().contains('User Already Exists'), true);
    }
    Test.stopTest();
  }
}
