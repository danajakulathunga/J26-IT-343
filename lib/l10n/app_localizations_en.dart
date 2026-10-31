// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'BananaGuard AI';

  @override
  String get appTagline => 'Intelligent Defect & Disease Diagnostics';

  @override
  String get chooseLanguage => 'Select Your Language';

  @override
  String get continueButton => 'Continue';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get continueAsGuest => 'Use for free / Continue as guest';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get sendOtp => 'Send Verification Code';

  @override
  String get enterOtp => 'Enter 6-digit verification code';

  @override
  String get resendOtp => 'Resend Code';

  @override
  String get newPassword => 'New Password';

  @override
  String get home => 'Home';

  @override
  String get history => 'History';

  @override
  String get notifications => 'Notifications';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get scanBanana => 'Scan a Banana';

  @override
  String get scanBananaSub =>
      'Capture a clear image for automated defect and disease analysis';

  @override
  String get photoTipsTitle => 'Tips for Best Accuracy';

  @override
  String get photoTip1 => 'Hold camera 20-30 cm from fruit';

  @override
  String get photoTip2 => 'Ensure good natural or bright light';

  @override
  String get photoTip3 => 'Avoid severe glare or dark shadows';

  @override
  String get conditionLibrary => 'Condition Library';

  @override
  String get viewAll => 'View All';

  @override
  String get recentScans => 'Recent Scans';

  @override
  String get noRecentScans => 'No recent scans yet';

  @override
  String get startFirstScan => 'Scan your first banana';

  @override
  String get selectVariety => 'Select Banana Variety (Optional)';

  @override
  String get varietyNotSure => 'Not sure / Unspecified';

  @override
  String get takePhoto => 'Take Photo with Camera';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get analyzingTitle => 'Analyzing Banana...';

  @override
  String get analyzingSubtitle =>
      'Running neural detection, severity indexing, and Grad-CAM explainability';

  @override
  String get cancel => 'Cancel';

  @override
  String get resultsTitle => 'Diagnostic Result';

  @override
  String get demoModeBanner => 'Demo mode – model not trained yet';

  @override
  String get detectedCondition => 'Detected Condition';

  @override
  String get conditionConfidence => 'Condition Confidence';

  @override
  String get severityLevel => 'Severity Level';

  @override
  String get severityScore => 'Severity Score';

  @override
  String get severityIndex => 'Severity Index';

  @override
  String get noDefectOrDisease => 'No defect or disease detected';

  @override
  String get causeFactors => 'Primary Cause Factors';

  @override
  String get recommendations => 'Action Recommendations';

  @override
  String get gradcamExplanation =>
      'Grad-CAM Explanation (Red/Yellow regions influenced the prediction)';

  @override
  String get originalImage => 'Original';

  @override
  String get highlightedImage => 'Highlighted';

  @override
  String get downloadReport => 'Download PDF Report';

  @override
  String get downloadingReport => 'Generating and downloading PDF report...';

  @override
  String get reportDownloaded => 'Report downloaded successfully!';

  @override
  String get open => 'Open';

  @override
  String get share => 'Share';

  @override
  String get scanAgain => 'Scan Another';

  @override
  String get topPredictions => 'Alternative Predictions';

  @override
  String get qualityWarnings => 'Image Quality Advisory';

  @override
  String get lowConfidenceWarning => 'Low confidence – retake a clearer photo';

  @override
  String get disclaimerText =>
      'Decision-support information only. Consult an agricultural expert before applying treatments.';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System Default';

  @override
  String get lightTheme => 'Light Mode';

  @override
  String get darkTheme => 'Dark Mode';

  @override
  String get language => 'Language';

  @override
  String get about => 'About BananaGuard AI';

  @override
  String get privacyPolicy => 'Privacy & Data Policy';

  @override
  String get logout => 'Log Out';

  @override
  String get createAccountToSync =>
      'Create an account to sync your history across devices';

  @override
  String get guestUser => 'Guest User';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get allowNotifications => 'Enable Notifications';

  @override
  String get scanResultsNotif => 'Scan Result Alerts';

  @override
  String get inspectionReminders => 'Orchard Inspection Reminders';

  @override
  String get tipsAndUpdates => 'Tips & Agricultural Updates';

  @override
  String get dailyReminderTime => 'Daily Reminder Time';

  @override
  String get markAllAsRead => 'Mark All as Read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get noHistory => 'No scan history recorded';

  @override
  String get searchCondition => 'Search condition...';

  @override
  String get filterAll => 'All';

  @override
  String get filterDiseases => 'Diseases';

  @override
  String get filterDefects => 'Defects';

  @override
  String get filterHealthy => 'Healthy';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDelete => 'Are you sure you want to delete this scan?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get goodNight => 'Good night';
}
