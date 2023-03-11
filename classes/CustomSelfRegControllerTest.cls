/**
 * Author: Kevin Antonioli
 * Created: 03.11.2023
 *
 * Description: provides apex unit test coverage for apex class CustomSelfRegController.cls
 *
 * Assumptions:
 *  A custom profile called 'Customer Portal User' has been created
 *  System Admin is assigned a role (or else, the 'portal account owner must have a role' error will occur)
 *  A permission set for the portal has been created
 */
@isTest
public class CustomSelfRegControllerTest {
  private static String PORTAL_PROFILE_NAME = 'Customer Portal User'; // change to your own portal profile name; this one is out-of-box
  @isTest
  static void test_createUser() {
    Account accRecord = new account();
    accRecord.Name = 'ABC Corp Test';
    insert accRecord;

    Account accRecord2 = new account();
    accRecord2.Name = 'XYZ Corp Test';
    insert accRecord2;

    contact conRecord = new contact();
    conRecord.AccountId = accRecord.id;
    conRecord.FirstName = 'Bob';
    conRecord.LastName = 'Portalia';
    conRecord.Email = 'bobtest@portalia.com';
    insert conRecord;

    AccountContactRelation acr = new AccountContactRelation();
    acr.AccountId = accRecord2.id;
    acr.Contactid = conRecord.id;
    insert acr;

    String personAcctRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
      .get('Person Account')
      .getRecordTypeId();
    Account personAccount = new Account(Id = accRecord.Id);
    personAccount.recordTypeId = personAcctRecordTypeId;
    update personAccount;

    Profile portalProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = :PORTAL_PROFILE_NAME
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
    fieldMap.put(emailField, 'bobtest@portalia.com');

    Test.startTest();
    CustomSelfRegController CustomSelfRegController = new CustomSelfRegController();
    CustomSelfRegController.createUser(
      personAccount.Id,
      portalProfile.Id,
      fieldMap,
      'Password123!'
    );
    Test.stopTest();

    List<User> portalUsers = [
      SELECT Id
      FROM User
      WHERE ProfileId = :portalProfile.Id
    ];
    Assert.isTrue(!portalUsers.isEmpty());
  }

  @isTest
  static void test_NoContactFoundException() {
    String userEmail = 'test+Todd@testorg.com';
    Account account = new Account(Name = 'Todd Hamilton');
    Profile portalProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = :PORTAL_PROFILE_NAME
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
      Assert.isTrue(
        e.getMessage().contains('Unable to find associated Contact record')
      );
    }
    Test.stopTest();
  }
}
