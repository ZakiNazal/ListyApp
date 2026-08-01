/// All user-facing copy for Listy App.
///
/// The Figma file has several frames still in Arabic (the login screen, the
/// confirmation sheet). Per the brief the app ships in English only, so those
/// strings are translated here and nothing renders right-to-left.
abstract final class AppStrings {
  static const appName = 'Listy App';

  // Language screen
  static const chooseLanguage = 'Choose your language';
  static const chooseLanguageBody =
      'Select the language you want to use the app in. You can change this later in Settings.';
  static const arabic = 'Arabic';
  static const english = 'English';

  // Login
  static const signIn = 'Sign in';
  static const signInBody =
      'Please enter your mobile number. We will send you a verification code.';
  static const phoneNumber = 'Phone number';
  static const login = 'Login';

  // OTP
  static const verifyNumber = 'Verify your number';
  static String otpBody(String phone) =>
      'Enter the 6-digit code we sent to $phone.';
  static const verify = 'Verify';
  static const resendCode = 'Resend code';
  static String resendIn(int seconds) => 'Resend code in ${seconds}s';
  static const changeNumber = 'Change number';

  // Home
  static const home = 'Home';
  static const numberOfLists = 'Number of Lists';
  static const numberOfItems = 'Number of Items';
  static const request = 'Request';
  static const profile = 'Profile';

  // Request
  static const listName = 'List Name';
  static const chooseYourUser = 'Choose your user';
  static const select = 'Select';
  static const itemName = 'Item name';
  static String itemNameNumbered(int n) => 'Item name $n';
  static const typeHere = 'Type here';
  static const addItem = 'Add item';
  static const send = 'Send';

  // Select user sheet
  static const selectUser = 'Select user';
  static const invite = 'Invite';
  static const searchContacts = 'Search contacts';
  static const onListy = 'On Listy';
  static const inviteToListy = 'Invite to Listy';
  static const noContacts = 'No contacts found.';
  static const contactsPermissionTitle = 'Contacts access needed';
  static const contactsPermissionBody =
      'Listy uses your contacts to show which of your friends already use the app. '
      'Your contacts are only matched on this device and are never uploaded.';
  static const grantAccess = 'Allow access';
  static const openSettings = 'Open Settings';
  static String inviteMessage(String name) =>
      'Hi $name, join me on Listy App so we can share lists together.';
  static const cannotOpenMessages =
      'Could not open your messaging app. Please invite them manually.';

  // Item lists
  static const itemLists = 'Item Lists';
  static String itemCount(int n) => n == 1 ? '(1 Item)' : '($n Items)';
  static const noLists = 'You have no lists yet.';
  static const noItems = 'This list has no items.';
  static const listGone = 'This list is no longer available.';
  static const deleteList = 'Delete list';
  static const deleteListBody =
      'This removes the list for both of you. It cannot be undone.';
  static const delete = 'Delete';
  static String sentTo(String name) => 'Sent to $name';
  static String receivedFrom(String name) => 'From $name';
  static String doneOf(int done, int total) => '$done of $total done';

  // Home navigation (frames 1:2986 / 1:2928)
  static const upcomingLists = 'Upcoming Lists';
  static const invitedFriends = 'Invited Friends';
  static const noUpcoming = 'Nothing waiting on you.';
  static const noInvites = 'You have not invited anyone yet.';
  static const cancelInvite = 'Cancel';
  static const joined = 'Joined';
  static const users = 'Users';

  // Success sheet
  static const requestSentTitle = 'Your request was sent successfully!';
  static const requestSentBody =
      'The assigned user will get back to you shortly.';

  static const listSentTitle = 'List sent successfully!';
  static String listSentBody(String name) =>
      '$name can see it now and will tick items off as they go.';

  static const inviteSentTitle = 'Invitation ready to send!';
  // Deliberately not "Invitation sent": the OS never reports whether the
  // message was actually dispatched, only that the composer opened.
  static String inviteSentBody(String name) =>
      'We opened your messages app with an invite for $name. They will appear '
      'under Invited Friends once they join.';

  static const cancel = 'Cancel';
  static const done = 'Done';

  // Drawer
  static const myLists = 'My Lists';
  static const requests = 'Requests';
  static const notifications = 'Notifications';
  static const settingsSection = 'SETTINGS';
  static const aboutUs = 'About Us';
  static const contactUs = 'Contact Us';
  static const settings = 'Settings';
  static const logOut = 'Log Out';

  // Errors
  static const genericError = 'Something went wrong. Please try again.';
  static const invalidPhone = 'Please enter a valid phone number.';
  static const invalidPhoneSignIn =
      'Enter your number with its country code, starting with +.';
  static const invalidCode = 'That code is not correct. Please try again.';
  static const listNameRequired = 'Please enter a list name.';
  static const userRequired = 'Please choose a user.';
  static const itemRequired = 'Please add at least one item.';
}
