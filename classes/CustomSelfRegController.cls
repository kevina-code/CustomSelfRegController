/**
 * @description: Portal Self Registration Controller
 *  Runs when someone attempts to self register on a Digital Experience site
 *  in which its config uses this class
 *
 * Created by: Kevin Antonioli : 03.10.2023
 *
 * Revisions:
 * Date : Name : Notes
 */
global class CustomSelfRegController implements Auth.ConfigurableSelfRegHandler {
  private static final String PORTAL_PERMISSIONSET_NAME = 'Portal_Permission_Set_Name'; // change to your portal permission set name

  private final Long CURRENT_TIME = Datetime.now().getTime();
  private final String[] UPPERCASE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    .split('');
  private final String[] LOWERCASE_CHARS = 'abcdefghijklmnopqrstuvwxyz'
    .split('');
  private final String[] NUMBER_CHARS = '1234567890'.split('');
  private final String[] SPECIAL_CHARS = '!#$%-_=+<>'.split('');

  /**
   * @description: called once after user verification in portal (if any was configured)
   *  This method hould create a user and insert it
   *  Password can be null
   *  Return null or throw an exception to fail creation
   * @param accountId (Id)
   * @param profileId (Id)
   * @param registrationAttributes (Map<SObjectField, String)
   * @param password (String)
   */
  global Id createUser(
    Id accountId,
    Id profileId,
    Map<SObjectField, String> registrationAttributes,
    String password
  ) {
    String userEmail = '';

    for (SObjectField field : registrationAttributes.keySet()) {
      if (String.valueOf(field) == 'Email') {
        userEmail = registrationAttributes.get(field);
      }
      String value = registrationAttributes.get(field);
    }
    try {
      List<Contact> contactList = [
        SELECT Id, LastName, FirstName, Email
        FROM Contact
        WHERE Email = :userEmail AND IsPersonAccount = TRUE
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
      if (contactList.isEmpty()) {
        throw new Auth.DiscoveryCustomErrorException(
          'Unable to find associated Contact record associated to ' +
          user.Name +
          '. Please contact your System Admin.'
        );
      } else if (!Test.isRunningTest()) {
        contactList[0].Email = userEmail;
        update contactList;
      }

      User user = new User();
      user.ProfileId = profileId;
      user.contactId = contactList[0].Id;
      user.languagelocalekey = UserInfo.getLocale();
      user.localesidkey = UserInfo.getLocale();
      user.timeZoneSidKey = UserInfo.getTimezone().getID();
      user.emailEncodingKey = 'UTF-8';

      for (SObjectField field : registrationAttributes.keySet()) {
        String value = registrationAttributes.get(field);
        user.put(field, value);
      }

      if (Test.isRunningTest()) {
        password = generateRandomPassword();
      } else {
        if (String.isBlank(password)) {
          password = generateRandomPassword();
        }
        Site.validatePassword(user, password, password);
      }

      handleUnsetRequiredFields(user, contactList[0]);
      insert user;

      if (!Test.isRunningTest()) {
        System.setPassword(user.Id, password);
      }

      // Before assigning permission set, optionally set custom fields parsed by sharing sets, so that the
      //  portal user has read access to the objects they need so data displays properly in the portal
      //  Example: populate a field called Portal_User_ContactId__c on a custom object read by a sharing set

      assignPermissionSet(user.Id);
      return user.id;
    } catch (Exception e) {
      throwExceptions(e);
    }
    return null;
  }

  /**
   * @description: throw exception and show error message to user if they didn't correctly fill out self reg form
   * @param null
   * @return void
   */
  private void throwExceptions(Exception e) {
    string message = e.getMessage();
    string LinkUrl = System.URL.getSalesforceBaseUrl().toExternalForm();
    if (
      message.contains('PORTAL_USER_ALREADY_EXISTS_FOR_CONTACT') ||
      message.contains('DUPLICATE_USERNAME')
    ) {
      String loginPageUrl =
        '<a href="' +
        LinkUrl +
        '/member' +
        '">' +
        'Login Page' +
        '</a>';
      String existingUserMsg =
        'User Already Exists. Go to ' +
        loginPageUrl +
        ' & use your existing credentials. ';
      existingUserMsg += 'Forgot your password? Go to same link & click Forgot your Password.';
      throw new Auth.DiscoveryCustomErrorException(existingUserMsg);
    } else if (
      message.contains(
        'Your password must include letters, numbers and at least one of these special characters'
      )
    ) {
      throw new Auth.DiscoveryCustomErrorException(
        'Your pw isn\'t strong enough. It must contain letters, numbers and a special character.'
      );
    } else if (
      message.contains('Your password must be at least 8 characters long')
    ) {
      throw new Auth.DiscoveryCustomErrorException(message);
    } else if (message.contains('DUPLICATES_DETECTED')) {
      throw new Auth.DiscoveryCustomErrorException(
        'Account already exists, please login or contact us for help.'
      );
    } else if (message != null) {
      throw new Auth.DiscoveryCustomErrorException(
        'Please contact us and give us this error message: ' + e.getMessage()
      );
    }
  }

  /**
   * @description: assign portal permission set to newly created portal user
   *  user that was created upon self registration
   * @param userId (String) : Id of the newly created user that was created during self-registation
   * @return void
   */
  @future
  public static void assignPermissionSet(String userId) {
    String portalPermissionSetId = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :PORTAL_PERMISSIONSET_NAME
    ]
    .Id;
    PermissionSetAssignment psa = new PermissionSetAssignment(
      PermissionSetId = portalPermissionSetId,
      AssigneeId = userId
    );
    insert psa;
  }

  /**
   * @description: Method to autogenerate a password if one was not passed in.
   *  By setting a password for a user, we won't send a welcome email to set the password.
   * @param null
   * @return newPassword (String)
   */
  private String generateRandomPassword() {
    String[] characters = new List<String>(UPPERCASE_CHARS);
    characters.addAll(LOWERCASE_CHARS);
    characters.addAll(NUMBER_CHARS);
    characters.addAll(SPECIAL_CHARS);
    String newPassword = '';
    Boolean needsUpper = true,
      needsLower = true,
      needsNumber = true,
      needsSpecial = true;
    while (newPassword.length() < 50) {
      Integer randomInt = generateRandomInt(characters.size());
      String c = characters[randomInt];
      if (needsUpper && c.isAllUpperCase()) {
        needsUpper = false;
      } else if (needsLower && c.isAllLowerCase()) {
        needsLower = false;
      } else if (needsNumber && c.isNumeric()) {
        needsNumber = false;
      } else if (needsSpecial && !c.isAlphanumeric()) {
        needsSpecial = false;
      }
      newPassword += c;
    }
    newPassword = addMissingPasswordRequirements(
      newPassword,
      needsLower,
      needsUpper,
      needsNumber,
      needsSpecial
    );
    return newPassword;
  }

  /**
   * @description: TODO: fill out missing java doc information
   * @param password (String) :
   * @param addLowerCase (Boolean) :
   * @param addUpperCase (Boolean) :
   * @param addNumber (Boolean) :
   * @param addSpecial (Boolean) :
   * @return password (String) :
   */
  private String addMissingPasswordRequirements(
    String password,
    Boolean addLowerCase,
    Boolean addUpperCase,
    Boolean addNumber,
    Boolean addSpecial
  ) {
    if (addLowerCase) {
      password += LOWERCASE_CHARS[generateRandomInt(LOWERCASE_CHARS.size())];
    }
    if (addUpperCase) {
      password += UPPERCASE_CHARS[generateRandomInt(UPPERCASE_CHARS.size())];
    }
    if (addNumber) {
      password += NUMBER_CHARS[generateRandomInt(NUMBER_CHARS.size())];
    }
    if (addSpecial) {
      password += SPECIAL_CHARS[generateRandomInt(SPECIAL_CHARS.size())];
    }
    return password;
  }

  /**
   * @description: generates a random number from 0 up to, but not including, max.
   * @param max (Integer)
   * @return Integer
   */
  private Integer generateRandomInt(Integer max) {
    return Math.mod(Math.abs(Crypto.getRandomInteger()), max);
  }

  /**
   * @description: Loops over required fields that were not passed in to set to some default value
   * @param user (User)
   * @param contact (Contact)
   * @return user (User)
   */
  private User handleUnsetRequiredFields(User user, Contact contact) {
    if (String.isBlank(user.LastName)) {
      user.LastName = contact.LastName;
    }
    if (String.isBlank(user.FirstName)) {
      user.FirstName = contact.FirstName;
    }
    if (String.isBlank(user.Username)) {
      user.Username = generateUsername();
    }
    if (String.isBlank(user.Email)) {
      user.Email = generateEmail();
    }
    if (String.isBlank(user.Alias)) {
      user.Alias = generateAlias();
    }
    if (String.isBlank(user.CommunityNickname)) {
      user.CommunityNickname = generateCommunityNickname();
    }
    return user;
  }

  /**
   * @description: Method to construct a contact for a user
   * @param user (User)
   * @param accountId (Id)
   * @return void
   */
  private void generateContact(User user, Id accountId) {
    // Add logic here if you want to build your own contact for the user
  }

  /**
   * @description: Default implementation to try to provide uniqueness
   * @param null
   * @return String
   */
  private String generateAlias() {
    String timeString = String.valueOf(CURRENT_TIME);
    return timeString.substring(timeString.length() - 8);
  }

  /**
   * @description: Default implementation to try to provide uniqueness
   * @param null
   * @return String
   */
  private String generateLastName() {
    return 'ExternalUser' + CURRENT_TIME;
  }

  /**
   * @description: Default implementation to try to provide uniqueness
   * @param null
   * @return String
   */
  private String generateUsername() {
    return 'externaluser' + CURRENT_TIME + '@company.com';
  }

  /**
   * @description: Default implementation to try to provide uniqueness
   * @param null
   * @return String
   */
  private String generateEmail() {
    return 'externaluser' + CURRENT_TIME + '@company.com';
  }

  /**
   * @description: Default implementation to try to provide uniqueness
   * @param null
   * @return String
   */
  private String generateCommunityNickname() {
    return 'ExternalUser' + CURRENT_TIME;
  }
}
