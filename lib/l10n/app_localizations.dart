import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';

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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
    Locale('ta')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'BananaGuard AI'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Intelligent Defect & Disease Diagnostics'**
  String get appTagline;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Your Language'**
  String get chooseLanguage;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Use for free / Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get sendOtp;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit verification code'**
  String get enterOtp;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendOtp;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @scanBanana.
  ///
  /// In en, this message translates to:
  /// **'Scan a Banana'**
  String get scanBanana;

  /// No description provided for @scanBananaSub.
  ///
  /// In en, this message translates to:
  /// **'Capture a clear image for automated defect and disease analysis'**
  String get scanBananaSub;

  /// No description provided for @photoTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips for Best Accuracy'**
  String get photoTipsTitle;

  /// No description provided for @photoTip1.
  ///
  /// In en, this message translates to:
  /// **'Hold camera 20-30 cm from fruit'**
  String get photoTip1;

  /// No description provided for @photoTip2.
  ///
  /// In en, this message translates to:
  /// **'Ensure good natural or bright light'**
  String get photoTip2;

  /// No description provided for @photoTip3.
  ///
  /// In en, this message translates to:
  /// **'Avoid severe glare or dark shadows'**
  String get photoTip3;

  /// No description provided for @conditionLibrary.
  ///
  /// In en, this message translates to:
  /// **'Condition Library'**
  String get conditionLibrary;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @recentScans.
  ///
  /// In en, this message translates to:
  /// **'Recent Scans'**
  String get recentScans;

  /// No description provided for @noRecentScans.
  ///
  /// In en, this message translates to:
  /// **'No recent scans yet'**
  String get noRecentScans;

  /// No description provided for @startFirstScan.
  ///
  /// In en, this message translates to:
  /// **'Scan your first banana'**
  String get startFirstScan;

  /// No description provided for @selectVariety.
  ///
  /// In en, this message translates to:
  /// **'Select Banana Variety (Optional)'**
  String get selectVariety;

  /// No description provided for @varietyNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure / Unspecified'**
  String get varietyNotSure;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo with Camera'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @analyzingTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyzing Banana...'**
  String get analyzingTitle;

  /// No description provided for @analyzingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Running neural detection, severity indexing, and Grad-CAM explainability'**
  String get analyzingSubtitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @resultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Result'**
  String get resultsTitle;

  /// No description provided for @demoModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo mode – model not trained yet'**
  String get demoModeBanner;

  /// No description provided for @detectedCondition.
  ///
  /// In en, this message translates to:
  /// **'Detected Condition'**
  String get detectedCondition;

  /// No description provided for @conditionConfidence.
  ///
  /// In en, this message translates to:
  /// **'Condition Confidence'**
  String get conditionConfidence;

  /// No description provided for @severityLevel.
  ///
  /// In en, this message translates to:
  /// **'Severity Level'**
  String get severityLevel;

  /// No description provided for @severityScore.
  ///
  /// In en, this message translates to:
  /// **'Severity Score'**
  String get severityScore;

  /// No description provided for @severityIndex.
  ///
  /// In en, this message translates to:
  /// **'Severity Index'**
  String get severityIndex;

  /// No description provided for @noDefectOrDisease.
  ///
  /// In en, this message translates to:
  /// **'No defect or disease detected'**
  String get noDefectOrDisease;

  /// No description provided for @causeFactors.
  ///
  /// In en, this message translates to:
  /// **'Primary Cause Factors'**
  String get causeFactors;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Action Recommendations'**
  String get recommendations;

  /// No description provided for @gradcamExplanation.
  ///
  /// In en, this message translates to:
  /// **'Grad-CAM Explanation (Red/Yellow regions influenced the prediction)'**
  String get gradcamExplanation;

  /// No description provided for @originalImage.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get originalImage;

  /// No description provided for @highlightedImage.
  ///
  /// In en, this message translates to:
  /// **'Highlighted'**
  String get highlightedImage;

  /// No description provided for @downloadReport.
  ///
  /// In en, this message translates to:
  /// **'Download PDF Report'**
  String get downloadReport;

  /// No description provided for @downloadingReport.
  ///
  /// In en, this message translates to:
  /// **'Generating and downloading PDF report...'**
  String get downloadingReport;

  /// No description provided for @reportDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Report downloaded successfully!'**
  String get reportDownloaded;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Another'**
  String get scanAgain;

  /// No description provided for @topPredictions.
  ///
  /// In en, this message translates to:
  /// **'Alternative Predictions'**
  String get topPredictions;

  /// No description provided for @qualityWarnings.
  ///
  /// In en, this message translates to:
  /// **'Image Quality Advisory'**
  String get qualityWarnings;

  /// No description provided for @lowConfidenceWarning.
  ///
  /// In en, this message translates to:
  /// **'Low confidence – retake a clearer photo'**
  String get lowConfidenceWarning;

  /// No description provided for @disclaimerText.
  ///
  /// In en, this message translates to:
  /// **'Decision-support information only. Consult an agricultural expert before applying treatments.'**
  String get disclaimerText;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkTheme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About BananaGuard AI'**
  String get about;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data Policy'**
  String get privacyPolicy;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @createAccountToSync.
  ///
  /// In en, this message translates to:
  /// **'Create an account to sync your history across devices'**
  String get createAccountToSync;

  /// No description provided for @guestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guestUser;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @allowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get allowNotifications;

  /// No description provided for @scanResultsNotif.
  ///
  /// In en, this message translates to:
  /// **'Scan Result Alerts'**
  String get scanResultsNotif;

  /// No description provided for @inspectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Orchard Inspection Reminders'**
  String get inspectionReminders;

  /// No description provided for @tipsAndUpdates.
  ///
  /// In en, this message translates to:
  /// **'Tips & Agricultural Updates'**
  String get tipsAndUpdates;

  /// No description provided for @dailyReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder Time'**
  String get dailyReminderTime;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get markAllAsRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No scan history recorded'**
  String get noHistory;

  /// No description provided for @searchCondition.
  ///
  /// In en, this message translates to:
  /// **'Search condition...'**
  String get searchCondition;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterDiseases.
  ///
  /// In en, this message translates to:
  /// **'Diseases'**
  String get filterDiseases;

  /// No description provided for @filterDefects.
  ///
  /// In en, this message translates to:
  /// **'Defects'**
  String get filterDefects;

  /// No description provided for @filterHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get filterHealthy;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this scan?'**
  String get confirmDelete;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @goodNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get goodNight;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
