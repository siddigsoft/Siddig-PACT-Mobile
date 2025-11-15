import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'PACT Mobile'**
  String get appTitle;

  /// Title for the available tasks screen
  ///
  /// In en, this message translates to:
  /// **'Available Tasks'**
  String get availableTasks;

  /// Title for the field operations screen
  ///
  /// In en, this message translates to:
  /// **'Field Operations'**
  String get fieldOperations;

  /// Subtitle showing number of tasks in area
  ///
  /// In en, this message translates to:
  /// **'{count} tasks in your area'**
  String tasksInArea(int count);

  /// Button text for accepting a task
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Button text for declining a task
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// Message when no tasks are available
  ///
  /// In en, this message translates to:
  /// **'No tasks available'**
  String get noTasksAvailable;

  /// Message encouraging user to check back later
  ///
  /// In en, this message translates to:
  /// **'Check back later for new tasks in your area'**
  String get checkBackLater;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Register button text
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Phone number field label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Welcome back message
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// Sign in prompt
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// Create account title
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Button to show map view
  ///
  /// In en, this message translates to:
  /// **'Show Map'**
  String get showMap;

  /// Button to show tasks view
  ///
  /// In en, this message translates to:
  /// **'Show Tasks'**
  String get showTasks;

  /// Refresh button text
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Menu button text
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Settings menu item
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Arabic language name
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// High priority label
  ///
  /// In en, this message translates to:
  /// **'HIGH'**
  String get high;

  /// Medium priority label
  ///
  /// In en, this message translates to:
  /// **'MEDIUM'**
  String get medium;

  /// Low priority label
  ///
  /// In en, this message translates to:
  /// **'LOW'**
  String get low;

  /// Due date prefix
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// Distance suffix
  ///
  /// In en, this message translates to:
  /// **'km away'**
  String get kmAway;

  /// Home navigation tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Forms navigation tab
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get forms;

  /// Equipment screen title
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// Safety navigation tab
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// Chat screen title
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Prompt to register
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Prompt to login
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign up button text
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Pact Consultancy account'**
  String get signInToAccount;

  /// Sign in button text in caps
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signInCaps;

  /// Create account button text in caps
  ///
  /// In en, this message translates to:
  /// **'CREATE ACCOUNT'**
  String get createAccountCaps;

  /// Section title for MMP files
  ///
  /// In en, this message translates to:
  /// **'MMP Files'**
  String get mmpFiles;

  /// Message when user needs to log in to view MMP files
  ///
  /// In en, this message translates to:
  /// **'Please log in to view MMP files'**
  String get pleaseLogInToViewMMPFiles;

  /// Log in button text
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// Message when no MMP files are available
  ///
  /// In en, this message translates to:
  /// **'No MMP files available'**
  String get noMMPFilesAvailable;

  /// Error message when file URL is not available
  ///
  /// In en, this message translates to:
  /// **'No file URL available'**
  String get noFileUrlAvailable;

  /// Error message when file cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open file'**
  String get couldNotOpenFile;

  /// Error message for invalid URL format
  ///
  /// In en, this message translates to:
  /// **'Invalid file URL format'**
  String get invalidFileUrlFormat;

  /// Error message when accessing file URL fails
  ///
  /// In en, this message translates to:
  /// **'Error accessing file URL'**
  String get errorAccessingFileUrl;

  /// Dismiss button text for snackbar
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Dialog title for adding new equipment
  ///
  /// In en, this message translates to:
  /// **'Add New Equipment'**
  String get addNewEquipment;

  /// Equipment name field label
  ///
  /// In en, this message translates to:
  /// **'Equipment Name'**
  String get equipmentName;

  /// Equipment name field hint
  ///
  /// In en, this message translates to:
  /// **'Enter equipment name'**
  String get enterEquipmentName;

  /// Status field label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Next maintenance date field label
  ///
  /// In en, this message translates to:
  /// **'Next Maintenance Date'**
  String get nextMaintenanceDate;

  /// Date format hint
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get yyyyMmDd;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Add button text
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Inspection form dialog title
  ///
  /// In en, this message translates to:
  /// **'Inspection Form'**
  String get inspectionForm;

  /// Condition field label
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// Condition field hint
  ///
  /// In en, this message translates to:
  /// **'Enter current condition'**
  String get enterCurrentCondition;

  /// Concerns field label
  ///
  /// In en, this message translates to:
  /// **'Concerns'**
  String get concerns;

  /// Concerns field hint
  ///
  /// In en, this message translates to:
  /// **'Enter any concerns'**
  String get enterAnyConcerns;

  /// Recommendations field label
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// Recommendations field hint
  ///
  /// In en, this message translates to:
  /// **'Enter recommendations'**
  String get enterRecommendations;

  /// Submit button text
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Filter equipment bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Filter Equipment'**
  String get filterEquipment;

  /// Search equipment dialog title
  ///
  /// In en, this message translates to:
  /// **'Search Equipment'**
  String get searchEquipment;

  /// Search equipment field hint
  ///
  /// In en, this message translates to:
  /// **'Enter equipment name'**
  String get enterEquipmentNameSearch;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// All filter option
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Available filter option
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// In Use filter option
  ///
  /// In en, this message translates to:
  /// **'In Use'**
  String get inUse;

  /// Needs Maintenance filter option
  ///
  /// In en, this message translates to:
  /// **'Needs Maintenance'**
  String get needsMaintenance;

  /// Empty state message for no equipment
  ///
  /// In en, this message translates to:
  /// **'No equipment found'**
  String get noEquipmentFound;

  /// Empty state instruction for adding equipment
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add equipment'**
  String get tapPlusButtonToAddEquipment;

  /// Next prefix for maintenance date
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Checked-in status text
  ///
  /// In en, this message translates to:
  /// **'Checked-in'**
  String get checkedIn;

  /// Checked-out status text
  ///
  /// In en, this message translates to:
  /// **'Checked-out'**
  String get checkedOut;

  /// Next maintenance label
  ///
  /// In en, this message translates to:
  /// **'Next Maintenance'**
  String get nextMaintenance;

  /// Safety hub screen title
  ///
  /// In en, this message translates to:
  /// **'Safety Hub'**
  String get safetyHub;

  /// Information tooltip
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// Quick access section title
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quickAccess;

  /// Comprehensive monitoring item title
  ///
  /// In en, this message translates to:
  /// **'Comprehensive Monitoring'**
  String get safetyChecklist;

  /// Incident report item title
  ///
  /// In en, this message translates to:
  /// **'Incident Report'**
  String get incidentReport;

  /// Report incident dialog title
  ///
  /// In en, this message translates to:
  /// **'Report Incident'**
  String get reportIncident;

  /// Regional helplines item title
  ///
  /// In en, this message translates to:
  /// **'Regional Helplines'**
  String get regionalHelplines;

  /// Safety tip of the day title
  ///
  /// In en, this message translates to:
  /// **'Safety Tip of the Day'**
  String get safetyTipOfTheDay;

  /// Safety tip content about ladder inspection
  ///
  /// In en, this message translates to:
  /// **'Always inspect your ladder before use. Check for damage, missing parts, and proper functioning of all components.'**
  String get ladderInspectionTip;

  /// View more tips button text
  ///
  /// In en, this message translates to:
  /// **'View More Tips'**
  String get viewMoreTips;

  /// Local police emergency contact
  ///
  /// In en, this message translates to:
  /// **'Local Police:999'**
  String get localPolice;

  /// PACT emergency contact
  ///
  /// In en, this message translates to:
  /// **'PACT Emergency:+256700000000'**
  String get pactEmergency;

  /// Medical emergency contact
  ///
  /// In en, this message translates to:
  /// **'Medical Emergency:911'**
  String get medicalEmergency;

  /// Chat greeting message
  ///
  /// In en, this message translates to:
  /// **'Hi there! How can I help you today?'**
  String get hiHowCanIHelp;

  /// Support sender name
  ///
  /// In en, this message translates to:
  /// **'PACT Support'**
  String get pactSupport;

  /// Sample chat message about equipment
  ///
  /// In en, this message translates to:
  /// **'I need information about equipment maintenance.'**
  String get needEquipmentInfo;

  /// Support response asking for equipment details
  ///
  /// In en, this message translates to:
  /// **'Sure! I can help with that. What specific equipment are you asking about?'**
  String get sureWhatEquipment;

  /// Sample message specifying equipment
  ///
  /// In en, this message translates to:
  /// **'The excavator on site B.'**
  String get excavatorSiteB;

  /// Support response with maintenance information
  ///
  /// In en, this message translates to:
  /// **'I\'ve pulled up the maintenance schedule for that excavator. Its next maintenance is due on September 20. Would you like me to send you the full maintenance details?'**
  String get maintenanceScheduleResponse;

  /// Safety alert title
  ///
  /// In en, this message translates to:
  /// **'Safety Alert'**
  String get safetyAlert;

  /// Weather warning alert content
  ///
  /// In en, this message translates to:
  /// **'Severe weather warning for Site A. All personnel should follow safety protocols and stay informed of updates.'**
  String get weatherWarningSiteA;

  /// Message input hint text
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeAMessage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
