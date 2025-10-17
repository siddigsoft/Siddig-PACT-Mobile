import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    String jsonString = await rootBundle.loadString(
        'lib/l10n/app_${locale.languageCode}.arb');
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // Getters for commonly used strings
  String get appTitle => translate('appTitle');
  String get availableTasks => translate('availableTasks');
  String get fieldOperations => translate('fieldOperations');
  String get accept => translate('accept');
  String get decline => translate('decline');
  String get noTasksAvailable => translate('noTasksAvailable');
  String get checkBackLater => translate('checkBackLater');
  String get login => translate('login');
  String get register => translate('register');
  String get email => translate('email');
  String get password => translate('password');
  String get confirmPassword => translate('confirmPassword');
  String get fullName => translate('fullName');
  String get phoneNumber => translate('phoneNumber');
  String get welcome => translate('welcome');
  String get welcomeBack => translate('welcomeBack');
  String get signInToContinue => translate('signInToContinue');
  String get createAccount => translate('createAccount');
  String get showMap => translate('showMap');
  String get showTasks => translate('showTasks');
  String get refresh => translate('refresh');
  String get menu => translate('menu');
  String get logout => translate('logout');
  String get settings => translate('settings');
  String get language => translate('language');
  String get english => translate('english');
  String get arabic => translate('arabic');
  String get high => translate('high');
  String get medium => translate('medium');
  String get low => translate('low');
  String get due => translate('due');
  String get kmAway => translate('kmAway');
  String get home => translate('home');
  String get forms => translate('forms');
  String get equipment => translate('equipment');
  String get safety => translate('safety');
  String get chat => translate('chat');
  String get forgotPassword => translate('forgotPassword');
  String get dontHaveAccount => translate('dontHaveAccount');
  String get alreadyHaveAccount => translate('alreadyHaveAccount');
  String get signIn => translate('signIn');
  String get signUp => translate('signUp');
  String get signInToAccount => translate('signInToAccount');
  String get signInCaps => translate('signInCaps');
  String get createAccountCaps => translate('createAccountCaps');
  String get mmpFiles => translate('mmpFiles');
  String get pleaseLogInToViewMMPFiles => translate('pleaseLogInToViewMMPFiles');
  String get logIn => translate('logIn');
  String get noMMPFilesAvailable => translate('noMMPFilesAvailable');
  String get noFileUrlAvailable => translate('noFileUrlAvailable');
  String get couldNotOpenFile => translate('couldNotOpenFile');
  String get invalidFileUrlFormat => translate('invalidFileUrlFormat');
  String get errorAccessingFileUrl => translate('errorAccessingFileUrl');
  String get dismiss => translate('dismiss');
  String get addNewEquipment => translate('addNewEquipment');
  String get equipmentName => translate('equipmentName');
  String get enterEquipmentName => translate('enterEquipmentName');
  String get status => translate('status');
  String get nextMaintenanceDate => translate('nextMaintenanceDate');
  String get yyyyMmDd => translate('yyyyMmDd');
  String get cancel => translate('cancel');
  String get add => translate('add');
  String get inspectionForm => translate('inspectionForm');
  String get condition => translate('condition');
  String get submit => translate('submit');
  String get safetyChecklist => translate('safetyChecklist');
  String get enterCurrentCondition => translate('enterCurrentCondition');
  String get concerns => translate('concerns');
  String get enterAnyConcerns => translate('enterAnyConcerns');
  String get recommendations => translate('recommendations');
  String get enterRecommendations => translate('enterRecommendations');
  String get filterEquipment => translate('filterEquipment');
  String get searchEquipment => translate('searchEquipment');
  String get enterEquipmentNameSearch => translate('enterEquipmentNameSearch');
  String get close => translate('close');
  String get all => translate('all');
  String get available => translate('available');
  String get inUse => translate('inUse');
  String get needsMaintenance => translate('needsMaintenance');
  String get noEquipmentFound => translate('noEquipmentFound');
  String get tapPlusButtonToAddEquipment => translate('tapPlusButtonToAddEquipment');
  String get next => translate('next');
  String get checkedIn => translate('checkedIn');
  String get checkedOut => translate('checkedOut');
  String get nextMaintenance => translate('nextMaintenance');
  String get safetyHub => translate('safetyHub');
  String get information => translate('information');
  String get quickAccess => translate('quickAccess');
  String get incidentReport => translate('incidentReport');
  String get reportIncident => translate('reportIncident');
  String get regionalHelplines => translate('regionalHelplines');
  String get safetyTipOfTheDay => translate('safetyTipOfTheDay');
  String get ladderInspectionTip => translate('ladderInspectionTip');
  String get viewMoreTips => translate('viewMoreTips');
  String get localPolice => translate('localPolice');
  String get pactEmergency => translate('pactEmergency');
  String get medicalEmergency => translate('medicalEmergency');
  String get hiHowCanIHelp => translate('hiHowCanIHelp');
  String get pactSupport => translate('pactSupport');
  String get needEquipmentInfo => translate('needEquipmentInfo');
  String get sureWhatEquipment => translate('sureWhatEquipment');
  String get excavatorSiteB => translate('excavatorSiteB');
  String get maintenanceScheduleResponse => translate('maintenanceScheduleResponse');
  String get safetyAlert => translate('safetyAlert');
  String get weatherWarningSiteA => translate('weatherWarningSiteA');
  String get typeAMessage => translate('typeAMessage');

  // Helper method for pluralization
  String tasksInArea(int count) {
    return '$count ${translate('tasksInArea')}';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}