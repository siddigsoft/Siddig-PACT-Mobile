// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PACT Mobile';

  @override
  String get availableTasks => 'Available Tasks';

  @override
  String get fieldOperations => 'Field Operations';

  @override
  String tasksInArea(int count) {
    return '$count tasks in your area';
  }

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get noTasksAvailable => 'No tasks available';

  @override
  String get checkBackLater => 'Check back later for new tasks in your area';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get welcome => 'Welcome';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get createAccount => 'Create Account';

  @override
  String get showMap => 'Show Map';

  @override
  String get showTasks => 'Show Tasks';

  @override
  String get refresh => 'Refresh';

  @override
  String get menu => 'Menu';

  @override
  String get logout => 'Logout';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get high => 'HIGH';

  @override
  String get medium => 'MEDIUM';

  @override
  String get low => 'LOW';

  @override
  String get due => 'Due';

  @override
  String get kmAway => 'km away';

  @override
  String get home => 'Home';

  @override
  String get forms => 'Forms';

  @override
  String get equipment => 'Equipment';

  @override
  String get safety => 'Safety';

  @override
  String get chat => 'Chat';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get signInToAccount => 'Sign in to your Pact Consultancy account';

  @override
  String get signInCaps => 'SIGN IN';

  @override
  String get createAccountCaps => 'CREATE ACCOUNT';

  @override
  String get mmpFiles => 'MMP Files';

  @override
  String get pleaseLogInToViewMMPFiles => 'Please log in to view MMP files';

  @override
  String get logIn => 'Log In';

  @override
  String get noMMPFilesAvailable => 'No MMP files available';

  @override
  String get noFileUrlAvailable => 'No file URL available';

  @override
  String get couldNotOpenFile => 'Could not open file';

  @override
  String get invalidFileUrlFormat => 'Invalid file URL format';

  @override
  String get errorAccessingFileUrl => 'Error accessing file URL';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get addNewEquipment => 'Add New Equipment';

  @override
  String get equipmentName => 'Equipment Name';

  @override
  String get enterEquipmentName => 'Enter equipment name';

  @override
  String get status => 'Status';

  @override
  String get nextMaintenanceDate => 'Next Maintenance Date';

  @override
  String get yyyyMmDd => 'YYYY-MM-DD';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get inspectionForm => 'Inspection Form';

  @override
  String get condition => 'Condition';

  @override
  String get enterCurrentCondition => 'Enter current condition';

  @override
  String get concerns => 'Concerns';

  @override
  String get enterAnyConcerns => 'Enter any concerns';

  @override
  String get recommendations => 'Recommendations';

  @override
  String get enterRecommendations => 'Enter recommendations';

  @override
  String get submit => 'Submit';

  @override
  String get filterEquipment => 'Filter Equipment';

  @override
  String get searchEquipment => 'Search Equipment';

  @override
  String get enterEquipmentNameSearch => 'Enter equipment name';

  @override
  String get close => 'Close';

  @override
  String get all => 'All';

  @override
  String get available => 'Available';

  @override
  String get inUse => 'In Use';

  @override
  String get needsMaintenance => 'Needs Maintenance';

  @override
  String get noEquipmentFound => 'No equipment found';

  @override
  String get tapPlusButtonToAddEquipment => 'Tap the + button to add equipment';

  @override
  String get next => 'Next';

  @override
  String get checkedIn => 'Checked-in';

  @override
  String get checkedOut => 'Checked-out';

  @override
  String get nextMaintenance => 'Next Maintenance';

  @override
  String get safetyHub => 'Safety Hub';

  @override
  String get information => 'Information';

  @override
  String get quickAccess => 'Quick Access';

  @override
  String get safetyChecklist => 'Comprehensive Monitoring';

  @override
  String get incidentReport => 'Incident Report';

  @override
  String get reportIncident => 'Report Incident';

  @override
  String get regionalHelplines => 'Regional Helplines';

  @override
  String get safetyTipOfTheDay => 'Safety Tip of the Day';

  @override
  String get ladderInspectionTip => 'Always inspect your ladder before use. Check for damage, missing parts, and proper functioning of all components.';

  @override
  String get viewMoreTips => 'View More Tips';

  @override
  String get localPolice => 'Local Police:999';

  @override
  String get pactEmergency => 'PACT Emergency:+256700000000';

  @override
  String get medicalEmergency => 'Medical Emergency:911';

  @override
  String get hiHowCanIHelp => 'Hi there! How can I help you today?';

  @override
  String get pactSupport => 'PACT Support';

  @override
  String get needEquipmentInfo => 'I need information about equipment maintenance.';

  @override
  String get sureWhatEquipment => 'Sure! I can help with that. What specific equipment are you asking about?';

  @override
  String get excavatorSiteB => 'The excavator on site B.';

  @override
  String get maintenanceScheduleResponse => 'I\'ve pulled up the maintenance schedule for that excavator. Its next maintenance is due on September 20. Would you like me to send you the full maintenance details?';

  @override
  String get safetyAlert => 'Safety Alert';

  @override
  String get weatherWarningSiteA => 'Severe weather warning for Site A. All personnel should follow safety protocols and stay informed of updates.';

  @override
  String get typeAMessage => 'Type a message...';
}
