import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('kk'),
    Locale('ru'),
  ];

  /// Application name, shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'KORKEM Flow'**
  String get appTitle;

  /// Body of an empty list that a status filter, rather than a search, narrowed to nothing
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter.'**
  String get filterNoResults;

  /// Empties the list of recent search queries offered under the search field
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get actionClearHistory;

  /// Tooltip and screen-reader label for the button that empties the search field
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get actionClearSearch;

  /// Re-fetches a list from the server, offered on an empty list where pull-to-refresh is not discoverable
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// Retries the failed request on an error state
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get actionClearFilter;

  /// No description provided for @actionFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// No description provided for @actionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get actionSelectAll;

  /// Fallback when the backend gives no human-readable message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorGeneric;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server.'**
  String get errorOffline;

  /// Shown after a write is kept in the in-memory outbox because the server could not be reached
  ///
  /// In en, this message translates to:
  /// **'No connection. The command is waiting to be sent.'**
  String get outboxQueued;

  /// Persistent count of writes waiting in the device outbox
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 command waiting to send} other{{count} commands waiting to send}}'**
  String outboxPending(int count);

  /// No description provided for @outboxRetry.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get outboxRetry;

  /// Terminal server refusal received while replaying a queued write
  ///
  /// In en, this message translates to:
  /// **'A queued command was refused: {reason}'**
  String outboxRejected(String reason);

  /// No description provided for @errorNoAccess.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorNoAccess;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errorNotFound;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @emptyGeneric.
  ///
  /// In en, this message translates to:
  /// **'New items will appear here as they are created.'**
  String get emptyGeneric;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches for \"{query}\"'**
  String searchNoResults(String query);

  /// Screen-reader label for a status chip
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String semanticStatus(String status);

  /// No description provided for @navDeals.
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get navDeals;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @tasksOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get tasksOverdue;

  /// No description provided for @tasksToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tasksToday;

  /// No description provided for @tasksUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tasksUpcoming;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open tasks'**
  String get tasksEmpty;

  /// No description provided for @tasksEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Assigned work will appear here.'**
  String get tasksEmptyBody;

  /// No description provided for @taskComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get taskComplete;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get taskCompleted;

  /// Shown when the server refuses a completion after the undo window has closed; reason is the server's own explanation
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the task. {reason}'**
  String taskCompleteFailed(String reason);

  /// Explains whose task this is and who can complete it when assigned to someone else
  ///
  /// In en, this message translates to:
  /// **'Assigned to {assignee}. Can be completed by the assignee or shift supervisor'**
  String taskForeignAssigneeExplanation(String assignee);

  /// Takes back a task completion during the few seconds before it is sent
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @taskProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get taskProduction;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get profileVersion;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @profileServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get profileServer;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get taskPriorityHigh;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to your KORKEM workspace'**
  String get authSubtitle;

  /// No description provided for @authServer.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get authServer;

  /// No description provided for @authServerHint.
  ///
  /// In en, this message translates to:
  /// **'korkem.example.kz'**
  String get authServerHint;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// Screen-reader label and tooltip for the reveal toggle while the password is hidden
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Screen-reader label and tooltip for the reveal toggle while the password is visible
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @authSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this device?'**
  String get authSignOutConfirm;

  /// Body of the sign-out confirmation, naming what it costs to undo
  ///
  /// In en, this message translates to:
  /// **'You will need the server address and your password to sign back in.'**
  String get authSignOutBody;

  /// No description provided for @authFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get authFieldRequired;

  /// No description provided for @authInvalidServer.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid address.'**
  String get authInvalidServer;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get authNoAccount;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get authAlreadyHaveAccount;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a workspace for your furniture business'**
  String get authRegisterSubtitle;

  /// No description provided for @authCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Company / workshop name'**
  String get authCompanyName;

  /// No description provided for @authCompanyNameHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Astana Furniture, IP Marat'**
  String get authCompanyNameHint;

  /// No description provided for @authOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authOwnerName;

  /// No description provided for @authOwnerNameHint.
  ///
  /// In en, this message translates to:
  /// **'First and last name'**
  String get authOwnerNameHint;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authPasswordTooShort;

  /// No description provided for @authCustomServer.
  ///
  /// In en, this message translates to:
  /// **'Server settings'**
  String get authCustomServer;

  /// No description provided for @authHideServer.
  ///
  /// In en, this message translates to:
  /// **'Hide server settings'**
  String get authHideServer;

  /// Title of the first-run claiming wizard
  ///
  /// In en, this message translates to:
  /// **'First run'**
  String get claimTitle;

  /// Subtitle of the first-run claiming wizard
  ///
  /// In en, this message translates to:
  /// **'Create your company and owner account'**
  String get claimSubtitle;

  /// Label for the 16-character node launch code
  ///
  /// In en, this message translates to:
  /// **'Launch code'**
  String get claimCode;

  /// Hint for launch code input
  ///
  /// In en, this message translates to:
  /// **'16 characters from node log'**
  String get claimCodeHint;

  /// Helper text explaining where to find the launch code
  ///
  /// In en, this message translates to:
  /// **'The code is shown in the node terminal on first launch'**
  String get claimCodeHelper;

  /// Label for company name field
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get claimCompany;

  /// Label for owner name field
  ///
  /// In en, this message translates to:
  /// **'Owner name'**
  String get claimOwnerName;

  /// Label for owner email field
  ///
  /// In en, this message translates to:
  /// **'Owner email'**
  String get claimOwnerEmail;

  /// Label for owner password field
  ///
  /// In en, this message translates to:
  /// **'Owner password'**
  String get claimOwnerPassword;

  /// Label for password confirmation field
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get claimConfirmPassword;

  /// Error when password confirmation does not match
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get claimPasswordMismatch;

  /// Label for system language selection
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get claimLanguage;

  /// Button to submit the claim and create company
  ///
  /// In en, this message translates to:
  /// **'Create company'**
  String get claimSubmit;

  /// Error message when node is already claimed
  ///
  /// In en, this message translates to:
  /// **'This node is already claimed. Ask the owner for an invitation'**
  String get claimAlreadyClaimed;

  /// Error message when the launch code is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid code. It is shown in the node log at startup'**
  String get claimCodeRefused;

  /// Banner shown on login screen when node is unclaimed
  ///
  /// In en, this message translates to:
  /// **'This node is waiting for setup. Create a company to become the owner.'**
  String get claimNodeUnconfiguredBanner;

  /// Action button to launch company setup
  ///
  /// In en, this message translates to:
  /// **'Set up company'**
  String get claimSetupCompanyAction;

  /// Russian language choice
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get claimLangRu;

  /// Kazakh language choice
  ///
  /// In en, this message translates to:
  /// **'Kazakh'**
  String get claimLangKk;

  /// English language choice
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get claimLangEn;

  /// Title of the digital administrator stats screen
  ///
  /// In en, this message translates to:
  /// **'Digital administrator'**
  String get adminStatsTitle;

  /// Subtitle describing the purpose of the stats
  ///
  /// In en, this message translates to:
  /// **'Proof of value: results achieved without hiring an administrator'**
  String get adminStatsSubtitle;

  /// Period switcher week option
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get adminStatsPeriodWeek;

  /// Period switcher month option
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get adminStatsPeriodMonth;

  /// Period switcher quarter option
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get adminStatsPeriodQuarter;

  /// Warning label when there are stale unhandled captures
  ///
  /// In en, this message translates to:
  /// **'NEEDS ATTENTION: STALE'**
  String get adminStatsStaleHeroLabel;

  /// Explanation of stale unhandled captures
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture has not been handed over for more than 24 hours} other{{count} captures have not been handed over for more than 24 hours}}'**
  String adminStatsStaleHeroText(int count);

  /// Label when zero captures went stale
  ///
  /// In en, this message translates to:
  /// **'GREAT RESULT'**
  String get adminStatsZeroStaleHeroLabel;

  /// Affirmation that no captures went stale
  ///
  /// In en, this message translates to:
  /// **'Zero captures lost over {days} days'**
  String adminStatsZeroStaleHeroText(int days);

  /// Subtext for zero stale captures
  ///
  /// In en, this message translates to:
  /// **'All recorded captures were handed over on time or completed'**
  String get adminStatsZeroStaleHeroSub;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'Nothing captured yet'**
  String get adminStatsEmptyTitle;

  /// Empty state description
  ///
  /// In en, this message translates to:
  /// **'No customer requests recorded for the selected period. New messages from channels and messengers will appear here.'**
  String get adminStatsEmptyMessage;

  /// Metric label for total caught requests
  ///
  /// In en, this message translates to:
  /// **'Captured requests'**
  String get adminStatsCaught;

  /// Caption for caught requests
  ///
  /// In en, this message translates to:
  /// **'Total recorded by system'**
  String get adminStatsCaughtHelper;

  /// Metric label for requests assigned as task
  ///
  /// In en, this message translates to:
  /// **'Handed over to person'**
  String get adminStatsHandedOver;

  /// Caption for handed over metric
  ///
  /// In en, this message translates to:
  /// **'Tasks created for team'**
  String get adminStatsHandedOverHelper;

  /// Metric label for requests converted to orders
  ///
  /// In en, this message translates to:
  /// **'Converted to orders'**
  String get adminStatsConverted;

  /// Caption for converted metric
  ///
  /// In en, this message translates to:
  /// **'Led to agreement and payment'**
  String get adminStatsConvertedHelper;

  /// Metric label for dismissed captures
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get adminStatsDismissed;

  /// Caption for dismissed metric
  ///
  /// In en, this message translates to:
  /// **'Spam or customer decline'**
  String get adminStatsDismissedHelper;

  /// Metric label for stale captures
  ///
  /// In en, this message translates to:
  /// **'Stale (no task)'**
  String get adminStatsStaleMetric;

  /// Caption for stale metric
  ///
  /// In en, this message translates to:
  /// **'Unassigned for >24h'**
  String get adminStatsStaleMetricHelper;

  /// Section header for decision summary
  ///
  /// In en, this message translates to:
  /// **'Hiring decision summary'**
  String get adminStatsSummaryTitle;

  /// Summary text explaining what the metrics mean
  ///
  /// In en, this message translates to:
  /// **'The system processed {caught} requests. {converted} became orders, {stale} require attention.'**
  String adminStatsSummaryText(int caught, int converted, int stale);

  /// Button to retry loading stats
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminStatsRetry;

  /// Title of the company team screen
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get teamTitle;

  /// Subtitle of the company team screen
  ///
  /// In en, this message translates to:
  /// **'Company employees and their assigned positions'**
  String get teamSubtitle;

  /// Action button to open invitation form
  ///
  /// In en, this message translates to:
  /// **'Invite employee'**
  String get teamInviteButton;

  /// Header of the employee invitation dialog or form
  ///
  /// In en, this message translates to:
  /// **'Invite employee'**
  String get teamInviteTitle;

  /// Instructions for inviting an employee
  ///
  /// In en, this message translates to:
  /// **'Select position and enter email for access'**
  String get teamInviteSubtitle;

  /// Field label for employee email
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get teamEmailLabel;

  /// Hint text for email field
  ///
  /// In en, this message translates to:
  /// **'worker@company.kz'**
  String get teamEmailHint;

  /// Validation error for invalid email
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get teamEmailError;

  /// Field label for employee first name
  ///
  /// In en, this message translates to:
  /// **'Employee name'**
  String get teamFirstNameLabel;

  /// Hint text for first name field
  ///
  /// In en, this message translates to:
  /// **'Aidos'**
  String get teamFirstNameHint;

  /// Field label for position selection
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get teamPositionLabel;

  /// Position label for manager
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get teamPositionManager;

  /// Description for manager position
  ///
  /// In en, this message translates to:
  /// **'Sales department, customers, deals'**
  String get teamPositionManagerDesc;

  /// Position label for warehouse keeper
  ///
  /// In en, this message translates to:
  /// **'Warehouse keeper'**
  String get teamPositionWarehouse;

  /// Description for warehouse position
  ///
  /// In en, this message translates to:
  /// **'Warehouse, inventory, receiving'**
  String get teamPositionWarehouseDesc;

  /// Position label for accountant
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get teamPositionAccountant;

  /// Description for accountant position
  ///
  /// In en, this message translates to:
  /// **'Invoices, payments, financial reports'**
  String get teamPositionAccountantDesc;

  /// Position label for shop floor worker
  ///
  /// In en, this message translates to:
  /// **'Shop floor worker'**
  String get teamPositionShopFloor;

  /// Description for shop floor position
  ///
  /// In en, this message translates to:
  /// **'Machines, work instructions, progress reporting'**
  String get teamPositionShopFloorDesc;

  /// No description provided for @teamPositionMeasurer.
  ///
  /// In en, this message translates to:
  /// **'Surveyor'**
  String get teamPositionMeasurer;

  /// No description provided for @teamPositionMeasurerDesc.
  ///
  /// In en, this message translates to:
  /// **'Visits the client, takes measurements and photos'**
  String get teamPositionMeasurerDesc;

  /// No description provided for @teamPositionDesigner.
  ///
  /// In en, this message translates to:
  /// **'Design engineer'**
  String get teamPositionDesigner;

  /// No description provided for @teamPositionDesignerDesc.
  ///
  /// In en, this message translates to:
  /// **'Drawings, specifications, BAZIS imports'**
  String get teamPositionDesignerDesc;

  /// No description provided for @teamPositionShopManager.
  ///
  /// In en, this message translates to:
  /// **'Shop manager'**
  String get teamPositionShopManager;

  /// No description provided for @teamPositionShopManagerDesc.
  ///
  /// In en, this message translates to:
  /// **'Assigns work and watches the deadlines'**
  String get teamPositionShopManagerDesc;

  /// No description provided for @teamPositionCutter.
  ///
  /// In en, this message translates to:
  /// **'Panel saw operator'**
  String get teamPositionCutter;

  /// No description provided for @teamPositionCutterDesc.
  ///
  /// In en, this message translates to:
  /// **'Cuts board material'**
  String get teamPositionCutterDesc;

  /// No description provided for @teamPositionEdgeBanding.
  ///
  /// In en, this message translates to:
  /// **'Edge bander'**
  String get teamPositionEdgeBanding;

  /// No description provided for @teamPositionEdgeBandingDesc.
  ///
  /// In en, this message translates to:
  /// **'Edge banding machine'**
  String get teamPositionEdgeBandingDesc;

  /// No description provided for @teamPositionCnc.
  ///
  /// In en, this message translates to:
  /// **'CNC operator'**
  String get teamPositionCnc;

  /// No description provided for @teamPositionCncDesc.
  ///
  /// In en, this message translates to:
  /// **'Drilling and routing'**
  String get teamPositionCncDesc;

  /// No description provided for @teamPositionPainter.
  ///
  /// In en, this message translates to:
  /// **'Finisher'**
  String get teamPositionPainter;

  /// No description provided for @teamPositionPainterDesc.
  ///
  /// In en, this message translates to:
  /// **'Painting and coating'**
  String get teamPositionPainterDesc;

  /// No description provided for @teamPositionAssembler.
  ///
  /// In en, this message translates to:
  /// **'Assembler'**
  String get teamPositionAssembler;

  /// No description provided for @teamPositionAssemblerDesc.
  ///
  /// In en, this message translates to:
  /// **'Assembly and packing'**
  String get teamPositionAssemblerDesc;

  /// No description provided for @teamPositionInstaller.
  ///
  /// In en, this message translates to:
  /// **'Installer'**
  String get teamPositionInstaller;

  /// No description provided for @teamPositionInstallerDesc.
  ///
  /// In en, this message translates to:
  /// **'Delivery and installation at the client'**
  String get teamPositionInstallerDesc;

  /// Position label for company owner
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get teamPositionOwner;

  /// Description for company owner position
  ///
  /// In en, this message translates to:
  /// **'Full company management and administration'**
  String get teamPositionOwnerDesc;

  /// Empty state title when no employees are invited yet
  ///
  /// In en, this message translates to:
  /// **'You are alone for now'**
  String get teamEmptyTitle;

  /// Empty state description for team
  ///
  /// In en, this message translates to:
  /// **'Invite shop floor, warehouse, or sales team members to assign tasks and manage production.'**
  String get teamEmptyMessage;

  /// Success message when invitation is sent
  ///
  /// In en, this message translates to:
  /// **'Invitation sent'**
  String get teamInviteSuccess;

  /// Title for invitation success dialog
  ///
  /// In en, this message translates to:
  /// **'Employee invited'**
  String get teamInviteSuccessTitle;

  /// Detailed success message
  ///
  /// In en, this message translates to:
  /// **'Employee {name} added with position \'{position}\''**
  String teamInviteSuccessDetail(String name, String position);

  /// Label for server next step in invitation result
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get teamNextStepTitle;

  /// Notice that invited employee needs password configured
  ///
  /// In en, this message translates to:
  /// **'Password not set'**
  String get teamPasswordNotSet;

  /// Placeholder while loading server positions
  ///
  /// In en, this message translates to:
  /// **'Loading positions...'**
  String get teamPositionsLoading;

  /// Error loading server positions
  ///
  /// In en, this message translates to:
  /// **'Could not load positions list'**
  String get teamPositionsLoadError;

  /// Title when employee lacks permission to invite
  ///
  /// In en, this message translates to:
  /// **'Owner only'**
  String get teamForbiddenTitle;

  /// Message explaining why inviting is disabled for non-owners
  ///
  /// In en, this message translates to:
  /// **'Only the company owner can invite new employees and assign positions.'**
  String get teamForbiddenMessage;

  /// Submit button for invitation form
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get teamSendInvite;

  /// Section header for team members list
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get teamSectionMembers;

  /// Title for changing employee position dialog
  ///
  /// In en, this message translates to:
  /// **'Change Position'**
  String get teamChangePositionTitle;

  /// Action label to open change position dialog
  ///
  /// In en, this message translates to:
  /// **'Change Position'**
  String get teamChangePositionAction;

  /// Button to save changed position
  ///
  /// In en, this message translates to:
  /// **'Save Position'**
  String get teamSavePosition;

  /// Success message when position is changed
  ///
  /// In en, this message translates to:
  /// **'Position for {name} updated to «{position}»'**
  String teamChangePositionSuccess(String name, String position);

  /// Action label to deactivate employee
  ///
  /// In en, this message translates to:
  /// **'Revoke Access'**
  String get teamDeactivateAction;

  /// Title for deactivate confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Revoke Access?'**
  String get teamDeactivateDialogTitle;

  /// Confirmation message for deactivating employee
  ///
  /// In en, this message translates to:
  /// **'Revoke access for {name}? The employee will lose system access and all open sessions will be closed.'**
  String teamDeactivateConfirmMessage(String name);

  /// Confirmation button to deactivate
  ///
  /// In en, this message translates to:
  /// **'Revoke Access'**
  String get teamDeactivateConfirmButton;

  /// Success message with closed sessions count
  ///
  /// In en, this message translates to:
  /// **'Access revoked, sessions closed: {count}'**
  String teamDeactivateSuccess(int count);

  /// Action label to reactivate employee
  ///
  /// In en, this message translates to:
  /// **'Restore Access'**
  String get teamReactivateAction;

  /// Title for reactivate confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Restore Access?'**
  String get teamReactivateDialogTitle;

  /// Confirmation message for reactivating employee
  ///
  /// In en, this message translates to:
  /// **'Restore access for {name}?'**
  String teamReactivateConfirmMessage(String name);

  /// Confirmation button to reactivate
  ///
  /// In en, this message translates to:
  /// **'Restore Access'**
  String get teamReactivateConfirmButton;

  /// Success message when employee access is restored
  ///
  /// In en, this message translates to:
  /// **'Access restored'**
  String get teamReactivateSuccess;

  /// Status badge for deactivated employee
  ///
  /// In en, this message translates to:
  /// **'Access Revoked'**
  String get teamStatusDisabled;

  /// Status badge for active employee
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get teamStatusActive;

  /// Section header for deactivated employees
  ///
  /// In en, this message translates to:
  /// **'Deactivated Employees'**
  String get teamSectionDisabled;

  /// Tooltip or notice when attempting to modify own account
  ///
  /// In en, this message translates to:
  /// **'You cannot change your own position or revoke your own access'**
  String get teamCannotModifySelf;

  /// Settings tile title for team management
  ///
  /// In en, this message translates to:
  /// **'Team and employees'**
  String get settingsTeamTitle;

  /// Settings tile subtitle for team management
  ///
  /// In en, this message translates to:
  /// **'Invite employees and assign positions'**
  String get settingsTeamSubtitle;

  /// Title for company details screen
  ///
  /// In en, this message translates to:
  /// **'Company details'**
  String get companyDetailsTitle;

  /// Subtitle for company details screen
  ///
  /// In en, this message translates to:
  /// **'Address, BIN, and bank details'**
  String get companyDetailsSubtitle;

  /// Settings tile title for warehouses
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get warehousesSettingsTitle;

  /// Settings tile subtitle for warehouses
  ///
  /// In en, this message translates to:
  /// **'Storage locations and shipping warehouse'**
  String get warehousesSettingsSubtitle;

  /// Title for warehouses management screen
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get warehousesTitle;

  /// Subtitle for warehouses management screen
  ///
  /// In en, this message translates to:
  /// **'Storage locations and finished goods shipping warehouse'**
  String get warehousesSubtitle;

  /// Title for warehouse renaming guidance tip
  ///
  /// In en, this message translates to:
  /// **'How to change warehouse name in documents'**
  String get warehousesTipTitle;

  /// Body explaining the 3-step workflow to get desired warehouse name in documents
  ///
  /// In en, this message translates to:
  /// **'ERPNext does not allow renaming warehouses directly. To have a clear name on waybills: create your warehouse with the desired name → set it as shipping default → disable the English Finished Goods.'**
  String get warehousesTipBody;

  /// Section header for active warehouses
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get warehousesSectionActive;

  /// Section header for disabled warehouses
  ///
  /// In en, this message translates to:
  /// **'Disabled Warehouses'**
  String get warehousesSectionDisabled;

  /// Badge for the default shipping warehouse
  ///
  /// In en, this message translates to:
  /// **'Shipping Default'**
  String get warehousesShippingDefaultBadge;

  /// Badge for disabled warehouse
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get warehousesStatusDisabled;

  /// Count of item positions stored in warehouse
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item position} other{{count} item positions}}'**
  String warehousesPositionsCount(int count);

  /// Action to set warehouse as shipping default
  ///
  /// In en, this message translates to:
  /// **'Set as shipping default'**
  String get warehousesActionSetShippingDefault;

  /// Action to disable warehouse
  ///
  /// In en, this message translates to:
  /// **'Disable warehouse'**
  String get warehousesActionDisable;

  /// Action to enable disabled warehouse
  ///
  /// In en, this message translates to:
  /// **'Enable warehouse'**
  String get warehousesActionEnable;

  /// Button to create new warehouse
  ///
  /// In en, this message translates to:
  /// **'New warehouse'**
  String get warehousesCreateButton;

  /// Title for new warehouse dialog
  ///
  /// In en, this message translates to:
  /// **'New warehouse'**
  String get warehousesCreateDialogTitle;

  /// Subtitle for new warehouse dialog
  ///
  /// In en, this message translates to:
  /// **'Second workshop, rented space, vehicle'**
  String get warehousesCreateDialogSubtitle;

  /// Label for warehouse name input
  ///
  /// In en, this message translates to:
  /// **'Warehouse name'**
  String get warehousesNameLabel;

  /// Hint for warehouse name input
  ///
  /// In en, this message translates to:
  /// **'e.g. Materials Warehouse'**
  String get warehousesNameHint;

  /// Validation error when warehouse name is empty
  ///
  /// In en, this message translates to:
  /// **'Enter warehouse name'**
  String get warehousesNameError;

  /// Success feedback after creating warehouse
  ///
  /// In en, this message translates to:
  /// **'Warehouse \'{name}\' created'**
  String warehousesCreateSuccess(String name);

  /// Success feedback after setting shipping default warehouse
  ///
  /// In en, this message translates to:
  /// **'Warehouse \'{name}\' set as shipping default'**
  String warehousesSetShippingDefaultSuccess(String name);

  /// Title for disable warehouse confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Disable warehouse?'**
  String get warehousesDisableDialogTitle;

  /// Message for disable warehouse confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Disable warehouse \'{name}\'? It will no longer appear in new documents, stock history remains preserved.'**
  String warehousesDisableDialogMessage(String name);

  /// Success feedback after disabling warehouse
  ///
  /// In en, this message translates to:
  /// **'Warehouse \'{name}\' disabled'**
  String warehousesDisableSuccess(String name);

  /// Title for enable warehouse confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Enable warehouse?'**
  String get warehousesEnableDialogTitle;

  /// Message for enable warehouse confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Enable warehouse \'{name}\'? It will become available again in stock documents.'**
  String warehousesEnableDialogMessage(String name);

  /// Success feedback after enabling warehouse
  ///
  /// In en, this message translates to:
  /// **'Warehouse \'{name}\' enabled'**
  String warehousesEnableSuccess(String name);

  /// Title when no warehouses are returned
  ///
  /// In en, this message translates to:
  /// **'No warehouses found'**
  String get warehousesEmptyTitle;

  /// Message when no warehouses are returned
  ///
  /// In en, this message translates to:
  /// **'Company warehouse list is empty.'**
  String get warehousesEmptyMessage;

  /// Screen title for Bazis specification import
  ///
  /// In en, this message translates to:
  /// **'Bazis Specification'**
  String get bazisImportTitle;

  /// Screen subtitle for Bazis specification import
  ///
  /// In en, this message translates to:
  /// **'Inspect CAD export and create product BOM'**
  String get bazisImportSubtitle;

  /// Button to pick a Bazis XML export file
  ///
  /// In en, this message translates to:
  /// **'Select Bazis File'**
  String get bazisPickFileAction;

  /// Button to change the selected file
  ///
  /// In en, this message translates to:
  /// **'Select another file'**
  String get bazisChangeFileAction;

  /// Hint text for picking Bazis XML export
  ///
  /// In en, this message translates to:
  /// **'XML project export from Bazis-Mebelschik (.xml)'**
  String get bazisPickFileHint;

  /// Summary string of totals in Bazis export
  ///
  /// In en, this message translates to:
  /// **'Products: {products} · Parts: {parts} · Materials: {materials} · Operations: {operations}'**
  String bazisTotalsSummary(
    int products,
    int parts,
    int materials,
    int operations,
  );

  /// Button to create BOM specification in ERPNext
  ///
  /// In en, this message translates to:
  /// **'Create Specification'**
  String get bazisCreateSpecificationAction;

  /// Loading label while creating BOM specification
  ///
  /// In en, this message translates to:
  /// **'Creating specification…'**
  String get bazisCreatingSpecification;

  /// Loading label while inspecting Bazis file
  ///
  /// In en, this message translates to:
  /// **'Reading export…'**
  String get bazisInspectingFile;

  /// Label for product
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get bazisProductLabel;

  /// Label for product article
  ///
  /// In en, this message translates to:
  /// **'Article: {article}'**
  String bazisArticleLabel(String article);

  /// Label for product order reference
  ///
  /// In en, this message translates to:
  /// **'Order: {order}'**
  String bazisOrderLabel(String order);

  /// Label for price
  ///
  /// In en, this message translates to:
  /// **'Price: {price}'**
  String bazisPriceLabel(String price);

  /// Quantity in pieces
  ///
  /// In en, this message translates to:
  /// **'{qty} pcs'**
  String bazisQtyLabel(String qty);

  /// Tab header for parts
  ///
  /// In en, this message translates to:
  /// **'Parts ({count})'**
  String bazisPartsTab(int count);

  /// Tab header for materials
  ///
  /// In en, this message translates to:
  /// **'Materials ({count})'**
  String bazisMaterialsTab(int count);

  /// Tab header for operations
  ///
  /// In en, this message translates to:
  /// **'Operations ({count})'**
  String bazisOperationsTab(int count);

  /// Structural block/drawer workshop location for part
  ///
  /// In en, this message translates to:
  /// **'Block: {block}'**
  String bazisPartBlockLabel(String block);

  /// Dimensions of part in mm
  ///
  /// In en, this message translates to:
  /// **'{length} × {width} × {thickness} mm'**
  String bazisPartDimensions(String length, String width, String thickness);

  /// Edge materials list for part
  ///
  /// In en, this message translates to:
  /// **'Edge: {edges}'**
  String bazisPartEdges(String edges);

  /// Quantity and unit of material
  ///
  /// In en, this message translates to:
  /// **'{qty} {unit}'**
  String bazisMaterialUnitQty(String qty, String unit);

  /// Operation time in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min.'**
  String bazisOperationMinutes(String minutes);

  /// Badge when a new BOM draft was created
  ///
  /// In en, this message translates to:
  /// **'Specification created'**
  String get bazisBomStatusCreated;

  /// Badge when an existing BOM draft was updated
  ///
  /// In en, this message translates to:
  /// **'Specification draft updated'**
  String get bazisBomStatusUpdated;

  /// Alert header for skipped materials with 0 quantity
  ///
  /// In en, this message translates to:
  /// **'Materials without calculated quantity (omitted from BOM):'**
  String get bazisMaterialsWithoutQtyAlert;

  /// Alert header for operations with no workstation
  ///
  /// In en, this message translates to:
  /// **'Operations awaiting workstation assignment (added to catalog, not placed in routing):'**
  String get bazisOperationsAwaitingWorkstationAlert;

  /// Success title after import
  ///
  /// In en, this message translates to:
  /// **'Specification prepared'**
  String get bazisImportSuccessTitle;

  /// Button to upload another file
  ///
  /// In en, this message translates to:
  /// **'Upload another export'**
  String get bazisImportAnotherAction;

  /// Label with BOM document name
  ///
  /// In en, this message translates to:
  /// **'BOM doc: {bom}'**
  String bazisBomDocLabel(String bom);

  /// Label with Item document name
  ///
  /// In en, this message translates to:
  /// **'Item: {item}'**
  String bazisItemDocLabel(String item);

  /// Empty state message for parts
  ///
  /// In en, this message translates to:
  /// **'No parts in product'**
  String get bazisEmptyParts;

  /// Empty state message for materials
  ///
  /// In en, this message translates to:
  /// **'No materials in product'**
  String get bazisEmptyMaterials;

  /// Empty state message for operations
  ///
  /// In en, this message translates to:
  /// **'No operations in product'**
  String get bazisEmptyOperations;

  /// Title for integrations settings screen
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrationsTitle;

  /// Subtitle for integrations settings screen
  ///
  /// In en, this message translates to:
  /// **'TrustMe and Kaspi Pay Keys'**
  String get integrationsSubtitle;

  /// Security explanation for API keys and secrets
  ///
  /// In en, this message translates to:
  /// **'These are your company keys. They are stored encrypted on your server and are never shared externally.'**
  String get integrationsSecurityNote;

  /// Provider title for TrustMe
  ///
  /// In en, this message translates to:
  /// **'TrustMe'**
  String get trustmeTitle;

  /// Subtitle for TrustMe
  ///
  /// In en, this message translates to:
  /// **'Digital contract signing'**
  String get trustmeSubtitle;

  /// Label for organization BIN
  ///
  /// In en, this message translates to:
  /// **'Organization BIN'**
  String get trustmeBinLabel;

  /// Hint for organization BIN
  ///
  /// In en, this message translates to:
  /// **'12 digits'**
  String get trustmeBinHint;

  /// Label for API token
  ///
  /// In en, this message translates to:
  /// **'API Token'**
  String get trustmeApiTokenLabel;

  /// Hint for API token
  ///
  /// In en, this message translates to:
  /// **'Enter new token to change'**
  String get trustmeApiTokenHint;

  /// Label for webhook secret
  ///
  /// In en, this message translates to:
  /// **'Webhook Secret'**
  String get trustmeWebhookSecretLabel;

  /// Hint for webhook secret
  ///
  /// In en, this message translates to:
  /// **'Enter new secret to change'**
  String get trustmeWebhookSecretHint;

  /// Provider title for Kaspi Pay
  ///
  /// In en, this message translates to:
  /// **'Kaspi Pay'**
  String get kaspiTitle;

  /// Subtitle for Kaspi Pay
  ///
  /// In en, this message translates to:
  /// **'Payment acceptance and invoicing'**
  String get kaspiSubtitle;

  /// Label for merchant ID
  ///
  /// In en, this message translates to:
  /// **'Merchant / Point ID'**
  String get kaspiMerchantIdLabel;

  /// Hint for merchant ID
  ///
  /// In en, this message translates to:
  /// **'Identifier in Kaspi Pay'**
  String get kaspiMerchantIdHint;

  /// Label for API key
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get kaspiApiKeyLabel;

  /// Hint for API key
  ///
  /// In en, this message translates to:
  /// **'Enter new key to change'**
  String get kaspiApiKeyHint;

  /// Label for webhook secret
  ///
  /// In en, this message translates to:
  /// **'Webhook Secret'**
  String get kaspiWebhookSecretLabel;

  /// Hint for webhook secret
  ///
  /// In en, this message translates to:
  /// **'Enter new secret to change'**
  String get kaspiWebhookSecretHint;

  /// Badge indicating secret is stored
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get integrationSecretConfigured;

  /// Badge indicating secret is not set
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get integrationSecretNotConfigured;

  /// Button to clear a stored secret
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get integrationClearSecretAction;

  /// Button to save integration settings
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get integrationSaveAction;

  /// Notice when settings saved successfully
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get integrationSavedSuccess;

  /// Title for secret deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete key?'**
  String get integrationClearDialogTitle;

  /// Message for secret deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete {secretName}? {providerName} integration will stop working until a new key is entered.'**
  String integrationClearDialogMessage(String secretName, String providerName);

  /// Notice when secret is deleted
  ///
  /// In en, this message translates to:
  /// **'Key deleted'**
  String get integrationClearSuccess;

  /// Label for integration last status
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String integrationLastStatusLabel(String status);

  /// Label for integration last error
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String integrationLastErrorLabel(String error);

  /// Label for last checked date
  ///
  /// In en, this message translates to:
  /// **'Checked: {date}'**
  String integrationLastCheckedLabel(String date);

  /// Switch label to enable/disable integration
  ///
  /// In en, this message translates to:
  /// **'Enable integration'**
  String get integrationEnableToggle;

  /// Note explaining where company details are used
  ///
  /// In en, this message translates to:
  /// **'Details are used to generate contracts, invoices, and waybills.'**
  String get companyDetailsDocNote;

  /// Section header for general company information
  ///
  /// In en, this message translates to:
  /// **'General information'**
  String get companyDetailsSectionGeneral;

  /// Label for company name field
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyDetailsNameLabel;

  /// Hint for company name field
  ///
  /// In en, this message translates to:
  /// **'Korkem Furniture LLC'**
  String get companyDetailsNameHint;

  /// Label for BIN / Business Identification Number
  ///
  /// In en, this message translates to:
  /// **'BIN'**
  String get companyDetailsBinLabel;

  /// Hint for BIN field
  ///
  /// In en, this message translates to:
  /// **'12 digits'**
  String get companyDetailsBinHint;

  /// Validation error when BIN is not 12 digits
  ///
  /// In en, this message translates to:
  /// **'BIN must contain exactly 12 digits'**
  String get companyDetailsBinError;

  /// Section header for contacts and address
  ///
  /// In en, this message translates to:
  /// **'Contacts and address'**
  String get companyDetailsSectionContacts;

  /// Label for city field
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get companyDetailsCityLabel;

  /// Hint for city field
  ///
  /// In en, this message translates to:
  /// **'Almaty'**
  String get companyDetailsCityHint;

  /// Label for legal address field
  ///
  /// In en, this message translates to:
  /// **'Legal address'**
  String get companyDetailsAddressLabel;

  /// Hint for address field
  ///
  /// In en, this message translates to:
  /// **'150 Abay ave., office 401'**
  String get companyDetailsAddressHint;

  /// Label for phone field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get companyDetailsPhoneLabel;

  /// Hint for phone field
  ///
  /// In en, this message translates to:
  /// **'+7 777 123 45 67'**
  String get companyDetailsPhoneHint;

  /// Label for company email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get companyDetailsEmailLabel;

  /// Hint for email field
  ///
  /// In en, this message translates to:
  /// **'info@korkem.kz'**
  String get companyDetailsEmailHint;

  /// Validation error for company email field
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get companyDetailsEmailError;

  /// Label for company website field
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get companyDetailsWebsiteLabel;

  /// Hint for company website field
  ///
  /// In en, this message translates to:
  /// **'korkem.kz'**
  String get companyDetailsWebsiteHint;

  /// Notice that company name is read-only on details screen
  ///
  /// In en, this message translates to:
  /// **'Company name is set during creation and changed in company profile'**
  String get companyDetailsReadOnlyNameNotice;

  /// Section header for banking details
  ///
  /// In en, this message translates to:
  /// **'Bank details'**
  String get companyDetailsSectionBank;

  /// Label for bank name field
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get companyDetailsBankNameLabel;

  /// Hint for bank name field
  ///
  /// In en, this message translates to:
  /// **'Kaspi Bank JSC'**
  String get companyDetailsBankNameHint;

  /// Label for IBAN account field
  ///
  /// In en, this message translates to:
  /// **'Bank account (IBAN)'**
  String get companyDetailsIbanLabel;

  /// Hint for IBAN field
  ///
  /// In en, this message translates to:
  /// **'KZ...'**
  String get companyDetailsIbanHint;

  /// Helper note showing IBAN format
  ///
  /// In en, this message translates to:
  /// **'Format: KZ and 18 characters (e.g. KZ69...)'**
  String get companyDetailsIbanHelper;

  /// Validation error when Kazakhstan IBAN format is invalid
  ///
  /// In en, this message translates to:
  /// **'Kazakhstan IBAN must start with KZ and contain 20 characters'**
  String get companyDetailsIbanError;

  /// Label for BIC / SWIFT code field
  ///
  /// In en, this message translates to:
  /// **'Bank BIC'**
  String get companyDetailsBikLabel;

  /// Hint for BIC field
  ///
  /// In en, this message translates to:
  /// **'CASPKZ2A'**
  String get companyDetailsBikHint;

  /// Validation error for BIC code
  ///
  /// In en, this message translates to:
  /// **'BIC must contain 8 to 11 characters'**
  String get companyDetailsBikError;

  /// Save button on company details screen
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get companyDetailsSaveButton;

  /// Success message when company details are saved
  ///
  /// In en, this message translates to:
  /// **'Company details saved successfully'**
  String get companyDetailsSaveSuccess;

  /// Error message when company details cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Failed to load company details'**
  String get companyDetailsLoadError;

  /// Title for items and prices catalog screen
  ///
  /// In en, this message translates to:
  /// **'Items and prices'**
  String get itemsTitle;

  /// Subtitle for items catalog screen
  ///
  /// In en, this message translates to:
  /// **'Product catalog, units of measure, and prices'**
  String get itemsSubtitle;

  /// Search field hint in items catalog
  ///
  /// In en, this message translates to:
  /// **'Search by name or code'**
  String get itemsSearchHint;

  /// Title for empty items catalog
  ///
  /// In en, this message translates to:
  /// **'No items in catalog yet'**
  String get itemsEmptyTitle;

  /// Message for empty items catalog
  ///
  /// In en, this message translates to:
  /// **'Add the first catalog item'**
  String get itemsEmptyMessage;

  /// Action button to add a new item
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get itemsAddItem;

  /// Dialog title for creating a new item
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get itemsCreateTitle;

  /// Label for item name field
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemsNameLabel;

  /// Hint for item name field
  ///
  /// In en, this message translates to:
  /// **'Two-door wardrobe'**
  String get itemsNameHint;

  /// Validation error when item name is empty
  ///
  /// In en, this message translates to:
  /// **'Enter item name'**
  String get itemsNameRequired;

  /// Label for item code field
  ///
  /// In en, this message translates to:
  /// **'Item code (optional)'**
  String get itemsCodeLabel;

  /// Hint for item code field
  ///
  /// In en, this message translates to:
  /// **'CAB-01'**
  String get itemsCodeHint;

  /// Label for unit of measure dropdown
  ///
  /// In en, this message translates to:
  /// **'Unit of measure'**
  String get itemsUnitLabel;

  /// Hint for unit of measure dropdown
  ///
  /// In en, this message translates to:
  /// **'Select unit'**
  String get itemsUnitHint;

  /// Validation error when unit of measure is empty
  ///
  /// In en, this message translates to:
  /// **'Unit of measure is required'**
  String get itemsUnitRequired;

  /// Label for item description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get itemsDescriptionLabel;

  /// Hint for item description field
  ///
  /// In en, this message translates to:
  /// **'Materials, hardware, notes'**
  String get itemsDescriptionHint;

  /// Label for sale price field
  ///
  /// In en, this message translates to:
  /// **'Sale price (optional)'**
  String get itemsPriceLabel;

  /// Hint for sale price field
  ///
  /// In en, this message translates to:
  /// **'0 ₸'**
  String get itemsPriceHint;

  /// Label shown when item has no preset price
  ///
  /// In en, this message translates to:
  /// **'Price on request'**
  String get itemsPriceOnRequest;

  /// Short label for price
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get itemsPriceLabelShort;

  /// Dialog title for setting/changing item price
  ///
  /// In en, this message translates to:
  /// **'Change price'**
  String get itemsSetPriceTitle;

  /// Action button in set price dialog
  ///
  /// In en, this message translates to:
  /// **'Set price'**
  String get itemsSetPriceAction;

  /// Validation error when price is required but empty
  ///
  /// In en, this message translates to:
  /// **'Enter price'**
  String get itemsPriceRequired;

  /// Validation error for invalid price format
  ///
  /// In en, this message translates to:
  /// **'Invalid price amount'**
  String get itemsPriceInvalid;

  /// Success message when item price is updated
  ///
  /// In en, this message translates to:
  /// **'Price updated'**
  String get itemsPriceUpdated;

  /// Success message when a new item is created
  ///
  /// In en, this message translates to:
  /// **'Item added'**
  String get itemsCreateSuccess;

  /// Placeholder while loading units of measure
  ///
  /// In en, this message translates to:
  /// **'Loading units...'**
  String get itemsUnitsLoading;

  /// Error message when units of measure fail to load
  ///
  /// In en, this message translates to:
  /// **'Could not load units of measure'**
  String get itemsUnitsLoadError;

  /// Action label to open items catalog from quotation
  ///
  /// In en, this message translates to:
  /// **'Items catalog'**
  String get itemsCatalogAction;

  /// Navigation label for items and prices
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get navItems;

  /// Settings tile title for enquiry flow
  ///
  /// In en, this message translates to:
  /// **'Enquiry pipeline'**
  String get settingsEnquiryFlowTitle;

  /// Settings tile subtitle for enquiry flow
  ///
  /// In en, this message translates to:
  /// **'Pipeline from request to production order'**
  String get settingsEnquiryFlowSubtitle;

  /// Title of the enquiry pipeline screen
  ///
  /// In en, this message translates to:
  /// **'Enquiry pipeline'**
  String get enquiryFlowTitle;

  /// Subtitle of the enquiry pipeline screen
  ///
  /// In en, this message translates to:
  /// **'Pipeline from customer request to production order'**
  String get enquiryFlowSubtitle;

  /// First step title in pipeline
  ///
  /// In en, this message translates to:
  /// **'Enquiry'**
  String get enquiryFlowStep1;

  /// Second step title in pipeline
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get enquiryFlowStep2;

  /// Third step title in pipeline
  ///
  /// In en, this message translates to:
  /// **'Proposal'**
  String get enquiryFlowStep3;

  /// Fourth step title in pipeline
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get enquiryFlowStep4;

  /// Prompt to select a capture
  ///
  /// In en, this message translates to:
  /// **'Select a request to process'**
  String get enquiryFlowSelectCapture;

  /// Label for what the customer said
  ///
  /// In en, this message translates to:
  /// **'Customer words'**
  String get enquiryFlowSpokenText;

  /// Label for customer name field
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get enquiryFlowCustomerName;

  /// Dropdown label to assign measurer
  ///
  /// In en, this message translates to:
  /// **'Assign measurer'**
  String get enquiryFlowAssignMeasurer;

  /// Label for measurement date picker
  ///
  /// In en, this message translates to:
  /// **'Measurement date'**
  String get enquiryFlowMeasureDate;

  /// Button to convert capture to enquiry
  ///
  /// In en, this message translates to:
  /// **'Create enquiry'**
  String get enquiryFlowConvertAction;

  /// Title when customer name is ambiguous
  ///
  /// In en, this message translates to:
  /// **'Multiple matching customers found'**
  String get enquiryFlowAmbiguousTitle;

  /// Subtitle for ambiguous customer resolution
  ///
  /// In en, this message translates to:
  /// **'Choose an existing customer or create a new one:'**
  String get enquiryFlowAmbiguousSubtitle;

  /// Option to create as new customer
  ///
  /// In en, this message translates to:
  /// **'Create as new customer'**
  String get enquiryFlowCreateNewCustomer;

  /// Field label for dimensions
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get enquiryFlowDimensions;

  /// Hint for dimensions
  ///
  /// In en, this message translates to:
  /// **'3200x600, h=2100, left corner'**
  String get enquiryFlowDimensionsHint;

  /// Field label for notes
  ///
  /// In en, this message translates to:
  /// **'Notes and materials'**
  String get enquiryFlowNotes;

  /// Hint for notes
  ///
  /// In en, this message translates to:
  /// **'MDF white gloss, Blum hardware'**
  String get enquiryFlowNotesHint;

  /// Field label for address
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get enquiryFlowAddress;

  /// Hint for address
  ///
  /// In en, this message translates to:
  /// **'Abay ave 45, apt 12'**
  String get enquiryFlowAddressHint;

  /// Field label for city
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get enquiryFlowCity;

  /// Hint for city
  ///
  /// In en, this message translates to:
  /// **'Almaty'**
  String get enquiryFlowCityHint;

  /// Button to record measurement
  ///
  /// In en, this message translates to:
  /// **'Record measurement'**
  String get enquiryFlowRecordMeasurementAction;

  /// Label for photo attachment section on measurement step
  ///
  /// In en, this message translates to:
  /// **'Photos and references'**
  String get enquiryFlowAttachPhotos;

  /// Button to capture a photo with camera
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get enquiryFlowTakePhoto;

  /// Button to pick photos from gallery
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get enquiryFlowPickGallery;

  /// Count badge of attached measurement photos
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} photo attached} other{{count} photos attached}}'**
  String enquiryFlowPhotosCount(int count);

  /// Tooltip/label to remove attached photo
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get enquiryFlowRemovePhoto;

  /// Error message when camera or photo permissions are denied
  ///
  /// In en, this message translates to:
  /// **'Camera or gallery access was denied. Grant permission in device settings to attach measurement photos.'**
  String get enquiryFlowPermissionDenied;

  /// Field label for proposal item name
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get enquiryFlowItemCode;

  /// Hint for proposal item name
  ///
  /// In en, this message translates to:
  /// **'Kitchen set'**
  String get enquiryFlowItemCodeHint;

  /// Field label for proposal item description
  ///
  /// In en, this message translates to:
  /// **'Item description'**
  String get enquiryFlowItemDesc;

  /// Hint for proposal item description
  ///
  /// In en, this message translates to:
  /// **'MDF facades, stone countertop'**
  String get enquiryFlowItemDescHint;

  /// Field label for item quantity
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get enquiryFlowItemQty;

  /// Field label for item price
  ///
  /// In en, this message translates to:
  /// **'Unit price (₸)'**
  String get enquiryFlowItemRate;

  /// Button to add another item row
  ///
  /// In en, this message translates to:
  /// **'+ Add item'**
  String get enquiryFlowAddItem;

  /// Field label for quotation validity days
  ///
  /// In en, this message translates to:
  /// **'Validity period (days)'**
  String get enquiryFlowValidDays;

  /// Button to draft proposal
  ///
  /// In en, this message translates to:
  /// **'Draft proposal'**
  String get enquiryFlowDraftProposalAction;

  /// Field label for order delivery date
  ///
  /// In en, this message translates to:
  /// **'Delivery date'**
  String get enquiryFlowDeliveryDate;

  /// Validation message when delivery date is missing
  ///
  /// In en, this message translates to:
  /// **'Specify delivery date to create order'**
  String get enquiryFlowDeliveryDateRequired;

  /// Button label to pick delivery date
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get enquiryFlowPickDeliveryDate;

  /// Button to accept quotation and create order
  ///
  /// In en, this message translates to:
  /// **'Accept and create order'**
  String get enquiryFlowAcceptOrderAction;

  /// Banner when order is successfully created
  ///
  /// In en, this message translates to:
  /// **'Order sent to production'**
  String get enquiryFlowOrderCompleted;

  /// Button to navigate to created order
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get enquiryFlowViewOrder;

  /// Empty state title when no captures exist
  ///
  /// In en, this message translates to:
  /// **'No requests available'**
  String get enquiryFlowEmptyCaptures;

  /// Empty state description for captures
  ///
  /// In en, this message translates to:
  /// **'Create a new request by voice or text to process it through the pipeline.'**
  String get enquiryFlowEmptyCapturesDesc;

  /// Section header for design and drawings on order screen
  ///
  /// In en, this message translates to:
  /// **'Design & drawings'**
  String get orderDesignSection;

  /// Status badge when design is not assigned
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get orderDesignStatusNotAssigned;

  /// Status badge when design is assigned
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get orderDesignStatusAssigned;

  /// Status badge when design is delivered and accepted
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get orderDesignStatusDelivered;

  /// Status badge when design task deadline has passed
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get orderDesignStatusOverdue;

  /// Empty state title when design is not assigned
  ///
  /// In en, this message translates to:
  /// **'Design not assigned yet'**
  String get orderDesignNoTaskTitle;

  /// Empty state body for design
  ///
  /// In en, this message translates to:
  /// **'Drawings and specifications are required before production starts.'**
  String get orderDesignNoTaskBody;

  /// Button label to assign design task
  ///
  /// In en, this message translates to:
  /// **'Assign design'**
  String get orderDesignAssignAction;

  /// Label for assigned designer
  ///
  /// In en, this message translates to:
  /// **'Designer'**
  String get orderDesignDesignerLabel;

  /// Label for drawing deadline
  ///
  /// In en, this message translates to:
  /// **'Drawing due date'**
  String get orderDesignDueDateLabel;

  /// Validation message when due date is missing
  ///
  /// In en, this message translates to:
  /// **'Specify drawing due date'**
  String get orderDesignDueDateRequired;

  /// Header for attached drawings list
  ///
  /// In en, this message translates to:
  /// **'Attached files'**
  String get orderDesignFilesHeader;

  /// Explanation when no drawing files are attached
  ///
  /// In en, this message translates to:
  /// **'Drawing expected. Design cannot be accepted without an attached file.'**
  String get orderDesignNoFilesNotice;

  /// Button label to attach drawing file
  ///
  /// In en, this message translates to:
  /// **'Attach drawing'**
  String get orderDesignAttachFileAction;

  /// Title for attach drawing dialog
  ///
  /// In en, this message translates to:
  /// **'Attach drawing to order'**
  String get orderDesignAttachDialogTitle;

  /// Label for drawing file name input
  ///
  /// In en, this message translates to:
  /// **'Drawing file name'**
  String get orderDesignFileNameLabel;

  /// Hint for drawing file name input
  ///
  /// In en, this message translates to:
  /// **'drawing_kitchen.dxf'**
  String get orderDesignFileNameHint;

  /// Button to confirm file attachment
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get orderDesignAttachButton;

  /// Button to accept and complete design
  ///
  /// In en, this message translates to:
  /// **'Accept design'**
  String get orderDesignDeliverAction;

  /// Banner when design is verified and completed
  ///
  /// In en, this message translates to:
  /// **'Design accepted, drawings verified'**
  String get orderDesignCompletedNotice;

  /// Section header for installation on order screen
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get orderInstallationSection;

  /// Status badge when installation is not scheduled
  ///
  /// In en, this message translates to:
  /// **'Not scheduled'**
  String get orderInstallationStatusNotScheduled;

  /// Status badge when installation is scheduled
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get orderInstallationStatusScheduled;

  /// Status badge when installation is completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderInstallationStatusCompleted;

  /// Status badge when installation is overdue
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get orderInstallationStatusOverdue;

  /// Explanation when no items have been delivered yet
  ///
  /// In en, this message translates to:
  /// **'Shipment comes first, then installation. A crew arriving without furniture wastes a day, and the client loses trust.'**
  String get orderInstallationNoDeliveryNotice;

  /// Notice when order has shipments and is ready for installation
  ///
  /// In en, this message translates to:
  /// **'Furniture has been shipped. Schedule the installation crew arrival date.'**
  String get orderInstallationReadyToSchedule;

  /// Button to schedule installation
  ///
  /// In en, this message translates to:
  /// **'Schedule installation'**
  String get orderInstallationScheduleAction;

  /// Label for assigned installer
  ///
  /// In en, this message translates to:
  /// **'Installer / Crew'**
  String get orderInstallationInstallerLabel;

  /// Label for installation date
  ///
  /// In en, this message translates to:
  /// **'Installation date'**
  String get orderInstallationDateLabel;

  /// Validation message when installation date is missing
  ///
  /// In en, this message translates to:
  /// **'Specify installation date'**
  String get orderInstallationDateRequired;

  /// Button to complete installation
  ///
  /// In en, this message translates to:
  /// **'Installation completed'**
  String get orderInstallationCompleteAction;

  /// Title for complete installation dialog
  ///
  /// In en, this message translates to:
  /// **'Complete installation'**
  String get orderInstallationCompleteDialogTitle;

  /// Label for crew notes
  ///
  /// In en, this message translates to:
  /// **'Crew notes'**
  String get orderInstallationNotesLabel;

  /// Hint for crew notes field
  ///
  /// In en, this message translates to:
  /// **'E.g. wall was uneven, installed with extension filler'**
  String get orderInstallationNotesHint;

  /// Banner when installation is successfully completed
  ///
  /// In en, this message translates to:
  /// **'Installation completed successfully'**
  String get orderInstallationCompletedNotice;

  /// Section header for warranty on order screen
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get orderWarrantySection;

  /// Notice when order has not been shipped yet
  ///
  /// In en, this message translates to:
  /// **'Warranty will start after shipment.'**
  String get orderWarrantyNotStartedNotice;

  /// Date when goods were first shipped to customer
  ///
  /// In en, this message translates to:
  /// **'Shipped on: {date}'**
  String orderWarrantyShippedOn(String date);

  /// Status badge for active warranty
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get orderWarrantyStatusActive;

  /// Status badge for expired warranty
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get orderWarrantyStatusExpired;

  /// Status badge when item has no warranty period
  ///
  /// In en, this message translates to:
  /// **'No warranty'**
  String get orderWarrantyStatusNoWarranty;

  /// Warranty expiration date
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String orderWarrantyUntil(String date);

  /// Warranty duration in days
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String orderWarrantyPeriodDays(int days);

  /// Action button to file a warranty claim
  ///
  /// In en, this message translates to:
  /// **'File warranty claim'**
  String get orderWarrantyClaimAction;

  /// Title for warranty claim dialog
  ///
  /// In en, this message translates to:
  /// **'File warranty claim'**
  String get orderWarrantyClaimDialogTitle;

  /// Label for selecting item in claim dialog
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get orderWarrantyItemLabel;

  /// Label for complaint description
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get orderWarrantyComplaintLabel;

  /// Hint text for complaint input
  ///
  /// In en, this message translates to:
  /// **'Describe the issue in detail: what broke, under what conditions'**
  String get orderWarrantyComplaintHint;

  /// Validation error when complaint is empty
  ///
  /// In en, this message translates to:
  /// **'Describe reason for the claim'**
  String get orderWarrantyComplaintRequired;

  /// Banner when warranty claim is accepted
  ///
  /// In en, this message translates to:
  /// **'Claim {claim} registered successfully'**
  String orderWarrantyClaimSuccessNotice(String claim);

  /// Section header for invoicing on order screen
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get orderInvoicingSection;

  /// Status badge when no invoice has been drafted
  ///
  /// In en, this message translates to:
  /// **'Not issued'**
  String get orderInvoicingStatusNotDrafted;

  /// Status badge when sales invoice is drafted or submitted
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get orderInvoicingStatusDrafted;

  /// Status badge when sales invoice is paid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get orderInvoicingStatusPaid;

  /// Notice when sales order is in draft state
  ///
  /// In en, this message translates to:
  /// **'The order is not yet submitted. An invoice for a draft is an invoice for something not yet agreed upon.'**
  String get orderInvoicingOrderNotSubmittedNotice;

  /// Notice when no items have been delivered
  ///
  /// In en, this message translates to:
  /// **'Nothing has been shipped for this order yet. An invoice for undelivered furniture causes conflict with the client.'**
  String get orderInvoicingNoDeliveryNotice;

  /// Action button to draft sales invoice
  ///
  /// In en, this message translates to:
  /// **'Issue invoice'**
  String get orderInvoicingCreateAction;

  /// Label for invoice number
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get orderInvoicingNumberLabel;

  /// Label for invoice grand total
  ///
  /// In en, this message translates to:
  /// **'Invoice total'**
  String get orderInvoicingTotalLabel;

  /// Banner when sales invoice is successfully created
  ///
  /// In en, this message translates to:
  /// **'Invoice {invoice} created successfully'**
  String orderInvoicingSuccessNotice(String invoice);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get settingsSignedInAs;

  /// No description provided for @settingsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsConnection;

  /// No description provided for @settingsLookAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Look and language'**
  String get settingsLookAndLanguage;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navDashboard;

  /// No description provided for @dashboardGreeting.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardGreeting;

  /// No description provided for @dashboardMyWork.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get dashboardMyWork;

  /// Under the task tiles: how much of a person's own workload is late
  ///
  /// In en, this message translates to:
  /// **'{overdue} of {total} are overdue'**
  String dashboardWorkload(int overdue, int total);

  /// No description provided for @dashboardAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get dashboardAttention;

  /// No description provided for @dashboardAllClear.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you right now'**
  String get dashboardAllClear;

  /// No description provided for @dashboardAllClearBody.
  ///
  /// In en, this message translates to:
  /// **'Overdue work and decisions waiting on you appear here.'**
  String get dashboardAllClearBody;

  /// No description provided for @metricOpenDeals.
  ///
  /// In en, this message translates to:
  /// **'Open deals'**
  String get metricOpenDeals;

  /// No description provided for @metricOpenLeads.
  ///
  /// In en, this message translates to:
  /// **'Leads'**
  String get metricOpenLeads;

  /// No description provided for @metricMyOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'My tasks'**
  String get metricMyOpenTasks;

  /// No description provided for @metricOverdueTasks.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get metricOverdueTasks;

  /// No description provided for @metricPendingActions.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get metricPendingActions;

  /// No description provided for @metricWorkOrders.
  ///
  /// In en, this message translates to:
  /// **'In production'**
  String get metricWorkOrders;

  /// No description provided for @attentionPendingAction.
  ///
  /// In en, this message translates to:
  /// **'Decision required'**
  String get attentionPendingAction;

  /// No description provided for @attentionOverdueTask.
  ///
  /// In en, this message translates to:
  /// **'Overdue task'**
  String get attentionOverdueTask;

  /// No description provided for @navSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get navSales;

  /// No description provided for @navLeads.
  ///
  /// In en, this message translates to:
  /// **'Leads'**
  String get navLeads;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @dealsEmptyAssigned.
  ///
  /// In en, this message translates to:
  /// **'Nothing assigned to you yet'**
  String get dealsEmptyAssigned;

  /// No description provided for @dealsEmptyAssignedBody.
  ///
  /// In en, this message translates to:
  /// **'You only see deals you own or are assigned to. Ask a manager to assign you one.'**
  String get dealsEmptyAssignedBody;

  /// No description provided for @leadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No leads'**
  String get leadsEmpty;

  /// No description provided for @leadsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New enquiries appear here as they arrive.'**
  String get leadsEmptyBody;

  /// No description provided for @leadConverted.
  ///
  /// In en, this message translates to:
  /// **'Converted'**
  String get leadConverted;

  /// No description provided for @customersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No customers'**
  String get customersEmpty;

  /// No description provided for @customersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Organizations appear here once a deal is created for them.'**
  String get customersEmptyBody;

  /// No description provided for @detailPipeline.
  ///
  /// In en, this message translates to:
  /// **'Pipeline'**
  String get detailPipeline;

  /// No description provided for @detailCommercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial'**
  String get detailCommercial;

  /// No description provided for @detailOwnership.
  ///
  /// In en, this message translates to:
  /// **'Ownership'**
  String get detailOwnership;

  /// No description provided for @detailCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get detailCompany;

  /// No description provided for @fieldStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get fieldStage;

  /// No description provided for @fieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get fieldValue;

  /// No description provided for @fieldProbability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get fieldProbability;

  /// No description provided for @fieldExpectedClose.
  ///
  /// In en, this message translates to:
  /// **'Expected close'**
  String get fieldExpectedClose;

  /// No description provided for @fieldNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get fieldNextStep;

  /// No description provided for @fieldOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get fieldOwner;

  /// No description provided for @fieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get fieldSource;

  /// No description provided for @fieldTerritory.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get fieldTerritory;

  /// No description provided for @fieldIndustry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get fieldIndustry;

  /// No description provided for @fieldWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get fieldWebsite;

  /// No description provided for @fieldEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get fieldEmployees;

  /// No description provided for @fieldRevenue.
  ///
  /// In en, this message translates to:
  /// **'Annual revenue'**
  String get fieldRevenue;

  /// No description provided for @fieldOriginLead.
  ///
  /// In en, this message translates to:
  /// **'Converted from lead'**
  String get fieldOriginLead;

  /// No description provided for @fieldUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get fieldUpdated;

  /// No description provided for @actionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get actionCall;

  /// No description provided for @actionEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get actionEmail;

  /// No description provided for @actionWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get actionWhatsApp;

  /// No description provided for @navApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get navApprovals;

  /// No description provided for @navProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get navProduction;

  /// No description provided for @approvalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing awaiting you'**
  String get approvalsEmpty;

  /// No description provided for @approvalsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Decisions an agent is waiting on will appear here.'**
  String get approvalsEmptyBody;

  /// No description provided for @approvalApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approvalApprove;

  /// No description provided for @approvalReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get approvalReject;

  /// No description provided for @approvalApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvalApproved;

  /// No description provided for @approvalRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get approvalRejected;

  /// No description provided for @approvalRejectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Action'**
  String get approvalRejectDialogTitle;

  /// No description provided for @approvalRejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get approvalRejectReasonHint;

  /// No description provided for @approvalExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get approvalExpires;

  /// No description provided for @approvalExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get approvalExpired;

  /// No description provided for @productionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No work orders'**
  String get productionEmpty;

  /// No description provided for @productionEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Orders appear here once a deal moves into production.'**
  String get productionEmptyBody;

  /// No description provided for @paPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paPending;

  /// No description provided for @paApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get paApproved;

  /// No description provided for @paRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get paRejected;

  /// No description provided for @paExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get paExpired;

  /// No description provided for @woDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get woDraft;

  /// No description provided for @woSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get woSubmitted;

  /// No description provided for @woNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get woNotStarted;

  /// No description provided for @woInProcess.
  ///
  /// In en, this message translates to:
  /// **'In process'**
  String get woInProcess;

  /// No description provided for @woStockReserved.
  ///
  /// In en, this message translates to:
  /// **'Stock reserved'**
  String get woStockReserved;

  /// No description provided for @woStockPartial.
  ///
  /// In en, this message translates to:
  /// **'Stock partly reserved'**
  String get woStockPartial;

  /// No description provided for @woCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get woCompleted;

  /// No description provided for @woStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get woStopped;

  /// No description provided for @woClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get woClosed;

  /// No description provided for @woCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get woCancelled;

  /// No description provided for @navQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get navQuotes;

  /// No description provided for @navWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get navWarehouse;

  /// No description provided for @navOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get navOperations;

  /// No description provided for @quotesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No quotes'**
  String get quotesEmpty;

  /// No description provided for @quotesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Quotes appear here once one is raised for a deal.'**
  String get quotesEmptyBody;

  /// No description provided for @warehouseEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get warehouseEmpty;

  /// No description provided for @warehouseEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Stock items appear here.'**
  String get warehouseEmptyBody;

  /// No description provided for @fieldValidTill.
  ///
  /// In en, this message translates to:
  /// **'Valid till'**
  String get fieldValidTill;

  /// No description provided for @fieldReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get fieldReserved;

  /// No description provided for @warehouseNoStock.
  ///
  /// In en, this message translates to:
  /// **'Not stocked anywhere'**
  String get warehouseNoStock;

  /// No description provided for @quoteExpiredSoon.
  ///
  /// In en, this message translates to:
  /// **'Expires soon'**
  String get quoteExpiredSoon;

  /// No description provided for @qDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get qDraft;

  /// No description provided for @qOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get qOpen;

  /// No description provided for @qReplied.
  ///
  /// In en, this message translates to:
  /// **'Replied'**
  String get qReplied;

  /// No description provided for @qPartiallyOrdered.
  ///
  /// In en, this message translates to:
  /// **'Partly ordered'**
  String get qPartiallyOrdered;

  /// No description provided for @qOrdered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get qOrdered;

  /// No description provided for @qLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get qLost;

  /// No description provided for @qCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get qCancelled;

  /// No description provided for @qExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get qExpired;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been sent yet.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Assignments, mentions and alerts appear here.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// Sidebar row for the AI assistant, and the title of the chat screen
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get navAssistant;

  /// Screen-reader label for the button that opens the sidebar
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// Starts a fresh conversation
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNew;

  /// Heading above past conversations in the sidebar
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get chatRecent;

  /// Headline on an empty conversation
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get chatGreeting;

  /// Hint text in the message field
  ///
  /// In en, this message translates to:
  /// **'Ask KORKEM anything…'**
  String get chatPlaceholder;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// Starts voice input
  ///
  /// In en, this message translates to:
  /// **'Dictate'**
  String get chatDictate;

  /// No description provided for @chatDictateStop.
  ///
  /// In en, this message translates to:
  /// **'Stop dictating'**
  String get chatDictateStop;

  /// No description provided for @chatDictateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Dictation is unavailable. Allow microphone access in your phone settings, or type instead.'**
  String get chatDictateUnavailable;

  /// Status line under the assistant name. It says plainly that no language model is connected, so nobody mistakes a canned reply for a real one
  ///
  /// In en, this message translates to:
  /// **'Local mode · KORKEM data'**
  String get chatLocalMode;

  /// Announced while the assistant prepares a reply
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get chatThinking;

  /// Title when there are no conversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatEmptyThreads;

  /// Body message when there are no conversations.
  ///
  /// In en, this message translates to:
  /// **'Your conversations with the assistant will appear here.'**
  String get chatEmptyThreadsBody;

  /// Button on a data card inside a reply, leading to the matching screen
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get chatOpen;

  /// The honest fallback for anything the assistant does not recognise. It must never invent an answer
  ///
  /// In en, this message translates to:
  /// **'I\'m not connected to a language model yet, so I can\'t answer that. I can show you data from KORKEM:'**
  String get chatNotConnected;

  /// No description provided for @chatSuggestDeals.
  ///
  /// In en, this message translates to:
  /// **'Show my deals'**
  String get chatSuggestDeals;

  /// No description provided for @chatSuggestAttention.
  ///
  /// In en, this message translates to:
  /// **'What needs attention?'**
  String get chatSuggestAttention;

  /// No description provided for @chatSuggestOverdue.
  ///
  /// In en, this message translates to:
  /// **'What is overdue?'**
  String get chatSuggestOverdue;

  /// No description provided for @chatSuggestProduction.
  ///
  /// In en, this message translates to:
  /// **'What\'s in production?'**
  String get chatSuggestProduction;

  /// No description provided for @chatCardOpenDeals.
  ///
  /// In en, this message translates to:
  /// **'Open deals'**
  String get chatCardOpenDeals;

  /// No description provided for @chatCardAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get chatCardAttention;

  /// No description provided for @chatCardTasks.
  ///
  /// In en, this message translates to:
  /// **'My tasks'**
  String get chatCardTasks;

  /// No description provided for @chatCardProduction.
  ///
  /// In en, this message translates to:
  /// **'In production'**
  String get chatCardProduction;

  /// No description provided for @chatHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get chatHistory;

  /// No description provided for @chatHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get chatHistoryEmpty;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get chatEarlier;

  /// No description provided for @chatScrollToEnd.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get chatScrollToEnd;

  /// No description provided for @chatWorkspace.
  ///
  /// In en, this message translates to:
  /// **'AI Workspace'**
  String get chatWorkspace;

  /// No description provided for @chatRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRename;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation?'**
  String get chatDeleteTitle;

  /// No description provided for @chatDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed from this device. This cannot be undone.'**
  String chatDeleteBody(String title);

  /// No description provided for @chatRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation name'**
  String get chatRenameTitle;

  /// No description provided for @navClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get navClients;

  /// No description provided for @chatErrorNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'AI is not set up on the server yet. Ask your KORKEM administrator.'**
  String get chatErrorNotConfigured;

  /// No description provided for @chatErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not reach KORKEM. Check your connection.'**
  String get chatErrorOffline;

  /// No description provided for @chatErrorRefused.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for that.'**
  String get chatErrorRefused;

  /// No description provided for @chatErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Could not answer just now. Try again.'**
  String get chatErrorUnknown;

  /// No description provided for @chatWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get chatWorking;

  /// No description provided for @chatToolDeals.
  ///
  /// In en, this message translates to:
  /// **'Searching deals…'**
  String get chatToolDeals;

  /// No description provided for @chatToolLeads.
  ///
  /// In en, this message translates to:
  /// **'Searching leads…'**
  String get chatToolLeads;

  /// No description provided for @chatToolCustomers.
  ///
  /// In en, this message translates to:
  /// **'Searching customers…'**
  String get chatToolCustomers;

  /// No description provided for @chatToolTasks.
  ///
  /// In en, this message translates to:
  /// **'Searching tasks…'**
  String get chatToolTasks;

  /// No description provided for @chatToolProduction.
  ///
  /// In en, this message translates to:
  /// **'Checking production…'**
  String get chatToolProduction;

  /// No description provided for @chatToolOrders.
  ///
  /// In en, this message translates to:
  /// **'Checking orders…'**
  String get chatToolOrders;

  /// No description provided for @chatToolShortage.
  ///
  /// In en, this message translates to:
  /// **'Working out the shortage…'**
  String get chatToolShortage;

  /// No description provided for @chatToolStock.
  ///
  /// In en, this message translates to:
  /// **'Checking stock…'**
  String get chatToolStock;

  /// No description provided for @chatToolProcurement.
  ///
  /// In en, this message translates to:
  /// **'Preparing the purchase request…'**
  String get chatToolProcurement;

  /// No description provided for @chatToolProfile.
  ///
  /// In en, this message translates to:
  /// **'Checking your profile…'**
  String get chatToolProfile;

  /// Shown when a provider is configured but unreachable.
  ///
  /// In en, this message translates to:
  /// **'The AI service is not responding. Try again shortly.'**
  String get chatErrorProviderUnavailable;

  /// Shown when the provider rate limits or the quota is exhausted.
  ///
  /// In en, this message translates to:
  /// **'The AI service is busy. Wait a moment and try again.'**
  String get chatErrorRateLimited;

  /// Shown when a registered tool failed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete that action in KORKEM.'**
  String get chatErrorToolError;

  /// Heading of the confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'Confirm this action'**
  String get chatConfirmTitle;

  /// Explains that the write has not run.
  ///
  /// In en, this message translates to:
  /// **'The assistant wants to make a change. Nothing has happened yet.'**
  String get chatConfirmBody;

  /// Runs the proposed action.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get chatConfirmApprove;

  /// Declines the proposed action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatConfirmReject;

  /// Shown after declining.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing was changed.'**
  String get chatConfirmRejected;

  /// Badge on a reply produced without a model.
  ///
  /// In en, this message translates to:
  /// **'Not AI — direct data'**
  String get chatFallbackBadge;

  /// Default caption on an untrusted external message quote in chat
  ///
  /// In en, this message translates to:
  /// **'Customer message'**
  String get chatExternalMessageDefault;

  /// Notice stating that external message is untrusted input data, not a direct command
  ///
  /// In en, this message translates to:
  /// **'Someone else’s text — the assistant does not act on it'**
  String get chatExternalDataNotice;

  /// Provider timeout.
  ///
  /// In en, this message translates to:
  /// **'The AI service took too long. Try again.'**
  String get chatErrorTimedOut;

  /// Model missing or not permitted.
  ///
  /// In en, this message translates to:
  /// **'The selected AI model is unavailable. Choose another in AI Settings.'**
  String get chatErrorModelNotFound;

  /// Context window exceeded.
  ///
  /// In en, this message translates to:
  /// **'This conversation is too long. Start a new chat.'**
  String get chatErrorContextTooLarge;

  /// Title of the AI settings screen.
  ///
  /// In en, this message translates to:
  /// **'AI providers'**
  String get aiSettingsTitle;

  /// Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which AI answers, and connect it.'**
  String get aiSettingsSubtitle;

  /// Badge on the provider used when none is named.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get aiSettingsDefault;

  /// Action making a provider the default.
  ///
  /// In en, this message translates to:
  /// **'Use by default'**
  String get aiSettingsMakeDefault;

  /// Status for a provider with no configuration.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get aiSettingsNotConfigured;

  /// Status after a successful connection test.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get aiSettingsConnected;

  /// Status after a failed test.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get aiSettingsTestFailed;

  /// Runs one real call to the provider.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get aiSettingsTest;

  /// Saves provider configuration.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get aiSettingsSave;

  /// Label for the credential field.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get aiSettingsApiKey;

  /// Hint when a key already exists.
  ///
  /// In en, this message translates to:
  /// **'A key is stored. Leave blank to keep it.'**
  String get aiSettingsApiKeyStored;

  /// Label for the model field.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get aiSettingsModel;

  /// Label for the endpoint override.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get aiSettingsBaseUrl;

  /// Security note.
  ///
  /// In en, this message translates to:
  /// **'Keys are stored on the KORKEM server and never sent to this device.'**
  String get aiSettingsKeyNeverLeaves;

  /// Heading for the capability list.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get aiSettingsCapabilities;

  /// Shown for Ollama.
  ///
  /// In en, this message translates to:
  /// **'Runs locally — no key needed.'**
  String get aiSettingsLocalNoKey;

  /// Title of the channel settings screen.
  ///
  /// In en, this message translates to:
  /// **'Chat channels'**
  String get channelsTitle;

  /// Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect the Telegram and WhatsApp bots and say who is on the other end.'**
  String get channelsSubtitle;

  /// Security note.
  ///
  /// In en, this message translates to:
  /// **'Tokens are stored on the KORKEM server and never sent to this device.'**
  String get channelsSecretsNote;

  /// Some credential is missing.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get channelsStateNotConfigured;

  /// Configured but switched off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get channelsStateDisabled;

  /// Configured and on; nothing asked of the provider yet.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get channelsStateReady;

  /// Runs one real call to the provider.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get channelsTest;

  /// Shown after a successful real call.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get channelsTestOk;

  /// Shown after a failed real call.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get channelsTestFailed;

  /// Toggle.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get channelsEnabled;

  /// Saves channel configuration.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get channelsSave;

  /// Hint when a credential already exists.
  ///
  /// In en, this message translates to:
  /// **'Stored. Leave blank to keep it.'**
  String get channelsStored;

  /// Telegram credential.
  ///
  /// In en, this message translates to:
  /// **'Bot token'**
  String get channelsBotToken;

  /// Telegram webhook secret.
  ///
  /// In en, this message translates to:
  /// **'Webhook secret'**
  String get channelsWebhookSecret;

  /// WhatsApp credential.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get channelsAccessToken;

  /// WhatsApp phone number id.
  ///
  /// In en, this message translates to:
  /// **'Phone number ID'**
  String get channelsPhoneNumberId;

  /// WhatsApp webhook verify token.
  ///
  /// In en, this message translates to:
  /// **'Verify token'**
  String get channelsVerifyToken;

  /// Where the provider should send updates.
  ///
  /// In en, this message translates to:
  /// **'Webhook URL'**
  String get channelsWebhookUrl;

  /// Heading for the identity list.
  ///
  /// In en, this message translates to:
  /// **'Who writes in'**
  String get channelsIdentities;

  /// Identity with no user.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get channelsIdentityUnlinked;

  /// Binds a sender to a user.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get channelsLink;

  /// Takes the user away from a sender.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get channelsUnlink;

  /// Email of the user to bind.
  ///
  /// In en, this message translates to:
  /// **'KORKEM user'**
  String get channelsUser;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'Nobody has written to the bots yet.'**
  String get channelsIdentitiesEmpty;

  /// A real call to the provider succeeded.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get channelsStateConnected;

  /// The provider answered and said no.
  ///
  /// In en, this message translates to:
  /// **'Credentials rejected'**
  String get channelsStateInvalid;

  /// The provider cannot deliver to our webhook.
  ///
  /// In en, this message translates to:
  /// **'Webhook problem'**
  String get channelsStateWebhookError;

  /// Nobody answered at all.
  ///
  /// In en, this message translates to:
  /// **'Provider unreachable'**
  String get channelsStateUnavailable;

  /// Registers the webhook with the provider.
  ///
  /// In en, this message translates to:
  /// **'Configure webhook'**
  String get channelsConfigureWebhook;

  /// Stops the provider delivering here.
  ///
  /// In en, this message translates to:
  /// **'Remove webhook'**
  String get channelsRemoveWebhook;

  /// WhatsApp's webhook is configured on Meta's side.
  ///
  /// In en, this message translates to:
  /// **'Paste this URL into the provider\'s dashboard.'**
  String get channelsWebhookManual;

  /// When the last real call was made.
  ///
  /// In en, this message translates to:
  /// **'Last checked'**
  String get channelsLastChecked;

  /// Updates queued at the provider.
  ///
  /// In en, this message translates to:
  /// **'Waiting at the provider'**
  String get channelsPending;

  /// Title of the notification centre.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Subtitle.
  ///
  /// In en, this message translates to:
  /// **'What the system told people, and what could not be delivered.'**
  String get notificationsSubtitle;

  /// Try one delivery again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get notificationsRetry;

  /// Try every eligible delivery again.
  ///
  /// In en, this message translates to:
  /// **'Retry all'**
  String get notificationsRetryAll;

  /// Stop trying to deliver.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get notificationsCancel;

  /// How many times it has been tried.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get notificationsAttempts;

  /// When the retry is due.
  ///
  /// In en, this message translates to:
  /// **'Next attempt'**
  String get notificationsNextAttempt;

  /// Filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsFilterAll;

  /// Title of the dispatch board.
  ///
  /// In en, this message translates to:
  /// **'Work instructions'**
  String get instructionsTitle;

  /// Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Who was asked, and what they answered.'**
  String get instructionsSubtitle;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'Nobody has been given work yet.'**
  String get instructionsEmpty;

  /// How long the employee took.
  ///
  /// In en, this message translates to:
  /// **'Answered in'**
  String get instructionsAnsweredIn;

  /// Sends one real message to a linked identity.
  ///
  /// In en, this message translates to:
  /// **'Send test message'**
  String get channelsSendTest;

  /// Switches the channel off and removes the webhook.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get channelsDisconnect;

  /// When the channel last carried a message in.
  ///
  /// In en, this message translates to:
  /// **'Last received'**
  String get channelsLastInbound;

  /// When the channel last carried a message out.
  ///
  /// In en, this message translates to:
  /// **'Last sent'**
  String get channelsLastOutbound;

  /// How many messages could not be delivered.
  ///
  /// In en, this message translates to:
  /// **'Failed deliveries'**
  String get channelsFailedDeliveries;

  /// How many are scheduled for another attempt.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry'**
  String get channelsPendingRetries;

  /// The bot is blocked or has no rights.
  ///
  /// In en, this message translates to:
  /// **'Blocked by the provider'**
  String get channelsStateForbidden;

  /// The provider is throttling us.
  ///
  /// In en, this message translates to:
  /// **'Rate limited'**
  String get channelsStateRateLimited;

  /// Title of the sales orders screen.
  ///
  /// In en, this message translates to:
  /// **'Sales Orders'**
  String get ordersTitle;

  /// Empty state title.
  ///
  /// In en, this message translates to:
  /// **'No sales orders yet'**
  String get ordersEmpty;

  /// Empty state body.
  ///
  /// In en, this message translates to:
  /// **'New customer orders will appear here.'**
  String get ordersEmptyBody;

  /// Button to launch manufacturing for a sales order.
  ///
  /// In en, this message translates to:
  /// **'Start production'**
  String get ordersActionStartProduction;

  /// Feedback when starting production is in progress.
  ///
  /// In en, this message translates to:
  /// **'Starting production...'**
  String get ordersStartingProduction;

  /// Feedback when production was successfully launched.
  ///
  /// In en, this message translates to:
  /// **'Production started for {id}'**
  String ordersStartSuccess(String id);

  /// Feedback when materials were topped up for existing job.
  ///
  /// In en, this message translates to:
  /// **'Material transferred for {id}'**
  String ordersTopUpSuccess(String id);

  /// Feedback when order is already in production.
  ///
  /// In en, this message translates to:
  /// **'Production for {id} is already started'**
  String ordersAlreadyStarted(String id);

  /// Feedback when there is nothing to start.
  ///
  /// In en, this message translates to:
  /// **'Nothing to start for {id}'**
  String ordersNothingToStart(String id);

  /// Title of dialog when materials are missing.
  ///
  /// In en, this message translates to:
  /// **'Insufficient materials'**
  String get ordersBlockedTitle;

  /// Body of dialog when materials are missing.
  ///
  /// In en, this message translates to:
  /// **'Not enough materials in stock to start production:'**
  String get ordersBlockedBody;

  /// Summary feedback when production start is blocked.
  ///
  /// In en, this message translates to:
  /// **'Cannot start {id}: missing materials on the shelf'**
  String ordersBlockedSummary(String id);

  /// Percentage delivered.
  ///
  /// In en, this message translates to:
  /// **'{percent}% delivered'**
  String ordersDeliveredProgress(String percent);

  /// Delivery date annotation.
  ///
  /// In en, this message translates to:
  /// **'Delivery: {date}'**
  String ordersDeliveryDate(String date);

  /// Order creation date annotation.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String ordersTransactionDate(String date);

  /// Sales Order status: Draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get soDraft;

  /// Sales Order status: To Deliver and Bill.
  ///
  /// In en, this message translates to:
  /// **'To Deliver & Bill'**
  String get soToDeliverAndBill;

  /// Sales Order status: To Bill.
  ///
  /// In en, this message translates to:
  /// **'To Bill'**
  String get soToBill;

  /// Sales Order status: To Deliver.
  ///
  /// In en, this message translates to:
  /// **'To Deliver'**
  String get soToDeliver;

  /// Sales Order status: Completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get soCompleted;

  /// Sales Order status: Cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get soCancelled;

  /// Sales Order status: Closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get soClosed;

  /// Sales Order status: On Hold.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get soOnHold;

  /// Title for Today operational screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// Subtitle for Today operational screen.
  ///
  /// In en, this message translates to:
  /// **'Shop floor operational overview'**
  String get todaySubtitle;

  /// Label for active sales orders metric.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get todayActiveOrders;

  /// Overdue sales orders count badge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} overdue} other{{count} overdue}}'**
  String todayLateOrders(int count);

  /// Text when no orders are overdue.
  ///
  /// In en, this message translates to:
  /// **'All on track'**
  String get todayOrdersAllOnTrack;

  /// Label for in production metric.
  ///
  /// In en, this message translates to:
  /// **'In Production'**
  String get todayInProduction;

  /// Work orders count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} job} other{{count} jobs}}'**
  String todayWorkOrdersCount(int count);

  /// Text when all production jobs are on track.
  ///
  /// In en, this message translates to:
  /// **'No delays'**
  String get todayProductionAllOnTrack;

  /// Label for pending approvals metric.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get todayApprovals;

  /// Count of pending approvals.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} decision} other{{count} decisions}}'**
  String todayApprovalsCount(int count);

  /// Text when no approvals are pending.
  ///
  /// In en, this message translates to:
  /// **'All approved'**
  String get todayApprovalsNone;

  /// Label for stock shortage metric.
  ///
  /// In en, this message translates to:
  /// **'Stock Shortage'**
  String get todayStockDeficit;

  /// Count of stock items with projected quantity below zero.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item in deficit} other{{count} items in deficit}}'**
  String todayDeficitCount(int count);

  /// Text when no stock items are in deficit.
  ///
  /// In en, this message translates to:
  /// **'No shortages'**
  String get todayDeficitNone;

  /// Title for section requiring operator attention.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get todayAttentionTitle;

  /// Title when all operational metrics are healthy.
  ///
  /// In en, this message translates to:
  /// **'All Clear'**
  String get todayAllClearTitle;

  /// Subtitle when all operational metrics are healthy.
  ///
  /// In en, this message translates to:
  /// **'No critical delays or material shortages on the shop floor.'**
  String get todayAllClearSubtitle;

  /// Header for quick navigation section.
  ///
  /// In en, this message translates to:
  /// **'Quick Navigation'**
  String get todayQuickNav;

  /// Error text on today dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get todayTileError;

  /// Title for unassigned voice captures group
  ///
  /// In en, this message translates to:
  /// **'Unassigned captures'**
  String get todayUnassignedCapturesTitle;

  /// Empty state good news for captures
  ///
  /// In en, this message translates to:
  /// **'Nothing lost: all captures have been assigned'**
  String get todayUnassignedCapturesEmpty;

  /// Title for overdue tasks group
  ///
  /// In en, this message translates to:
  /// **'Overdue tasks'**
  String get todayOverdueTasksTitle;

  /// Empty state good news for tasks
  ///
  /// In en, this message translates to:
  /// **'All on schedule: no overdue measurements, designs, or installations'**
  String get todayOverdueTasksEmpty;

  /// Title for orders without design group
  ///
  /// In en, this message translates to:
  /// **'Orders without design'**
  String get todayOrdersWithoutDesignTitle;

  /// Empty state good news for orders without design
  ///
  /// In en, this message translates to:
  /// **'Design is assigned for all orders'**
  String get todayOrdersWithoutDesignEmpty;

  /// Title for delivered orders not invoiced group
  ///
  /// In en, this message translates to:
  /// **'Shipped without invoice'**
  String get todayDeliveredNotInvoicedTitle;

  /// Empty state good news for unbilled shipments
  ///
  /// In en, this message translates to:
  /// **'All shipments are billed'**
  String get todayDeliveredNotInvoicedEmpty;

  /// Headline when all 4 attention groups are clear
  ///
  /// In en, this message translates to:
  /// **'Everything is under control'**
  String get todayAllClearHeadline;

  /// Description when all 4 attention groups are clear
  ///
  /// In en, this message translates to:
  /// **'All requests are assigned, nothing is overdue, designs are in progress, and all deliveries have invoices.'**
  String get todayAllClearDescription;

  /// Overdue task due date label
  ///
  /// In en, this message translates to:
  /// **'Was due: {date}'**
  String todayOverdueWasDue(String date);

  /// Order delivery deadline label
  ///
  /// In en, this message translates to:
  /// **'Due delivery: {date}'**
  String todayDeliveryDue(String date);

  /// Shipment vs invoice progress
  ///
  /// In en, this message translates to:
  /// **'Shipped {delivered}%, billed {billed}%'**
  String todayBilledProgress(String delivered, String billed);

  /// Screen header with date
  ///
  /// In en, this message translates to:
  /// **'Today, {date}'**
  String todayHeaderDate(String date);

  /// Row label for overdue orders
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todayImportantOverdue;

  /// Row label for orders due today
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get todayImportantDueToday;

  /// Row label for orders due this week
  ///
  /// In en, this message translates to:
  /// **'Due this week'**
  String get todayImportantDueThisWeek;

  /// Row label for unpaid amount
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get todayImportantUnpaid;

  /// Row label for material shortage positions
  ///
  /// In en, this message translates to:
  /// **'Material shortage'**
  String get todayImportantMaterialDeficit;

  /// Row label for installations scheduled today
  ///
  /// In en, this message translates to:
  /// **'Installation today'**
  String get todayImportantInstallationToday;

  /// Row label for pending approval decisions
  ///
  /// In en, this message translates to:
  /// **'Requires decision'**
  String get todayImportantRequiresDecision;

  /// Unit for orders count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{order} other{orders}}'**
  String todayOrdersCountUnit(int count);

  /// Unit for material items/positions count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{item} other{items}}'**
  String todayPositionsCountUnit(int count);

  /// Unit for approvals count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{approval} other{approvals}}'**
  String todayApprovalsCountUnit(int count);

  /// Empty state title when all metrics are zero
  ///
  /// In en, this message translates to:
  /// **'Everything is under control'**
  String get todayEmptyStateTitle;

  /// Empty state description when all metrics are zero
  ///
  /// In en, this message translates to:
  /// **'No overdue orders, material shortages, or actions requiring decisions for today.'**
  String get todayEmptyStateDescription;

  /// Section heading for the production jobs of one order.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get orderProductionSection;

  /// Shown when an order has no work orders yet.
  ///
  /// In en, this message translates to:
  /// **'Production has not started'**
  String get orderNoProductionTitle;

  /// Explains that production has not been started for this order.
  ///
  /// In en, this message translates to:
  /// **'No jobs have been raised for this order. Start production once the order is confirmed.'**
  String get orderNoProductionBody;

  /// Section header for linked sales order in work order details.
  ///
  /// In en, this message translates to:
  /// **'Linked Sales Order'**
  String get workOrderLinkedSalesOrder;

  /// Shown when work order has no linked sales order.
  ///
  /// In en, this message translates to:
  /// **'No linked sales order'**
  String get workOrderNoLinkedSalesOrder;

  /// Planned end date.
  ///
  /// In en, this message translates to:
  /// **'Planned finish: {date}'**
  String workOrderPlannedEnd(String date);

  /// Actual end date.
  ///
  /// In en, this message translates to:
  /// **'Actual finish: {date}'**
  String workOrderActualEnd(String date);

  /// Bill of Materials number.
  ///
  /// In en, this message translates to:
  /// **'BOM: {bom}'**
  String workOrderBomNo(String bom);

  /// WIP warehouse name.
  ///
  /// In en, this message translates to:
  /// **'WIP warehouse: {warehouse}'**
  String workOrderWipWarehouse(String warehouse);

  /// Finished goods warehouse name.
  ///
  /// In en, this message translates to:
  /// **'Finished goods warehouse: {warehouse}'**
  String workOrderFgWarehouse(String warehouse);

  /// Produced quantity against planned quantity.
  ///
  /// In en, this message translates to:
  /// **'Produced: {produced} of {qty}'**
  String workOrderProducedProgress(String produced, String qty);

  /// Section header for work order operations in work order details.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get workOrderOperationsSection;

  /// Empty state title when work order has no operations.
  ///
  /// In en, this message translates to:
  /// **'No operations'**
  String get workOrderNoOperationsTitle;

  /// Empty state body when work order has no operations.
  ///
  /// In en, this message translates to:
  /// **'This work order has no operations defined.'**
  String get workOrderNoOperationsBody;

  /// Operation sequence number badge or label.
  ///
  /// In en, this message translates to:
  /// **'Op #{sequence}'**
  String workOrderOperationSequence(int sequence);

  /// Workstation assigned to the operation.
  ///
  /// In en, this message translates to:
  /// **'Workstation: {workstation}'**
  String workOrderOperationWorkstation(String workstation);

  /// Completed quantity for the operation.
  ///
  /// In en, this message translates to:
  /// **'Completed: {qty}'**
  String workOrderOperationCompleted(String qty);

  /// Scrap or process loss quantity for the operation.
  ///
  /// In en, this message translates to:
  /// **'Scrap: {qty}'**
  String workOrderOperationScrap(String qty);

  /// Planned duration for the operation in minutes.
  ///
  /// In en, this message translates to:
  /// **'Planned: {minutes} min'**
  String workOrderOperationTime(int minutes);

  /// Work order operation pending status.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get opPending;

  /// Work order operation in progress status.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get opInProgress;

  /// Work order operation completed status.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get opCompleted;

  /// Work order operation closed status.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get opClosed;

  /// Work order operation cancelled status.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get opCancelled;

  /// Section header for warehouse balances.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Balances'**
  String get stockBalancesSection;

  /// Section header for total stock summary across warehouses.
  ///
  /// In en, this message translates to:
  /// **'Total Across Warehouses'**
  String get stockSummarySection;

  /// Label for actual physical stock.
  ///
  /// In en, this message translates to:
  /// **'Actual Stock'**
  String get stockActualQty;

  /// Label for reserved stock quantity.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get stockReservedQty;

  /// Label for projected stock quantity.
  ///
  /// In en, this message translates to:
  /// **'Projected'**
  String get stockProjectedQty;

  /// Warning badge when projected quantity is below zero.
  ///
  /// In en, this message translates to:
  /// **'Stock Deficit'**
  String get stockDeficitAlert;

  /// Title when item has no warehouse balances.
  ///
  /// In en, this message translates to:
  /// **'Not stocked anywhere'**
  String get stockNoBalancesTitle;

  /// Explanation when item has no warehouse balances.
  ///
  /// In en, this message translates to:
  /// **'This item is not currently held in any company warehouse.'**
  String get stockNoBalancesBody;

  /// Button in expanded stock card to open item details screen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get warehouseActionOpen;

  /// Title for the outbox screen.
  ///
  /// In en, this message translates to:
  /// **'Command Queue'**
  String get outboxTitle;

  /// Title when outbox queue has no pending items.
  ///
  /// In en, this message translates to:
  /// **'All commands sent'**
  String get outboxEmptyTitle;

  /// Explanation when outbox queue has no pending items.
  ///
  /// In en, this message translates to:
  /// **'There are no pending or refused commands. When offline, new actions will wait here.'**
  String get outboxEmptyBody;

  /// Heading above pending outbox command cards.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send ({count})'**
  String outboxPendingSection(int count);

  /// Heading above refused outbox command cards.
  ///
  /// In en, this message translates to:
  /// **'Refused ({count})'**
  String outboxRejectedSection(int count);

  /// Persistent banner count for refused commands awaiting acknowledgement.
  ///
  /// In en, this message translates to:
  /// **'Commands needing attention: {count}'**
  String outboxRejectedPending(int count);

  /// Acknowledges and removes one refused command card.
  ///
  /// In en, this message translates to:
  /// **'Got it, remove'**
  String get outboxDismissRejected;

  /// Acknowledges and removes every refused command card.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get outboxDismissAll;

  /// Title for queued start production command.
  ///
  /// In en, this message translates to:
  /// **'Start production for {order}'**
  String outboxCommandStartProduction(String order);

  /// Title for queued complete operation command.
  ///
  /// In en, this message translates to:
  /// **'Operation: {operation}'**
  String outboxCommandCompleteOperation(String operation);

  /// Title for queued receive receipt command.
  ///
  /// In en, this message translates to:
  /// **'Receive for {order}'**
  String outboxCommandReceiveReceipt(String order);

  /// Title for queued purchase order command.
  ///
  /// In en, this message translates to:
  /// **'Purchase order for {request}'**
  String outboxCommandCreatePurchaseOrder(String request);

  /// Title for queued create delivery command.
  ///
  /// In en, this message translates to:
  /// **'Delivery for {order}'**
  String outboxCommandCreateDelivery(String order);

  /// Fallback title for generic queued command.
  ///
  /// In en, this message translates to:
  /// **'Command: {path}'**
  String outboxCommandGeneric(String path);

  /// Parameter label for item code in outbox.
  ///
  /// In en, this message translates to:
  /// **'Item: {item}'**
  String outboxParamItem(String item);

  /// Parameter label for supplier in outbox.
  ///
  /// In en, this message translates to:
  /// **'Supplier: {supplier}'**
  String outboxParamSupplier(String supplier);

  /// Parameter label for work order in outbox.
  ///
  /// In en, this message translates to:
  /// **'Work order: {workOrder}'**
  String outboxParamWorkOrder(String workOrder);

  /// Parameter label for completed quantity in outbox.
  ///
  /// In en, this message translates to:
  /// **'Completed: {qty}'**
  String outboxParamCompletedQty(String qty);

  /// Parameter label for scrap quantity in outbox.
  ///
  /// In en, this message translates to:
  /// **'Scrap: {qty}'**
  String outboxParamScrapQty(String qty);

  /// Title for the pending outbox commands tile on Today screen.
  ///
  /// In en, this message translates to:
  /// **'Not Sent'**
  String get todayOutboxTitle;

  /// Subtitle when all outbox commands have been sent on Today screen.
  ///
  /// In en, this message translates to:
  /// **'All sent'**
  String get todayOutboxAllSent;

  /// Section header for shipments on order detail screen.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get orderDeliveriesSection;

  /// Title when no deliveries have been made for an order.
  ///
  /// In en, this message translates to:
  /// **'No shipments yet'**
  String get orderNoDeliveriesTitle;

  /// Body when no deliveries have been made for an order.
  ///
  /// In en, this message translates to:
  /// **'Deliveries will appear here when goods are shipped.'**
  String get orderNoDeliveriesBody;

  /// Title for the universal search screen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// Placeholder for search text field.
  ///
  /// In en, this message translates to:
  /// **'Order, customer, material...'**
  String get searchPlaceholder;

  /// Title when search query is empty.
  ///
  /// In en, this message translates to:
  /// **'Search across everything'**
  String get searchEmptyPromptTitle;

  /// Description when search query is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter an order number, customer name, work order, or item code.'**
  String get searchEmptyPromptBody;

  /// Title when search query yields no results.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get searchNoResultsTitle;

  /// Body when search query yields no results.
  ///
  /// In en, this message translates to:
  /// **'No results matching «{query}».'**
  String searchNoResultsBody(String query);

  /// Header for orders section in search results.
  ///
  /// In en, this message translates to:
  /// **'Orders ({count})'**
  String searchSectionOrders(int count);

  /// Header for work orders section in search results.
  ///
  /// In en, this message translates to:
  /// **'Work Orders ({count})'**
  String searchSectionWorkOrders(int count);

  /// Header for stock section in search results.
  ///
  /// In en, this message translates to:
  /// **'Stock ({count})'**
  String searchSectionStock(int count);

  /// Error message when a specific search section fails to load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load {section}'**
  String searchSectionError(String section);

  /// Tooltip for search action in top bar.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchNavTooltip;

  /// Title in detail pane when no order is selected in wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select an order'**
  String get ordersSelectPromptTitle;

  /// Message in detail pane when no order is selected in wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select an order from the list on the left to view details and production.'**
  String get ordersSelectPromptBody;

  /// Title in detail pane when no work order is selected in wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select a work order'**
  String get productionSelectPromptTitle;

  /// Message in detail pane when no work order is selected in wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select a work order from the list to view its details and operations.'**
  String get productionSelectPromptBody;

  /// Title in detail pane when no stock item is selected in wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select an item'**
  String get warehouseSelectPromptTitle;

  /// Message in detail pane when no stock item is selected in wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select an item from the list to view warehouse balances and details.'**
  String get warehouseSelectPromptBody;

  /// Action button label to complete an operation.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeOperationAction;

  /// Dialog title when reporting operation completion.
  ///
  /// In en, this message translates to:
  /// **'Complete Operation'**
  String get completeOperationTitle;

  /// Input field label for good/completed quantity.
  ///
  /// In en, this message translates to:
  /// **'Completed quantity'**
  String get completeOperationQtyLabel;

  /// Input field label for scrapped quantity.
  ///
  /// In en, this message translates to:
  /// **'Scrap quantity'**
  String get completeOperationScrapQtyLabel;

  /// Snackbar message when operation is successfully completed.
  ///
  /// In en, this message translates to:
  /// **'Operation {operation} completed'**
  String completeOperationSuccess(String operation);

  /// Message when the operation was already completed.
  ///
  /// In en, this message translates to:
  /// **'Operation is already completed'**
  String get completeOperationAlreadyComplete;

  /// Validation error message for invalid quantity input.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid non-negative number'**
  String get completeOperationInvalidQty;

  /// Title when server refuses operation completion.
  ///
  /// In en, this message translates to:
  /// **'Cannot Complete Operation'**
  String get completeOperationBlockedTitle;

  /// Action button label to create delivery note for sales order.
  ///
  /// In en, this message translates to:
  /// **'Create delivery'**
  String get ordersActionCreateDelivery;

  /// Success message when delivery note is created.
  ///
  /// In en, this message translates to:
  /// **'Delivery note {note} created'**
  String orderDeliverySuccess(String note);

  /// Message when delivery note is created for partial quantity due to warehouse availability.
  ///
  /// In en, this message translates to:
  /// **'Partial delivery {note} created for available stock'**
  String orderDeliveryAdjustedSuccess(String note);

  /// Message when order was already fully delivered.
  ///
  /// In en, this message translates to:
  /// **'Order is already delivered'**
  String get orderAlreadyDelivered;

  /// Message when nothing is ready in warehouse for shipment.
  ///
  /// In en, this message translates to:
  /// **'Nothing is in stock to deliver'**
  String get orderNothingShippable;

  /// Title when delivery creation is refused by server.
  ///
  /// In en, this message translates to:
  /// **'Cannot Create Delivery'**
  String get orderDeliveryBlockedTitle;

  /// Action button label to receive a purchase order into the warehouse.
  ///
  /// In en, this message translates to:
  /// **'Receive delivery'**
  String get warehouseActionReceive;

  /// Dialog title for receiving a purchase order.
  ///
  /// In en, this message translates to:
  /// **'Receive Delivery'**
  String get receiveDeliveryDialogTitle;

  /// Label for purchase order input field.
  ///
  /// In en, this message translates to:
  /// **'Purchase Order #'**
  String get receivePurchaseOrderFieldLabel;

  /// Hint for purchase order input field.
  ///
  /// In en, this message translates to:
  /// **'e.g. PUR-ORD-2026-00001'**
  String get receivePurchaseOrderFieldHint;

  /// Success message when purchase receipt is submitted.
  ///
  /// In en, this message translates to:
  /// **'Purchase receipt {receipt} booked'**
  String receiveSuccess(String receipt);

  /// Message when purchase order has no remaining quantities to receive.
  ///
  /// In en, this message translates to:
  /// **'All items on this purchase order are already received'**
  String get receiveNothingOutstanding;

  /// Title when receiving is refused by server.
  ///
  /// In en, this message translates to:
  /// **'Cannot Receive Delivery'**
  String get receiveBlockedTitle;

  /// Action button label to create purchase order from material request.
  ///
  /// In en, this message translates to:
  /// **'Create purchase order'**
  String get warehouseActionPurchaseOrder;

  /// Dialog title for creating purchase order.
  ///
  /// In en, this message translates to:
  /// **'Create Purchase Order'**
  String get createPurchaseOrderDialogTitle;

  /// Label for material request input field.
  ///
  /// In en, this message translates to:
  /// **'Material Request #'**
  String get materialRequestFieldLabel;

  /// Hint for material request input field.
  ///
  /// In en, this message translates to:
  /// **'e.g. MAT-MR-2026-00001'**
  String get materialRequestFieldHint;

  /// Label for optional supplier input field.
  ///
  /// In en, this message translates to:
  /// **'Supplier (optional)'**
  String get supplierFieldLabel;

  /// Success message when purchase order is created.
  ///
  /// In en, this message translates to:
  /// **'Purchase order {order} created'**
  String purchaseOrderSuccess(String order);

  /// Title when purchase order creation is refused by server.
  ///
  /// In en, this message translates to:
  /// **'Cannot Create Purchase Order'**
  String get purchaseOrderBlockedTitle;

  /// Title when no receivable purchase orders exist.
  ///
  /// In en, this message translates to:
  /// **'No deliveries pending'**
  String get receiveNoOrdersTitle;

  /// Body message when no receivable purchase orders exist.
  ///
  /// In en, this message translates to:
  /// **'All purchase orders have already been received or none are open.'**
  String get receiveNoOrdersBody;

  /// Title when no orderable material requests exist.
  ///
  /// In en, this message translates to:
  /// **'No material requests'**
  String get orderableNoRequestsTitle;

  /// Body message when no orderable material requests exist.
  ///
  /// In en, this message translates to:
  /// **'All material purchase requests have already been ordered.'**
  String get orderableNoRequestsBody;

  /// Due date for material request.
  ///
  /// In en, this message translates to:
  /// **'Needed by: {date}'**
  String materialRequestNeededDate(String date);

  /// Expected delivery date for purchase order.
  ///
  /// In en, this message translates to:
  /// **'Expected: {date}'**
  String purchaseOrderExpectedDate(String date);

  /// Title for the workstations screen.
  ///
  /// In en, this message translates to:
  /// **'Workstations'**
  String get workstationsTitle;

  /// Subtitle for the workstations screen.
  ///
  /// In en, this message translates to:
  /// **'Operation queue by workstation'**
  String get workstationsSubtitle;

  /// Title when all workstations are idle.
  ///
  /// In en, this message translates to:
  /// **'No active jobs'**
  String get workstationsEmptyTitle;

  /// Body message when all workstations are idle.
  ///
  /// In en, this message translates to:
  /// **'All workstations are idle, no unfinished operations.'**
  String get workstationsEmptyBody;

  /// Title when a selected workstation queue is empty.
  ///
  /// In en, this message translates to:
  /// **'All done at this workstation'**
  String get stationQueueEmptyTitle;

  /// Body message when a selected workstation queue is empty.
  ///
  /// In en, this message translates to:
  /// **'No pending operations waiting at this station.'**
  String get stationQueueEmptyBody;

  /// Number of operations waiting at a workstation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} operation} other{{count} operations}}'**
  String workstationWaitingCount(int count);

  /// Due date for a workstation operation.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String workstationDueOn(String date);

  /// Item/product name label.
  ///
  /// In en, this message translates to:
  /// **'Product: {item}'**
  String workstationItemLabel(String item);

  /// Quantity label for a workstation operation.
  ///
  /// In en, this message translates to:
  /// **'Quantity: {qty}'**
  String workstationQtyLabel(String qty);

  /// Planned minutes for an operation.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String workstationDuration(String minutes);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateInstall;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'KORKEM Flow Update'**
  String get updateDialogTitle;

  /// No description provided for @updateBuildLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build})'**
  String updateBuildLabel(String version, int build);

  /// No description provided for @updateNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s New:'**
  String get updateNotesTitle;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get updateDownloading;

  /// No description provided for @updateCheckButton.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheckButton;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Latest version is installed'**
  String get updateUpToDate;

  /// No description provided for @updateOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get updateOpenBrowser;

  /// No description provided for @updateInstallSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'The system installer will open after the download completes.'**
  String get updateInstallSystemPrompt;

  /// No description provided for @aiCascadeTitle.
  ///
  /// In en, this message translates to:
  /// **'Order of asking'**
  String get aiCascadeTitle;

  /// No description provided for @aiCascadeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Top down: when one runs out of quota, the next one answers.'**
  String get aiCascadeSubtitle;

  /// No description provided for @aiCascadeFree.
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get aiCascadeFree;

  /// No description provided for @memoryTitle.
  ///
  /// In en, this message translates to:
  /// **'What KORKEM Knows'**
  String get memoryTitle;

  /// No description provided for @memorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Company knowledge and your work habits'**
  String get memorySubtitle;

  /// No description provided for @memorySectionCompany.
  ///
  /// In en, this message translates to:
  /// **'About company'**
  String get memorySectionCompany;

  /// No description provided for @memorySectionUser.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get memorySectionUser;

  /// No description provided for @memoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'KORKEM hasn\'t remembered anything yet'**
  String get memoryEmptyTitle;

  /// No description provided for @memoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Knowledge about the workshop, business rules, and your preferences will appear here as the assistant learns.'**
  String get memoryEmptyBody;

  /// No description provided for @memoryEmptyCompany.
  ///
  /// In en, this message translates to:
  /// **'No company facts yet'**
  String get memoryEmptyCompany;

  /// No description provided for @memoryEmptyUser.
  ///
  /// In en, this message translates to:
  /// **'No facts about you yet'**
  String get memoryEmptyUser;

  /// No description provided for @memoryStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get memoryStatusConfirmed;

  /// No description provided for @memoryStatusUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'System inferred'**
  String get memoryStatusUnconfirmed;

  /// No description provided for @memoryActionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get memoryActionView;

  /// No description provided for @memoryActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get memoryActionEdit;

  /// No description provided for @memoryActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get memoryActionDelete;

  /// No description provided for @memoryActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get memoryActionConfirm;

  /// No description provided for @memoryActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get memoryActionSave;

  /// No description provided for @memoryEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Fact'**
  String get memoryEditDialogTitle;

  /// No description provided for @memoryEditHint.
  ///
  /// In en, this message translates to:
  /// **'Fact text'**
  String get memoryEditHint;

  /// No description provided for @memoryDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete fact?'**
  String get memoryDeleteConfirmTitle;

  /// No description provided for @memoryDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Memory is easy to delete and cannot be restored. KORKEM will stop using this fact in conversations.'**
  String get memoryDeleteConfirmBody;

  /// No description provided for @memoryFactUpdated.
  ///
  /// In en, this message translates to:
  /// **'Fact updated'**
  String get memoryFactUpdated;

  /// No description provided for @memoryFactConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Fact confirmed'**
  String get memoryFactConfirmed;

  /// No description provided for @memoryFactDeleted.
  ///
  /// In en, this message translates to:
  /// **'Fact deleted'**
  String get memoryFactDeleted;

  /// No description provided for @memorySourcePrefix.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String memorySourcePrefix(String source);

  /// No description provided for @promptBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Last prompt breakdown'**
  String get promptBreakdownTitle;

  /// No description provided for @promptBreakdownTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String promptBreakdownTokens(String count);

  /// No description provided for @promptBreakdownHeaviest.
  ///
  /// In en, this message translates to:
  /// **'heaviest'**
  String get promptBreakdownHeaviest;

  /// No description provided for @promptBreakdownEmpty.
  ///
  /// In en, this message translates to:
  /// **'No prompts yet'**
  String get promptBreakdownEmpty;

  /// No description provided for @promptBreakdownEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Token usage breakdown will appear here after the first assistant request.'**
  String get promptBreakdownEmptyBody;

  /// No description provided for @tokenCategoryInstruction.
  ///
  /// In en, this message translates to:
  /// **'System instruction'**
  String get tokenCategoryInstruction;

  /// No description provided for @tokenCategoryTools.
  ///
  /// In en, this message translates to:
  /// **'Tool schemas'**
  String get tokenCategoryTools;

  /// No description provided for @tokenCategoryCompanyMemory.
  ///
  /// In en, this message translates to:
  /// **'Company memory'**
  String get tokenCategoryCompanyMemory;

  /// No description provided for @tokenCategoryUserMemory.
  ///
  /// In en, this message translates to:
  /// **'User memory'**
  String get tokenCategoryUserMemory;

  /// No description provided for @tokenCategoryConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get tokenCategoryConversation;

  /// No description provided for @tokenCategoryOrderData.
  ///
  /// In en, this message translates to:
  /// **'Order data'**
  String get tokenCategoryOrderData;

  /// No description provided for @tokenCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get tokenCategoryOther;

  /// No description provided for @aiWeeklySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get aiWeeklySummaryTitle;

  /// No description provided for @aiWeeklyTurns.
  ///
  /// In en, this message translates to:
  /// **'Total turns'**
  String get aiWeeklyTurns;

  /// No description provided for @aiWeeklyPrimaryModel.
  ///
  /// In en, this message translates to:
  /// **'Primary model'**
  String get aiWeeklyPrimaryModel;

  /// No description provided for @aiWeeklyReserve.
  ///
  /// In en, this message translates to:
  /// **'KORKEM reserve'**
  String get aiWeeklyReserve;

  /// No description provided for @aiWeeklyAvgDuration.
  ///
  /// In en, this message translates to:
  /// **'Average duration'**
  String get aiWeeklyAvgDuration;

  /// No description provided for @aiWeeklySeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String aiWeeklySeconds(String seconds);

  /// Title of the assistant check section in AI settings
  ///
  /// In en, this message translates to:
  /// **'Assistant Quality Check'**
  String get assistantCheckTitle;

  /// Button to trigger assistant test suite run
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get assistantCheckRunButton;

  /// Label when test run is in progress
  ///
  /// In en, this message translates to:
  /// **'Running check...'**
  String get assistantCheckRunning;

  /// Title when assistant check hasn't run yet
  ///
  /// In en, this message translates to:
  /// **'Check has not been run'**
  String get assistantCheckNotRunTitle;

  /// Description explaining why to run the check
  ///
  /// In en, this message translates to:
  /// **'Run the check to verify the assistant performs correctly on typical workshop scenarios.'**
  String get assistantCheckNotRunDescription;

  /// Summary count of passed scenarios
  ///
  /// In en, this message translates to:
  /// **'Passed {passed} of {total}'**
  String assistantCheckPassedSummary(int passed, int total);

  /// Timestamp of the last run
  ///
  /// In en, this message translates to:
  /// **'last run {time}'**
  String assistantCheckLastRun(String time);

  /// Duration in seconds for scenario execution
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String assistantCheckDurationSeconds(String seconds);

  /// Notice shown when assistant check polling times out
  ///
  /// In en, this message translates to:
  /// **'The check is taking longer than usual. Please check back in a minute.'**
  String get assistantCheckTakingLonger;

  /// Title of the proactive events section
  ///
  /// In en, this message translates to:
  /// **'Noticed by KORKEM'**
  String get eventsTitle;

  /// Title shown when there are no urgent proactive events
  ///
  /// In en, this message translates to:
  /// **'Everything is under control'**
  String get eventsAllClearTitle;

  /// Description shown when there are no urgent proactive events
  ///
  /// In en, this message translates to:
  /// **'Factory is running on schedule, no urgent events.'**
  String get eventsAllClearDescription;

  /// High severity label
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get eventsSeverityHigh;

  /// Medium severity label
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get eventsSeverityMedium;

  /// Low severity label
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get eventsSeverityLow;

  /// Button label to dismiss a proactive event
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get eventsActionDismiss;

  /// No description provided for @eventsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load events'**
  String get eventsLoadFailed;

  /// Feedback message when an event is dismissed
  ///
  /// In en, this message translates to:
  /// **'Event dismissed'**
  String get eventsDismissSuccess;

  /// Title of the Materials screen
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materialsTitle;

  /// Subtitle of the Materials screen
  ///
  /// In en, this message translates to:
  /// **'Board and edge catalogue'**
  String get materialsSubtitle;

  /// Sidebar and navigation label for Materials
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get navMaterials;

  /// Chip label for board/sheet material
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get materialKindBoard;

  /// Chip label for edge band material
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get materialKindEdge;

  /// Filter option to show all materials
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get materialsFilterAll;

  /// Filter option to show only boards
  ///
  /// In en, this message translates to:
  /// **'Boards'**
  String get materialsFilterBoards;

  /// Filter option to show only edges
  ///
  /// In en, this message translates to:
  /// **'Edges'**
  String get materialsFilterEdges;

  /// Formatted thickness in millimeters
  ///
  /// In en, this message translates to:
  /// **'{thickness} mm'**
  String materialsThicknessLabel(String thickness);

  /// Sheet dimensions formatted as width × height mm
  ///
  /// In en, this message translates to:
  /// **'{width}×{height} mm'**
  String materialsFormatDimensions(int width, int height);

  /// White color family
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get materialsColorWhite;

  /// Wood color family
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get materialsColorWood;

  /// Grey color family
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get materialsColorGrey;

  /// Black color family
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get materialsColorBlack;

  /// Filter chip for 16 mm thickness
  ///
  /// In en, this message translates to:
  /// **'16 mm'**
  String get materialsFilterThickness16;

  /// Filter chip for 18 mm thickness
  ///
  /// In en, this message translates to:
  /// **'18 mm'**
  String get materialsFilterThickness18;

  /// Hint text for materials search field
  ///
  /// In en, this message translates to:
  /// **'Search by decor code, name, manufacturer'**
  String get materialsSearchHint;

  /// Empty state title when there are no materials
  ///
  /// In en, this message translates to:
  /// **'Catalogue is empty'**
  String get materialsEmptyTitle;

  /// Empty state message when there are no materials
  ///
  /// In en, this message translates to:
  /// **'Catalogue items will appear here once synchronized.'**
  String get materialsEmptyMessage;

  /// Empty state title when search or filters yield no results
  ///
  /// In en, this message translates to:
  /// **'No materials found'**
  String get materialsEmptyFilteredTitle;

  /// Empty state message when search or filters yield no results
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search terms or clearing active filters.'**
  String get materialsEmptyFilteredMessage;

  /// Title for filter sheet
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get materialsFilterTitle;

  /// Thickness section title
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get materialsFilterThickness;

  /// Color family section title
  ///
  /// In en, this message translates to:
  /// **'Color family'**
  String get materialsFilterColorFamily;

  /// Material kind filter title
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get materialsFilterKind;

  /// Active status label
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get materialsActive;

  /// Inactive status label
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get materialsInactive;

  /// Board thickness that this edge fits
  ///
  /// In en, this message translates to:
  /// **'fits {thickness} mm'**
  String materialsFitsThickness(String thickness);

  /// Width of the edge banding
  ///
  /// In en, this message translates to:
  /// **'width {width} mm'**
  String materialsEdgeWidth(String width);

  /// Title of the Hardware screen
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardwareTitle;

  /// Subtitle of the Hardware screen
  ///
  /// In en, this message translates to:
  /// **'Hinges, runners and fittings'**
  String get hardwareSubtitle;

  /// Sidebar navigation label for Hardware
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get navHardware;

  /// Filter option to show all hardware types
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get hardwareTypeAll;

  /// Filter option for hinges
  ///
  /// In en, this message translates to:
  /// **'Hinges'**
  String get hardwareTypeHinge;

  /// Filter option for runners/slides
  ///
  /// In en, this message translates to:
  /// **'Runners'**
  String get hardwareTypeRunner;

  /// Filter option for handles
  ///
  /// In en, this message translates to:
  /// **'Handles'**
  String get hardwareTypeHandle;

  /// Filter option for legs and feet
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get hardwareTypeLeg;

  /// Filter option for shelf supports
  ///
  /// In en, this message translates to:
  /// **'Shelf supports'**
  String get hardwareTypeShelfSupport;

  /// Kind chip label for hinge
  ///
  /// In en, this message translates to:
  /// **'Hinge'**
  String get hardwareKindHinge;

  /// Kind chip label for runner
  ///
  /// In en, this message translates to:
  /// **'Runner'**
  String get hardwareKindRunner;

  /// Kind chip label for handle
  ///
  /// In en, this message translates to:
  /// **'Handle'**
  String get hardwareKindHandle;

  /// Kind chip label for leg
  ///
  /// In en, this message translates to:
  /// **'Leg'**
  String get hardwareKindLeg;

  /// Kind chip label for shelf support
  ///
  /// In en, this message translates to:
  /// **'Shelf support'**
  String get hardwareKindShelfSupport;

  /// Filter option for any hinge overlay
  ///
  /// In en, this message translates to:
  /// **'Any overlay'**
  String get hardwareOverlayAll;

  /// Hinge overlay type: full
  ///
  /// In en, this message translates to:
  /// **'Full overlay'**
  String get hardwareOverlayFull;

  /// Hinge overlay type: half
  ///
  /// In en, this message translates to:
  /// **'Half overlay'**
  String get hardwareOverlayHalf;

  /// Hinge overlay type: inset
  ///
  /// In en, this message translates to:
  /// **'Inset'**
  String get hardwareOverlayInset;

  /// Explanation of full overlay hinge installation
  ///
  /// In en, this message translates to:
  /// **'Door fully overlaps the cabinet edge'**
  String get hardwareOverlayFullExplanation;

  /// Explanation of half overlay hinge installation
  ///
  /// In en, this message translates to:
  /// **'Two doors share one cabinet edge'**
  String get hardwareOverlayHalfExplanation;

  /// Explanation of inset hinge installation
  ///
  /// In en, this message translates to:
  /// **'Door sits flush inside the cabinet'**
  String get hardwareOverlayInsetExplanation;

  /// Mounting hole pattern: Austrian 45mm
  ///
  /// In en, this message translates to:
  /// **'Austrian (45 mm)'**
  String get hardwareMountingAustrian;

  /// Mounting hole pattern: Italian 48mm
  ///
  /// In en, this message translates to:
  /// **'Italian (48 mm)'**
  String get hardwareMountingItalian;

  /// Mounting hole pattern: German 52mm
  ///
  /// In en, this message translates to:
  /// **'German (52 mm)'**
  String get hardwareMountingGerman;

  /// Mounting hole pattern: Mini 38mm
  ///
  /// In en, this message translates to:
  /// **'Mini (38 mm)'**
  String get hardwareMountingMini;

  /// Hinge opening angle in degrees
  ///
  /// In en, this message translates to:
  /// **'{angle}°'**
  String hardwareOpeningAngle(String angle);

  /// Cup diameter and depth
  ///
  /// In en, this message translates to:
  /// **'Cup Ø{diameter}×{depth} mm'**
  String hardwareCupSpec(String diameter, String depth);

  /// Hinge cup diameter
  ///
  /// In en, this message translates to:
  /// **'Ø{diameter} mm'**
  String hardwareCupDiameter(String diameter);

  /// Hardware length in mm
  ///
  /// In en, this message translates to:
  /// **'{length} mm'**
  String hardwareLength(String length);

  /// Load capacity in kg
  ///
  /// In en, this message translates to:
  /// **'up to {load} kg'**
  String hardwareLoad(String load);

  /// Distance between handle mounting-hole centres
  ///
  /// In en, this message translates to:
  /// **'Hole spacing {spacing} mm'**
  String hardwareHoleSpacing(String spacing);

  /// Soft-close integrated damper label
  ///
  /// In en, this message translates to:
  /// **'Soft-close'**
  String get hardwareSoftClose;

  /// No damper
  ///
  /// In en, this message translates to:
  /// **'No soft-close'**
  String get hardwareNoSoftClose;

  /// Hint text for hardware search field
  ///
  /// In en, this message translates to:
  /// **'Search by model, brand, name'**
  String get hardwareSearchHint;

  /// Empty state title when there is no hardware
  ///
  /// In en, this message translates to:
  /// **'Hardware catalogue is empty'**
  String get hardwareEmptyTitle;

  /// Empty state message when there is no hardware
  ///
  /// In en, this message translates to:
  /// **'Hardware items will appear here once synchronized.'**
  String get hardwareEmptyMessage;

  /// Empty state title when filters match nothing
  ///
  /// In en, this message translates to:
  /// **'No hardware found'**
  String get hardwareEmptyFilteredTitle;

  /// Empty state message when filters match nothing
  ///
  /// In en, this message translates to:
  /// **'Try adjusting the hardware type, overlay, or clearing active filters.'**
  String get hardwareEmptyFilteredMessage;

  /// Settings switch: shop floor sees prices
  ///
  /// In en, this message translates to:
  /// **'Prices for the shop floor'**
  String get priceVisibilityTitle;

  /// Settings switch: shop floor sees prices
  ///
  /// In en, this message translates to:
  /// **'Let production, warehouse and drivers see client prices and order totals'**
  String get priceVisibilitySubtitle;

  /// Settings switch: shop floor sees prices
  ///
  /// In en, this message translates to:
  /// **'Could not save. Try again.'**
  String get priceVisibilitySaveFailed;

  /// Optional defect photo when completing a stage
  ///
  /// In en, this message translates to:
  /// **'Defect photo (optional)'**
  String get defectPhotoAdd;

  /// Optional defect photo when completing a stage
  ///
  /// In en, this message translates to:
  /// **'Photo attached'**
  String get defectPhotoChosen;

  /// Optional defect photo when completing a stage
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get defectPhotoRemove;

  /// Optional defect photo when completing a stage
  ///
  /// In en, this message translates to:
  /// **'The stage is recorded, but the defect photo was not sent.'**
  String get defectPhotoNotSent;

  /// Optional defect photo when completing a stage
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera.'**
  String get defectPhotoCameraFailed;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Facade prices'**
  String get facadePricesTitle;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Price per m² by milling and finish'**
  String get facadePricesSubtitle;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Add milling'**
  String get facadePricesAddMilling;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Milling'**
  String get facadePricesMilling;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get facadePricesFinish;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Price per m²'**
  String get facadePricesPricePerM2;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get facadePricesSold;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Not sold'**
  String get facadePricesNotSold;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Price saved'**
  String get facadePricesSaved;

  /// Facade price matrix settings
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get facadePricesSave;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Facade order calculation'**
  String get facadeQuoteTitle;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Add facade'**
  String get facadeQuoteAddLine;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Demolition'**
  String get facadeQuoteDemolition;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Prepayment (if different)'**
  String get facadeQuotePrepaymentManual;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'By default {percent}% of the total'**
  String facadeQuotePrepaymentDefault(String percent);

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get facadeQuoteCalculate;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get facadeQuoteNumberRequired;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Facade {number}'**
  String facadeQuoteLine(int number);

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get facadeQuoteRemoveLine;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Width, mm'**
  String get facadeQuoteWidth;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Height, mm'**
  String get facadeQuoteHeight;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Pcs'**
  String get facadeQuoteQty;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Double-sided'**
  String get facadeQuoteDoubleSided;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Customer\'s material'**
  String get facadeQuoteCustomerMaterial;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get facadeQuotePieces;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get facadeQuoteArea;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get facadeQuoteTotal;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Prepayment'**
  String get facadeQuotePrepayment;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get facadeQuoteBalance;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Not offered'**
  String get facadeRulesNotOffered;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Order rules'**
  String get facadeRulesTitle;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Double-sided factor (×)'**
  String get facadeRulesDoubleSidedFactor;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Empty — not offered'**
  String get facadeRulesEmptyMeansOff;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Discount for customer\'s material'**
  String get facadeRulesDiscount;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Demolition price'**
  String get facadeRulesDemolitionRate;

  /// Facade order calculation
  ///
  /// In en, this message translates to:
  /// **'Prepayment by default'**
  String get facadeRulesPrepayment;

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'Place the order'**
  String get facadeOrderSection;

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'Choose a customer'**
  String get facadeOrderPickCustomer;

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'Name — press Enter'**
  String get facadeOrderSearchCustomer;

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get facadeOrderNoCustomers;

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'Choose the due date'**
  String get facadeOrderPickDate;

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String facadeOrderDueOn(String date);

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'Create order'**
  String get facadeOrderCreate;

  /// Facade order from a quote
  ///
  /// In en, this message translates to:
  /// **'Order {name} created'**
  String facadeOrderCreated(String name);

  /// Agreed prepayment not yet received
  ///
  /// In en, this message translates to:
  /// **'Prepayment due: {amount}'**
  String orderPrepaymentDue(String amount);

  /// Shop-floor facade list
  ///
  /// In en, this message translates to:
  /// **'Facades to make'**
  String get facadeJobsTitle;

  /// Shop-floor facade list
  ///
  /// In en, this message translates to:
  /// **'No facades to make'**
  String get facadeJobsEmptyTitle;

  /// Shop-floor facade list
  ///
  /// In en, this message translates to:
  /// **'Facades appear here once an order is placed.'**
  String get facadeJobsEmptyMessage;

  /// Shop-floor facade list
  ///
  /// In en, this message translates to:
  /// **'due {date}'**
  String facadeJobsDue(String date);

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Piece work'**
  String get pieceWorkTitle;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get pieceWorkMine;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Nothing accrued yet'**
  String get pieceWorkNothingYet;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get pieceWorkPending;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get pieceWorkApproved;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get pieceWorkPaid;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get pieceWorkRejected;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get pieceWorkPcs;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'To approve'**
  String get pieceWorkToApprove;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Nothing to approve'**
  String get pieceWorkNothingToApprove;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get pieceWorkApprove;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get pieceWorkReject;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Reason — the worker will see it'**
  String get pieceWorkReason;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get pieceWorkRates;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Add a rate'**
  String get pieceWorkAddRate;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get pieceWorkDisabled;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Overtime and weekends'**
  String get pieceWorkCoefficients;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Overtime'**
  String get pieceWorkOvertime;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get pieceWorkWeekend;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'after'**
  String get pieceWorkAfter;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'as usual'**
  String get pieceWorkNoCoefficient;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get pieceWorkOperation;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'As named in the shop, or «Фасад» for finished facades'**
  String get pieceWorkOperationHint;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'per piece'**
  String get pieceWorkPerPiece;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get pieceWorkRate;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get pieceWorkEnabled;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Shift ends at (HH:MM)'**
  String get pieceWorkShiftEnd;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Saturday is a day off'**
  String get pieceWorkSaturdayOff;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Sunday is a day off'**
  String get pieceWorkSundayOff;

  /// Piece-rate pay
  ///
  /// In en, this message translates to:
  /// **'Piece rate: ~{amount}'**
  String pieceWorkEstimate(String amount);

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Urgent expenses'**
  String get expensesTitle;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Add an expense'**
  String get expensesAdd;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Awaiting a decision'**
  String get expensesPendingTotal;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'No expenses'**
  String get expensesEmptyTitle;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Spent money on the job? Write it down here, with the receipt.'**
  String get expensesEmptyMessage;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Expense recorded'**
  String get expensesFiled;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Recorded, but the receipt photo was not sent.'**
  String get expensesReceiptNotSent;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expensesAmount;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get expensesPurpose;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expensesCategory;

  /// Urgent expenses
  ///
  /// In en, this message translates to:
  /// **'Photo of the receipt'**
  String get expensesReceipt;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'PIN sign-in'**
  String get pinAdminTitle;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Shop-floor tablets and who signs in on them'**
  String get pinAdminSubtitle;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Tablets'**
  String get pinAdminTablets;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Make this device a PIN tablet'**
  String get pinAdminRegisterThis;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'This device: {label}'**
  String pinAdminThisIs(String label);

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Switched off'**
  String get pinAdminRevoked;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Switch off'**
  String get pinAdminRevoke;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'People with a PIN'**
  String get pinAdminPeople;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Locked after wrong attempts'**
  String get pinAdminLocked;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get pinAdminClear;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Assign a PIN'**
  String get pinAdminAssign;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Tablet name, e.g. «Shop, cutting»'**
  String get pinAdminTabletName;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Tablet registered'**
  String get pinAdminRegistered;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get pinAdminChoosePerson;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'PIN, 4 to 6 digits'**
  String get pinAdminNewPin;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'PIN assigned'**
  String get pinAdminPinSet;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Sign in with PIN'**
  String get pinLoginTitle;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Choose yourself and enter your PIN'**
  String get pinLoginSubtitle;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'This tablet is not set up for PINs'**
  String get pinLoginUnavailableTitle;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'Ask the administrator to register it in Settings.'**
  String get pinLoginUnavailableMessage;

  /// PIN sign-in on shop-floor tablets
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLoginPin;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materialStockTitle;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'On hand'**
  String get materialStockOnHand;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get materialStockReceive;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get materialStockLists;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Nothing in stock yet'**
  String get materialStockEmptyTitle;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Purchases appear here once they are received.'**
  String get materialStockEmptyMessage;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Average price {price}'**
  String materialStockAverage(String price);

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Fill in every field.'**
  String get materialStockFillAll;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'{title}: received, now {onHand}'**
  String materialStockReceived(String title, String onHand);

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Material name'**
  String get materialStockName;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Bought from'**
  String get materialStockSupplier;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'How many'**
  String get materialStockQty;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get materialStockUnit;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Price per unit'**
  String get materialStockPrice;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get materialStockSuppliers;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get materialStockAdd;

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'«{value}» added'**
  String materialStockAdded(String value);

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'{value} (off)'**
  String materialStockOff(String value);

  /// Materials store
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materialStockOpen;

  /// Order list filter: both lines of business.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get directionAll;

  /// No description provided for @directionFurniture.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get directionFurniture;

  /// No description provided for @directionFacades.
  ///
  /// In en, this message translates to:
  /// **'Facades'**
  String get directionFacades;

  /// Badge on an urgent order.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get orderUrgent;

  /// No description provided for @tierNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get tierNew;

  /// No description provided for @tierRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get tierRegular;

  /// No description provided for @tierVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get tierVip;

  /// No description provided for @facadeSpecTitle.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get facadeSpecTitle;

  /// No description provided for @facadeSpecThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness, mm'**
  String get facadeSpecThickness;

  /// No description provided for @facadeSpecDecorTop.
  ///
  /// In en, this message translates to:
  /// **'Face decor'**
  String get facadeSpecDecorTop;

  /// No description provided for @facadeSpecDecorBottom.
  ///
  /// In en, this message translates to:
  /// **'Back decor'**
  String get facadeSpecDecorBottom;

  /// No description provided for @facadeSpecEdge.
  ///
  /// In en, this message translates to:
  /// **'Edge profile'**
  String get facadeSpecEdge;

  /// No description provided for @facadeSpecNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get facadeSpecNone;

  /// Colour group of a facade position.
  ///
  /// In en, this message translates to:
  /// **'group “{group}”'**
  String facadeSpecGroup(String group);

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'On hand {onHand} · reserved {reserved}'**
  String materialStockHeld(String onHand, String reserved);

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'{qty} free'**
  String materialStockFree(String qty);

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'Materials for the order'**
  String get facadeMaterialsTitle;

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'need {needed} · held {held} · written off {issued}'**
  String facadeMaterialsLine(String needed, String held, String issued);

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'short {qty}'**
  String facadeMaterialsShort(String qty);

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'All held'**
  String get facadeMaterialsHeld;

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'Reserve what is free'**
  String get facadeMaterialsReserve;

  /// Warehouse reservations (package 5)
  ///
  /// In en, this message translates to:
  /// **'Nothing needed from the warehouse'**
  String get facadeMaterialsEmpty;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Who made it?'**
  String get crewTitle;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Tick the crew. Shares in % are optional — empty means equal.'**
  String get crewHint;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'A crew is at least two people.'**
  String get crewTooSmall;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Give everyone a share — or no one, for equal shares.'**
  String get crewSharesAllOrNone;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get crewDone;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Done — made together…'**
  String get crewDoneTogether;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Pay sheet'**
  String get payrollTitle;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Copy for accounting (CSV)'**
  String get payrollCopyCsv;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Pay sheet copied — paste it into Excel'**
  String get payrollCsvCopied;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get payrollPrevMonth;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get payrollNextMonth;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Nothing accrued this month'**
  String get payrollEmpty;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Total to pay'**
  String get payrollTotal;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Piece work'**
  String get payrollPiece;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Daily bonuses'**
  String get payrollDailyBonus;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Monthly bonus'**
  String get payrollMonthlyBonus;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get payrollBonus;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Fines'**
  String get payrollFine;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Advances'**
  String get payrollAdvance;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Not yet approved: {amount}'**
  String payrollPending(String amount);

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Advances, fines, bonuses'**
  String get payrollAdjustments;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get payrollAddAdjustment;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'None this month'**
  String get payrollNoAdjustments;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get payrollReverse;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get payrollEmployee;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get payrollAmount;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get payrollReason;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Today\'s bonus'**
  String get bonusToday;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'This month\'s bonus'**
  String get bonusMonth;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Reached — bonus {bonus}'**
  String bonusReached(String bonus);

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'{left} to go for {bonus}'**
  String bonusLeft(String left, String bonus);

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Bonuses'**
  String get bonusRules;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'From {threshold} a day — {bonus}'**
  String bonusRuleDay(String threshold, String bonus);

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'From {threshold} a month — {bonus}'**
  String bonusRuleMonth(String threshold, String bonus);

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Daily threshold'**
  String get bonusDayThreshold;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Daily bonus'**
  String get bonusDayAmount;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Monthly threshold'**
  String get bonusMonthThreshold;

  /// Payroll (package 6)
  ///
  /// In en, this message translates to:
  /// **'Monthly bonus'**
  String get bonusMonthAmount;

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'In %'**
  String get crewSplitPercent;

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Who made how much, {unit}'**
  String crewSplitByAmount(String unit);

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Tick the crew and enter how much each made. The amounts must add up to the total.'**
  String get crewHintAmount;

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Made together…'**
  String get crewMadeTogether;

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Crew: {count} people'**
  String crewChosen(int count);

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Remove the crew'**
  String get crewClear;

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get unitPieces;

  /// Crews on stages (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'m²'**
  String get unitSquareMetres;

  /// Payouts (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get payrollPaid;

  /// Payouts (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Left to pay'**
  String get payrollLeft;

  /// Payouts (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get payrollMarkPaid;

  /// Payouts (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'{name}: paid {amount}? The period closes — no more advances, fines or bonuses can be entered for it.'**
  String payrollMarkPaidConfirm(String name, String amount);

  /// Payouts (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Payout recorded'**
  String get payrollMarkPaidDone;

  /// Payouts (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Left to pay in total'**
  String get payrollTotalLeft;

  /// Shop trades (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Shop trades'**
  String get tradesAction;

  /// Shop trades (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'What they do'**
  String get tradesTitle;

  /// Shop trades (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Several are fine. Trades give no rights — the position does.'**
  String get tradesHint;

  /// Shop trades (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Your own trade'**
  String get tradesOwn;

  /// Shop trades (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tradesAdd;

  /// Shop trades (package 6, part 2)
  ///
  /// In en, this message translates to:
  /// **'Trades saved'**
  String get tradesSaved;

  /// Exchange with 1C
  ///
  /// In en, this message translates to:
  /// **'Exchange with 1C'**
  String get oneCTitle;

  /// Exchange with 1C
  ///
  /// In en, this message translates to:
  /// **'Sales, payments, receipts and pay sheet for accounting'**
  String get oneCSubtitle;

  /// Exchange with 1C
  ///
  /// In en, this message translates to:
  /// **'Exchange with 1C is on'**
  String get oneCEnabled;

  /// Exchange with 1C
  ///
  /// In en, this message translates to:
  /// **'Exchange is off. If the company keeps no 1C, leave it so.'**
  String get oneCOffHint;

  /// Exchange with 1C
  ///
  /// In en, this message translates to:
  /// **'In 1C: «Load data from a spreadsheet» — paste what you copied. Dates DD.MM.YYYY, decimal comma.'**
  String get oneCHowTo;

  /// Exchange with 1C
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get oneCCopy;

  /// Exchange with 1C
  ///
  /// In en, this message translates to:
  /// **'{title}: {count} rows. Paste into 1C.'**
  String oneCCopied(String title, int count);

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Press layout'**
  String get pressLayoutTitle;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'TEXTURED — DO NOT TURN'**
  String get pressTextured;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Plain — may be turned'**
  String get pressPlain;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Load {count} · section {metres} m'**
  String pressLoad(int count, String metres);

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Film: {metres} m'**
  String pressFilmTotal(String metres);

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Corrected by hand: {reason}. Layout says {metres} m.'**
  String pressCorrected(String reason, String metres);

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Larger than the press table: lines {positions}'**
  String pressTooBig(String positions);

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Correct the metres'**
  String get pressCorrect;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Film, metres'**
  String get pressMetres;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Why not as laid out'**
  String get pressReason;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Back to the layout'**
  String get pressBackToLayout;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'The order has no PVC-film facades.'**
  String get pressNoFilm;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Press: area, gap, sections'**
  String get pressSettingsTitle;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Working length, mm'**
  String get pressLength;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Working width, mm'**
  String get pressWidth;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Margin at the edge, mm'**
  String get pressMargin;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Gap between parts, mm'**
  String get pressGap;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Sections: film and working length'**
  String get pressSections;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Film, m'**
  String get pressSectionFilm;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Add a section'**
  String get pressAddSection;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Press settings saved'**
  String get pressSaved;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Textured film'**
  String get materialTextured;

  /// Press layout
  ///
  /// In en, this message translates to:
  /// **'Parts are not turned on the press; the map says «DO NOT TURN»'**
  String get materialTexturedHint;

  /// Press layout print
  ///
  /// In en, this message translates to:
  /// **'Print the layout'**
  String get pressPrint;

  /// Press layout print
  ///
  /// In en, this message translates to:
  /// **'Load {count} of {total} · section {metres} m'**
  String pressPrintLoad(int count, int total, String metres);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Sheet {count}'**
  String pressPrintSheet(int count);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Copies: {count}'**
  String pressPrintCopies(int count);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Size: {size} mm'**
  String pressPrintSize(String size);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Film section: {metres} m'**
  String pressPrintSection(String metres);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Sheet area: {area} m²'**
  String pressPrintArea(String area);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Parts: {area} m² ({share}%)'**
  String pressPrintParts(String area, String share);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Waste: {area} m² ({share}%)'**
  String pressPrintWaste(String area, String share);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Parts: {count}'**
  String pressPrintCount(int count);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Parts perimeter: {metres} m'**
  String pressPrintPerimeter(String metres);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Gap: {gap} mm · margin: {margin} mm'**
  String pressPrintGap(String gap, String margin);

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get pressPrintDetails;

  /// Press layout print, two loads a page
  ///
  /// In en, this message translates to:
  /// **'Page {count}'**
  String pressPrintPage(int count);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Logistics'**
  String get logisticsTitle;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get logisticsDeliveries;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get logisticsSummary;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Record a delivery'**
  String get logisticsAdd;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'No deliveries this month'**
  String get logisticsEmpty;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'A van, a taxi, a transport company — write down what bringing the material cost.'**
  String get logisticsEmptyMessage;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Delivery cost'**
  String get logisticsAmount;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'From (city)'**
  String get logisticsFrom;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Delivered by'**
  String get logisticsTransport;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Carrier (optional)'**
  String get logisticsCarrier;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'What came'**
  String get logisticsWhat;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get logisticsQty;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get logisticsUnit;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Order № (if for an order)'**
  String get logisticsOrder;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get logisticsOrderedOn;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get logisticsDeliveredOn;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Urgent (paid extra for speed)'**
  String get logisticsUrgent;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get logisticsNote;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Delivery recorded'**
  String get logisticsSaved;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Cancel the record'**
  String get logisticsCancel;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Why cancel'**
  String get logisticsCancelReason;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Cancelled: {reason}'**
  String logisticsCancelled(String reason);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'{count} days on the road'**
  String logisticsDays(int count);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'This month: {amount}'**
  String logisticsTotal(String amount);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Last month: {amount}'**
  String logisticsPrevious(String amount);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'By material'**
  String get logisticsByCategory;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'By city'**
  String get logisticsByCity;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'By way of delivery'**
  String get logisticsByTransport;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'By carrier'**
  String get logisticsByCarrier;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Per unit'**
  String get logisticsPerUnit;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'{amount} per {unit} · {qty} {unit} delivered'**
  String logisticsPerUnitLine(String amount, String unit, String qty);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'deliveries: {count}'**
  String logisticsCount(int count);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'{days} days on the road on average'**
  String logisticsAverageDays(String days);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Urgent: {count} for {amount}'**
  String logisticsUrgentLine(int count, String amount);

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Receipts without a delivery'**
  String get logisticsUnlinked;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'The material came but its delivery was not written down. Write it — or 0 ₸ if the supplier brought it.'**
  String get logisticsUnlinkedHint;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get logisticsWrite;

  /// Logistics: deliveries kept apart from material
  ///
  /// In en, this message translates to:
  /// **'Delivery (if paid for)'**
  String get logisticsDeliveryOptional;

  /// Material stock: minimum and low warning
  ///
  /// In en, this message translates to:
  /// **'Minimum on hand'**
  String get materialMin;

  /// Material stock: minimum and low warning
  ///
  /// In en, this message translates to:
  /// **'When free stock drops below it, the owner is told to order more. Empty or 0 — no warning.'**
  String get materialMinHint;

  /// Material stock: minimum and low warning
  ///
  /// In en, this message translates to:
  /// **'Low — minimum {minimum}'**
  String materialLow(String minimum);

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get stockCountTab;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'What is on the shelf now'**
  String get stockCountTitle;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Type what you counted. Empty rows are left alone. Differences from the books are posted as one document, and the month\'s usage is counted from this figure.'**
  String get stockCountHint;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'In the books: {qty}'**
  String stockCountBooks(String qty);

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'on shelf'**
  String get stockCountOnShelf;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Save the count'**
  String get stockCountSave;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Nothing entered.'**
  String get stockCountNothing;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Count saved, differences: {count}'**
  String stockCountSaved(int count);

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'The month\'s usage'**
  String get stockUsageTitle;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Not counted this month yet — «left» is still from the books.'**
  String get stockUsageNotCounted;

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Counted on {date}'**
  String stockUsageCountedOn(String date);

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Start {start} · bought {bought} · left {end} {unit}'**
  String stockUsageLine(String start, String bought, String end, String unit);

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Used in fact {used}, by orders {orders}'**
  String stockUsageUsed(String used, String orders);

  /// Stock count and the month's usage
  ///
  /// In en, this message translates to:
  /// **'Unaccounted: {qty}{money}'**
  String stockUsageLoss(String qty, String money);

  /// No description provided for @navMdf.
  ///
  /// In en, this message translates to:
  /// **'MDF'**
  String get navMdf;

  /// No description provided for @mdfOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get mdfOrders;

  /// No description provided for @mdfOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'All orders: due dates, payments, debt'**
  String get mdfOrdersHint;

  /// No description provided for @mdfQuoteHint.
  ///
  /// In en, this message translates to:
  /// **'Lines, m², price — and the order'**
  String get mdfQuoteHint;

  /// No description provided for @mdfJobsHint.
  ///
  /// In en, this message translates to:
  /// **'Queued, in work, done'**
  String get mdfJobsHint;

  /// No description provided for @mdfPress.
  ///
  /// In en, this message translates to:
  /// **'Press'**
  String get mdfPress;

  /// No description provided for @mdfPressHint.
  ///
  /// In en, this message translates to:
  /// **'Table and section sizes; the layout opens from an order'**
  String get mdfPressHint;

  /// No description provided for @mdfStockHint.
  ///
  /// In en, this message translates to:
  /// **'MDF and film: on hand, low, month-end count'**
  String get mdfStockHint;

  /// No description provided for @mdfLogisticsHint.
  ///
  /// In en, this message translates to:
  /// **'MDF and film deliveries and their cost'**
  String get mdfLogisticsHint;

  /// No description provided for @mdfPricesHint.
  ///
  /// In en, this message translates to:
  /// **'Price per m² by milling and finish'**
  String get mdfPricesHint;

  /// No description provided for @materialsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add material'**
  String get materialsAdd;

  /// No description provided for @materialsName.
  ///
  /// In en, this message translates to:
  /// **'Material name'**
  String get materialsName;

  /// No description provided for @materialsManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get materialsManufacturer;

  /// No description provided for @materialsDecorCode.
  ///
  /// In en, this message translates to:
  /// **'Decor code'**
  String get materialsDecorCode;

  /// No description provided for @materialsThicknessInput.
  ///
  /// In en, this message translates to:
  /// **'Thickness, mm'**
  String get materialsThicknessInput;

  /// No description provided for @materialsSheetWidthInput.
  ///
  /// In en, this message translates to:
  /// **'Sheet width, mm'**
  String get materialsSheetWidthInput;

  /// No description provided for @materialsSheetHeightInput.
  ///
  /// In en, this message translates to:
  /// **'Sheet height, mm'**
  String get materialsSheetHeightInput;

  /// No description provided for @materialsEdgeWidthInput.
  ///
  /// In en, this message translates to:
  /// **'Edge width, mm'**
  String get materialsEdgeWidthInput;

  /// No description provided for @materialsFitsThicknessInput.
  ///
  /// In en, this message translates to:
  /// **'For board thickness, mm'**
  String get materialsFitsThicknessInput;

  /// No description provided for @materialsPositiveDimension.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get materialsPositiveDimension;

  /// No description provided for @materialsCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Material added'**
  String get materialsCreateSuccess;

  /// No description provided for @materialsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get materialsSave;

  /// No description provided for @facadePricesEmptyNotSold.
  ///
  /// In en, this message translates to:
  /// **'Empty — not sold'**
  String get facadePricesEmptyNotSold;

  /// No description provided for @facadePricesNeedOne.
  ///
  /// In en, this message translates to:
  /// **'Enter a price for at least one finish.'**
  String get facadePricesNeedOne;

  /// No description provided for @mdfOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'MDF orders'**
  String get mdfOrdersTitle;

  /// No description provided for @mdfOrderNew.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get mdfOrderNew;

  /// No description provided for @mdfOrderSearch.
  ///
  /// In en, this message translates to:
  /// **'No., customer, phone, colour'**
  String get mdfOrderSearch;

  /// No description provided for @mdfFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mdfFilterAll;

  /// No description provided for @mdfFilterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get mdfFilterOverdue;

  /// No description provided for @mdfFilterDebt.
  ///
  /// In en, this message translates to:
  /// **'With debt'**
  String get mdfFilterDebt;

  /// No description provided for @mdfStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get mdfStatusDraft;

  /// No description provided for @mdfStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get mdfStatusAccepted;

  /// No description provided for @mdfStatusInShop.
  ///
  /// In en, this message translates to:
  /// **'In the shop'**
  String get mdfStatusInShop;

  /// No description provided for @mdfStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get mdfStatusReady;

  /// No description provided for @mdfStatusHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get mdfStatusHandedOver;

  /// No description provided for @mdfStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get mdfStatusOnHold;

  /// No description provided for @mdfStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get mdfStatusCancelled;

  /// No description provided for @mdfStageCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get mdfStageCut;

  /// No description provided for @mdfStageMill.
  ///
  /// In en, this message translates to:
  /// **'Milling'**
  String get mdfStageMill;

  /// No description provided for @mdfStageSand.
  ///
  /// In en, this message translates to:
  /// **'Sanding'**
  String get mdfStageSand;

  /// No description provided for @mdfStageVacuum.
  ///
  /// In en, this message translates to:
  /// **'Vacuum'**
  String get mdfStageVacuum;

  /// No description provided for @mdfStagePaint.
  ///
  /// In en, this message translates to:
  /// **'Painting'**
  String get mdfStagePaint;

  /// No description provided for @mdfEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get mdfEmpty;

  /// No description provided for @mdfEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap «New order» to write the first one.'**
  String get mdfEmptyHint;

  /// No description provided for @mdfDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt {amount}'**
  String mdfDebt(String amount);

  /// No description provided for @mdfCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get mdfCustomer;

  /// No description provided for @mdfDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get mdfDue;

  /// No description provided for @mdfHeadSection.
  ///
  /// In en, this message translates to:
  /// **'Facade'**
  String get mdfHeadSection;

  /// No description provided for @mdfThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness, mm'**
  String get mdfThickness;

  /// No description provided for @mdfFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get mdfFinish;

  /// No description provided for @mdfDecorTop.
  ///
  /// In en, this message translates to:
  /// **'Face decor'**
  String get mdfDecorTop;

  /// No description provided for @mdfDecorBottom.
  ///
  /// In en, this message translates to:
  /// **'Back decor'**
  String get mdfDecorBottom;

  /// No description provided for @mdfPatina.
  ///
  /// In en, this message translates to:
  /// **'Patina'**
  String get mdfPatina;

  /// No description provided for @mdfMilling.
  ///
  /// In en, this message translates to:
  /// **'Milling'**
  String get mdfMilling;

  /// No description provided for @mdfEdge.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get mdfEdge;

  /// No description provided for @mdfExtraName.
  ///
  /// In en, this message translates to:
  /// **'Extra name'**
  String get mdfExtraName;

  /// No description provided for @mdfDefaultRate.
  ///
  /// In en, this message translates to:
  /// **'Default price per m²'**
  String get mdfDefaultRate;

  /// No description provided for @mdfNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get mdfNone;

  /// No description provided for @mdfLinesSection.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get mdfLinesSection;

  /// No description provided for @mdfHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get mdfHeight;

  /// No description provided for @mdfWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get mdfWidth;

  /// No description provided for @mdfQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get mdfQty;

  /// No description provided for @mdfNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get mdfNote;

  /// No description provided for @mdfRate.
  ///
  /// In en, this message translates to:
  /// **'Price m²'**
  String get mdfRate;

  /// No description provided for @mdfArea.
  ///
  /// In en, this message translates to:
  /// **'m²'**
  String get mdfArea;

  /// No description provided for @mdfAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get mdfAmount;

  /// No description provided for @mdfAddLine.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get mdfAddLine;

  /// No description provided for @mdfNoPrice.
  ///
  /// In en, this message translates to:
  /// **'no price'**
  String get mdfNoPrice;

  /// No description provided for @mdfManualRate.
  ///
  /// In en, this message translates to:
  /// **'price by hand'**
  String get mdfManualRate;

  /// No description provided for @mdfTotals.
  ///
  /// In en, this message translates to:
  /// **'{pieces} pcs · {area} m² · {total}'**
  String mdfTotals(String pieces, String area, String total);

  /// No description provided for @mdfPaidDebt.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} · Debt {debt}'**
  String mdfPaidDebt(String paid, String debt);

  /// No description provided for @mdfSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mdfSaveDraft;

  /// No description provided for @mdfAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept the order'**
  String get mdfAccept;

  /// No description provided for @mdfDeleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get mdfDeleteDraft;

  /// No description provided for @mdfSaved.
  ///
  /// In en, this message translates to:
  /// **'Order saved'**
  String get mdfSaved;

  /// No description provided for @mdfAccepted.
  ///
  /// In en, this message translates to:
  /// **'Order accepted — prices fixed'**
  String get mdfAccepted;

  /// No description provided for @mdfNeedCustomer.
  ///
  /// In en, this message translates to:
  /// **'Pick the customer and the due date.'**
  String get mdfNeedCustomer;

  /// No description provided for @mdfNeedLine.
  ///
  /// In en, this message translates to:
  /// **'Add at least one line.'**
  String get mdfNeedLine;

  /// No description provided for @mdfStagesSection.
  ///
  /// In en, this message translates to:
  /// **'Stages'**
  String get mdfStagesSection;

  /// No description provided for @mdfPaymentsSection.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get mdfPaymentsSection;

  /// No description provided for @mdfAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Add payment'**
  String get mdfAddPayment;

  /// No description provided for @mdfPaymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount, ₸'**
  String get mdfPaymentAmount;

  /// No description provided for @mdfPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get mdfPaymentMethod;

  /// No description provided for @mdfNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get mdfNoPayments;

  /// No description provided for @mdfHold.
  ///
  /// In en, this message translates to:
  /// **'Put on hold'**
  String get mdfHold;

  /// No description provided for @mdfResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get mdfResume;

  /// No description provided for @mdfHoldReason.
  ///
  /// In en, this message translates to:
  /// **'Why on hold'**
  String get mdfHoldReason;

  /// No description provided for @mdfCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get mdfCancelOrder;

  /// No description provided for @mdfCancelReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get mdfCancelReason;

  /// No description provided for @mdfHandOver.
  ///
  /// In en, this message translates to:
  /// **'Hand over'**
  String get mdfHandOver;

  /// No description provided for @mdfHandOverComment.
  ///
  /// In en, this message translates to:
  /// **'Why hand over with a debt'**
  String get mdfHandOverComment;

  /// No description provided for @mdfOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get mdfOverdue;

  /// No description provided for @mdfDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get mdfDueSoon;

  /// No description provided for @mdfConfirm.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get mdfConfirm;

  /// No description provided for @mdfCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mdfCancel;

  /// No description provided for @mdfLineDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete line'**
  String get mdfLineDelete;

  /// No description provided for @mdfLineDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get mdfLineDuplicate;

  /// No description provided for @mdfChangeAccepted.
  ///
  /// In en, this message translates to:
  /// **'An accepted order changes through «Change order» — coming.'**
  String get mdfChangeAccepted;

  /// No description provided for @mdfPrintTitle.
  ///
  /// In en, this message translates to:
  /// **'Order No. {name}'**
  String mdfPrintTitle(String name);

  /// No description provided for @mdfPrintAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get mdfPrintAccepted;

  /// No description provided for @mdfPrintPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get mdfPrintPhone;

  /// No description provided for @mdfPrintPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get mdfPrintPaid;

  /// No description provided for @mdfPrintDebt.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get mdfPrintDebt;

  /// No description provided for @mdfPrintTotal.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get mdfPrintTotal;

  /// No description provided for @mdfPrintClient.
  ///
  /// In en, this message translates to:
  /// **'Customer copy'**
  String get mdfPrintClient;

  /// No description provided for @mdfPrintShop.
  ///
  /// In en, this message translates to:
  /// **'Shop copy'**
  String get mdfPrintShop;

  /// No description provided for @mdfPasteSizes.
  ///
  /// In en, this message translates to:
  /// **'Paste sizes'**
  String get mdfPasteSizes;

  /// No description provided for @mdfPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Copy sizes from WhatsApp, Excel or a form — one part per line: «348 997 2», «348x997-2pcs». Words after the count become the note.'**
  String get mdfPasteHint;

  /// No description provided for @mdfPasteFound.
  ///
  /// In en, this message translates to:
  /// **'Lines found: {count}'**
  String mdfPasteFound(int count);

  /// No description provided for @mdfPasteSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped (not sizes): {rows}'**
  String mdfPasteSkipped(String rows);

  /// No description provided for @mdfPasteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to the order'**
  String get mdfPasteAdd;

  /// No description provided for @mdfPasted.
  ///
  /// In en, this message translates to:
  /// **'Lines added: {count}'**
  String mdfPasted(int count);

  /// No description provided for @mdfNewCustomer.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get mdfNewCustomer;

  /// No description provided for @mdfNewCustomerOption.
  ///
  /// In en, this message translates to:
  /// **'+ New customer «{name}»'**
  String mdfNewCustomerOption(String name);

  /// No description provided for @mdfRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat order'**
  String get mdfRepeat;

  /// No description provided for @filmShortageTitle.
  ///
  /// In en, this message translates to:
  /// **'Film to buy'**
  String get filmShortageTitle;

  /// No description provided for @filmShortageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No film needed for orders'**
  String get filmShortageEmpty;

  /// No description provided for @filmShortageEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Accepted film orders show here until the vacuum is ticked.'**
  String get filmShortageEmptyHint;

  /// No description provided for @filmShortageTotals.
  ///
  /// In en, this message translates to:
  /// **'Needed {needed} m · to buy {toBuy} m'**
  String filmShortageTotals(String needed, String toBuy);

  /// No description provided for @filmShortageByFilm.
  ///
  /// In en, this message translates to:
  /// **'By film'**
  String get filmShortageByFilm;

  /// No description provided for @filmShortageByOrder.
  ///
  /// In en, this message translates to:
  /// **'By order'**
  String get filmShortageByOrder;

  /// No description provided for @filmShortageLine.
  ///
  /// In en, this message translates to:
  /// **'{orders} orders · needed {needed} · held {held} · free {free} {unit}'**
  String filmShortageLine(
    String orders,
    String needed,
    String held,
    String free,
    String unit,
  );

  /// No description provided for @filmShortageBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy {qty} {unit}'**
  String filmShortageBuy(String qty, String unit);

  /// No description provided for @filmShortageEnough.
  ///
  /// In en, this message translates to:
  /// **'Enough'**
  String get filmShortageEnough;

  /// No description provided for @filmShortageShort.
  ///
  /// In en, this message translates to:
  /// **'{qty} m short'**
  String filmShortageShort(String qty);

  /// No description provided for @filmShortageNotOnBooks.
  ///
  /// In en, this message translates to:
  /// **'This film is not in stock — add it under «Stock».'**
  String get filmShortageNotOnBooks;

  /// No description provided for @mdfFilmHint.
  ///
  /// In en, this message translates to:
  /// **'How many metres of which film to order'**
  String get mdfFilmHint;

  /// No description provided for @mdfDebtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get mdfDebtsTitle;

  /// No description provided for @mdfDebtsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No debts'**
  String get mdfDebtsEmpty;

  /// No description provided for @mdfDebtsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Every accepted order is paid up.'**
  String get mdfDebtsEmptyHint;

  /// No description provided for @mdfDebtsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total owed: {amount}'**
  String mdfDebtsTotal(String amount);

  /// No description provided for @mdfDebtsByCustomer.
  ///
  /// In en, this message translates to:
  /// **'By customer'**
  String get mdfDebtsByCustomer;

  /// No description provided for @mdfDebtsByOrder.
  ///
  /// In en, this message translates to:
  /// **'By order'**
  String get mdfDebtsByOrder;

  /// No description provided for @mdfDebtsOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders owing: {count}'**
  String mdfDebtsOrders(int count);

  /// No description provided for @mdfDebtsHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Handed over owing'**
  String get mdfDebtsHandedOver;

  /// No description provided for @mdfDebtsHint.
  ///
  /// In en, this message translates to:
  /// **'Who owes what, by customer and order'**
  String get mdfDebtsHint;

  /// No description provided for @mdfBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Parts by film'**
  String get mdfBatchTitle;

  /// No description provided for @mdfBatchHint.
  ///
  /// In en, this message translates to:
  /// **'Every part of the open orders of one film, as one list'**
  String get mdfBatchHint;

  /// No description provided for @mdfBatchShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get mdfBatchShow;

  /// No description provided for @mdfBatchTotals.
  ///
  /// In en, this message translates to:
  /// **'{orders} orders · {pieces} parts · {area} m²'**
  String mdfBatchTotals(String orders, String pieces, String area);

  /// No description provided for @mdfBatchParts.
  ///
  /// In en, this message translates to:
  /// **'Parts (same sizes summed)'**
  String get mdfBatchParts;

  /// No description provided for @mdfBatchLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get mdfBatchLong;

  /// No description provided for @mdfBatchShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get mdfBatchShort;

  /// No description provided for @mdfBatchOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get mdfBatchOrders;

  /// No description provided for @mdfChangeOrder.
  ///
  /// In en, this message translates to:
  /// **'Change order'**
  String get mdfChangeOrder;

  /// No description provided for @mdfChangeReason.
  ///
  /// In en, this message translates to:
  /// **'What changes and why'**
  String get mdfChangeReason;

  /// No description provided for @mdfSaveChange.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get mdfSaveChange;

  /// No description provided for @mdfChanged.
  ///
  /// In en, this message translates to:
  /// **'Order changed — written into its history'**
  String get mdfChanged;

  /// No description provided for @mdfHistorySection.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get mdfHistorySection;

  /// No description provided for @mdfPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop plan'**
  String get mdfPlanTitle;

  /// No description provided for @mdfPlanHint.
  ///
  /// In en, this message translates to:
  /// **'What waits at each stage, in m²'**
  String get mdfPlanHint;

  /// No description provided for @mdfPlanInWork.
  ///
  /// In en, this message translates to:
  /// **'In work: {area} m²'**
  String mdfPlanInWork(String area);

  /// No description provided for @mdfPlanTick.
  ///
  /// In en, this message translates to:
  /// **'Stage done'**
  String get mdfPlanTick;

  /// No description provided for @mdfPlanTicked.
  ///
  /// In en, this message translates to:
  /// **'{order}: «{stage}» ticked'**
  String mdfPlanTicked(String order, String stage);

  /// No description provided for @mdfPlanIntake.
  ///
  /// In en, this message translates to:
  /// **'Orders taken in, by day'**
  String get mdfPlanIntake;

  /// No description provided for @mdfPlanIntakeDay.
  ///
  /// In en, this message translates to:
  /// **'{orders} orders · {area} m²'**
  String mdfPlanIntakeDay(String orders, String area);

  /// No description provided for @mdfCashTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash book'**
  String get mdfCashTitle;

  /// No description provided for @mdfCashHint.
  ///
  /// In en, this message translates to:
  /// **'Payments by method, expenses, balance'**
  String get mdfCashHint;

  /// No description provided for @mdfCashToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get mdfCashToday;

  /// No description provided for @mdfCashWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get mdfCashWeek;

  /// No description provided for @mdfCashMonth.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get mdfCashMonth;

  /// No description provided for @mdfCashIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get mdfCashIn;

  /// No description provided for @mdfCashOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get mdfCashOut;

  /// No description provided for @mdfCashNet.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get mdfCashNet;

  /// No description provided for @mdfCashByDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get mdfCashByDay;

  /// No description provided for @mdfCashPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get mdfCashPayments;

  /// No description provided for @mdfCashNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments in this period'**
  String get mdfCashNoPayments;

  /// No description provided for @mdfCashExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get mdfCashExpenses;

  /// No description provided for @mdfReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Order report'**
  String get mdfReportTitle;

  /// No description provided for @mdfReportHint.
  ///
  /// In en, this message translates to:
  /// **'Orders, m² and money for a period'**
  String get mdfReportHint;

  /// No description provided for @mdfReportThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get mdfReportThisMonth;

  /// No description provided for @mdfReportLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get mdfReportLastMonth;

  /// No description provided for @mdfReportYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get mdfReportYear;

  /// No description provided for @mdfReportOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get mdfReportOrders;

  /// No description provided for @mdfReportArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get mdfReportArea;

  /// No description provided for @mdfReportTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get mdfReportTotal;

  /// No description provided for @mdfReportPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get mdfReportPaid;

  /// No description provided for @mdfReportDebt.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get mdfReportDebt;

  /// No description provided for @mdfReportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get mdfReportCancelled;

  /// No description provided for @mdfReportByDecor.
  ///
  /// In en, this message translates to:
  /// **'By film'**
  String get mdfReportByDecor;

  /// No description provided for @mdfReportTopCustomers.
  ///
  /// In en, this message translates to:
  /// **'Top customers'**
  String get mdfReportTopCustomers;

  /// No description provided for @mdfReportLine.
  ///
  /// In en, this message translates to:
  /// **'{orders} orders · {area} m² · {total}'**
  String mdfReportLine(String orders, String area, String total);

  /// No description provided for @mdfReportOwes.
  ///
  /// In en, this message translates to:
  /// **'owes {amount}'**
  String mdfReportOwes(String amount);

  /// No description provided for @mdfVolumeVersus.
  ///
  /// In en, this message translates to:
  /// **'{arrow} {pct}% on the period before'**
  String mdfVolumeVersus(String arrow, int pct);

  /// No description provided for @mdfVolumeDone.
  ///
  /// In en, this message translates to:
  /// **'Done by stage'**
  String get mdfVolumeDone;

  /// No description provided for @mdfVolumeQueue.
  ///
  /// In en, this message translates to:
  /// **'Waiting now — where it jams'**
  String get mdfVolumeQueue;

  /// No description provided for @mdfVolumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop — work volume'**
  String get mdfVolumeTitle;

  /// No description provided for @mdfVolumeHint.
  ///
  /// In en, this message translates to:
  /// **'m² per worker and stage'**
  String get mdfVolumeHint;

  /// No description provided for @mdfVolumeByWorker.
  ///
  /// In en, this message translates to:
  /// **'By worker'**
  String get mdfVolumeByWorker;

  /// No description provided for @mdfVolumeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stages ticked in this period'**
  String get mdfVolumeEmpty;

  /// No description provided for @mdfVolumeUnassigned.
  ///
  /// In en, this message translates to:
  /// **'With nobody named: {area}'**
  String mdfVolumeUnassigned(String area);

  /// No description provided for @mdfWhoDidIt.
  ///
  /// In en, this message translates to:
  /// **'Who did this stage?'**
  String get mdfWhoDidIt;

  /// No description provided for @mdfWorkerNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody named'**
  String get mdfWorkerNobody;

  /// No description provided for @mdfDictTitle.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get mdfDictTitle;

  /// No description provided for @mdfDictHint.
  ///
  /// In en, this message translates to:
  /// **'Thickness, finish, colours, patina, milling, edge'**
  String get mdfDictHint;

  /// No description provided for @mdfDictOpen.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get mdfDictOpen;

  /// No description provided for @mdfDictDecor.
  ///
  /// In en, this message translates to:
  /// **'Film colour'**
  String get mdfDictDecor;

  /// No description provided for @mdfDictAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get mdfDictAdd;

  /// No description provided for @mdfDictRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get mdfDictRename;

  /// No description provided for @mdfDictDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mdfDictDelete;

  /// No description provided for @mdfDictValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get mdfDictValue;

  /// No description provided for @mdfDictEmpty.
  ///
  /// In en, this message translates to:
  /// **'The list is empty. Press «+» to add.'**
  String get mdfDictEmpty;

  /// No description provided for @mdfDictDeleteAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete «{value}»? If orders already use it, it only leaves the list; the orders stay as they are.'**
  String mdfDictDeleteAsk(String value);

  /// No description provided for @mdfCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get mdfCustomers;

  /// No description provided for @mdfCustomerSearch.
  ///
  /// In en, this message translates to:
  /// **'Name, phone or organisation'**
  String get mdfCustomerSearch;

  /// No description provided for @mdfNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get mdfNothingFound;

  /// No description provided for @mdfCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mdfCustomerName;

  /// No description provided for @mdfCustomerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get mdfCustomerPhone;

  /// No description provided for @mdfCustomerOrg.
  ///
  /// In en, this message translates to:
  /// **'Organisation'**
  String get mdfCustomerOrg;

  /// No description provided for @mdfCustomerDeleteAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete the customer «{name}»? If they have orders, they only leave the list; the orders stay.'**
  String mdfCustomerDeleteAsk(String name);

  /// No description provided for @mdfMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get mdfMaterial;

  /// No description provided for @mdfFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get mdfFilm;

  /// No description provided for @mdfFilmNone.
  ///
  /// In en, this message translates to:
  /// **'No film chosen'**
  String get mdfFilmNone;

  /// No description provided for @mdfFilmPick.
  ///
  /// In en, this message translates to:
  /// **'The group\'s film'**
  String get mdfFilmPick;

  /// No description provided for @mdfFilmRate.
  ///
  /// In en, this message translates to:
  /// **'Price per m²'**
  String get mdfFilmRate;

  /// No description provided for @mdfFilmRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the group'**
  String get mdfFilmRemove;

  /// No description provided for @mdfFilmRemoveAsk.
  ///
  /// In en, this message translates to:
  /// **'Remove the «{film}» group with its positions?'**
  String mdfFilmRemoveAsk(String film);

  /// No description provided for @mdfFilmSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Group total'**
  String get mdfFilmSubtotal;

  /// No description provided for @mdfAddFilm.
  ///
  /// In en, this message translates to:
  /// **'Add a film'**
  String get mdfAddFilm;

  /// No description provided for @mdfBackSide.
  ///
  /// In en, this message translates to:
  /// **'Back side'**
  String get mdfBackSide;

  /// No description provided for @mdfBackSideShort.
  ///
  /// In en, this message translates to:
  /// **'back'**
  String get mdfBackSideShort;

  /// No description provided for @mdfTagUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get mdfTagUrgent;

  /// No description provided for @mdfTagRework.
  ///
  /// In en, this message translates to:
  /// **'Rework'**
  String get mdfTagRework;

  /// No description provided for @mdfTagWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get mdfTagWarranty;

  /// No description provided for @mdfTagVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get mdfTagVip;

  /// No description provided for @mdfTagFurnitureMaker.
  ///
  /// In en, this message translates to:
  /// **'Furniture maker'**
  String get mdfTagFurnitureMaker;

  /// No description provided for @mdfTagNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get mdfTagNew;

  /// No description provided for @mdfTagPrepayOnly.
  ///
  /// In en, this message translates to:
  /// **'Prepayment only'**
  String get mdfTagPrepayOnly;

  /// No description provided for @mdfFilterUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get mdfFilterUrgent;

  /// No description provided for @mdfFilterFurnitureMakers.
  ///
  /// In en, this message translates to:
  /// **'Furniture makers'**
  String get mdfFilterFurnitureMakers;

  /// No description provided for @mdfFilterRework.
  ///
  /// In en, this message translates to:
  /// **'Reworks'**
  String get mdfFilterRework;

  /// No description provided for @mdfColEdge.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get mdfColEdge;

  /// No description provided for @mdfEdgeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default edge'**
  String get mdfEdgeDefault;

  /// No description provided for @mdfExtraAdd.
  ///
  /// In en, this message translates to:
  /// **'+ extra'**
  String get mdfExtraAdd;

  /// No description provided for @mdfDeadlineToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get mdfDeadlineToday;

  /// No description provided for @mdfDeadlineTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get mdfDeadlineTomorrow;

  /// No description provided for @mdfDeadlineLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get mdfDeadlineLater;

  /// No description provided for @mdfAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Won\'t make it'**
  String get mdfAtRisk;

  /// No description provided for @mdfTvTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop screen'**
  String get mdfTvTitle;

  /// No description provided for @mdfTvHint.
  ///
  /// In en, this message translates to:
  /// **'Today, tomorrow, later — for the shop\'s TV'**
  String get mdfTvHint;

  /// No description provided for @mdfPrepayOnlyAsk.
  ///
  /// In en, this message translates to:
  /// **'{customer}: prepayment only, and nothing is paid. Accept anyway?'**
  String mdfPrepayOnlyAsk(String customer);

  /// No description provided for @mdfThicknessShort.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get mdfThicknessShort;

  /// No description provided for @mdfCopyOrder.
  ///
  /// In en, this message translates to:
  /// **'Copy order'**
  String get mdfCopyOrder;

  /// No description provided for @mdfAddStage.
  ///
  /// In en, this message translates to:
  /// **'stage'**
  String get mdfAddStage;

  /// No description provided for @mdfStageReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get mdfStageReady;

  /// No description provided for @mdfPayTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get mdfPayTransfer;

  /// No description provided for @mdfPayCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get mdfPayCash;

  /// No description provided for @mdfPayCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get mdfPayCard;

  /// No description provided for @mdfPayBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get mdfPayBank;

  /// No description provided for @mdfDictBank.
  ///
  /// In en, this message translates to:
  /// **'Banks'**
  String get mdfDictBank;

  /// No description provided for @mdfDictLocked.
  ///
  /// In en, this message translates to:
  /// **'Always on the list — can\'t be removed'**
  String get mdfDictLocked;

  /// No description provided for @mdfCoatingPvc.
  ///
  /// In en, this message translates to:
  /// **'PVC'**
  String get mdfCoatingPvc;

  /// No description provided for @mdfCoatingPaint.
  ///
  /// In en, this message translates to:
  /// **'Paint'**
  String get mdfCoatingPaint;

  /// No description provided for @mdfCoatingRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get mdfCoatingRaw;

  /// No description provided for @mdfCoatingPick.
  ///
  /// In en, this message translates to:
  /// **'Which coating?'**
  String get mdfCoatingPick;

  /// No description provided for @mdfColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get mdfColor;

  /// No description provided for @mdfDictPaint.
  ///
  /// In en, this message translates to:
  /// **'Paints'**
  String get mdfDictPaint;

  /// No description provided for @mdfPaintNone.
  ///
  /// In en, this message translates to:
  /// **'No paint chosen'**
  String get mdfPaintNone;

  /// No description provided for @mdfCoatingNotChosen.
  ///
  /// In en, this message translates to:
  /// **'No coating chosen'**
  String get mdfCoatingNotChosen;

  /// No description provided for @mdfCoatingSwitchAsk.
  ///
  /// In en, this message translates to:
  /// **'«{film}» is not in the «{coating}» list. The block\'s colour will be cleared; positions, sizes and prices stay. Change it?'**
  String mdfCoatingSwitchAsk(String film, String coating);

  /// No description provided for @mdfColCoating.
  ///
  /// In en, this message translates to:
  /// **'Coating'**
  String get mdfColCoating;

  /// No description provided for @mdfPrintHeightShort.
  ///
  /// In en, this message translates to:
  /// **'H'**
  String get mdfPrintHeightShort;

  /// No description provided for @mdfPrintWidthShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get mdfPrintWidthShort;

  /// No description provided for @mdfPrintThickShort.
  ///
  /// In en, this message translates to:
  /// **'Thk.'**
  String get mdfPrintThickShort;

  /// No description provided for @mdfPrintMaterialShort.
  ///
  /// In en, this message translates to:
  /// **'Mat.'**
  String get mdfPrintMaterialShort;

  /// No description provided for @mdfPrintSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get mdfPrintSubtotal;

  /// No description provided for @mdfPrintPieces.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get mdfPrintPieces;

  /// No description provided for @mdfChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get mdfChangesTitle;

  /// No description provided for @mdfReasonClient.
  ///
  /// In en, this message translates to:
  /// **'Customer changed it'**
  String get mdfReasonClient;

  /// No description provided for @mdfReasonMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake at intake'**
  String get mdfReasonMistake;

  /// No description provided for @mdfReasonAdded.
  ///
  /// In en, this message translates to:
  /// **'Positions added'**
  String get mdfReasonAdded;

  /// No description provided for @mdfReasonPrice.
  ///
  /// In en, this message translates to:
  /// **'Price changed'**
  String get mdfReasonPrice;

  /// No description provided for @mdfLeaveUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving? The changes will be lost.'**
  String get mdfLeaveUnsaved;

  /// No description provided for @mdfLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get mdfLeave;

  /// No description provided for @mdfChangeAdded.
  ///
  /// In en, this message translates to:
  /// **'Position {n} added'**
  String mdfChangeAdded(int n);

  /// No description provided for @mdfChangeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Position {n} removed'**
  String mdfChangeRemoved(int n);

  /// No description provided for @mdfTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get mdfTagsTitle;

  /// No description provided for @mdfDueInDays.
  ///
  /// In en, this message translates to:
  /// **'+{n} days'**
  String mdfDueInDays(int n);

  /// No description provided for @mdfDueCalendar.
  ///
  /// In en, this message translates to:
  /// **'Pick in the calendar…'**
  String get mdfDueCalendar;

  /// No description provided for @mdfPaymentFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get mdfPaymentFix;

  /// No description provided for @mdfPaymentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete payment'**
  String get mdfPaymentDelete;

  /// No description provided for @mdfPaymentFixTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix the payment'**
  String get mdfPaymentFixTitle;

  /// No description provided for @mdfPaymentReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get mdfPaymentReason;

  /// No description provided for @mdfPayReasonAmount.
  ///
  /// In en, this message translates to:
  /// **'Wrong amount'**
  String get mdfPayReasonAmount;

  /// No description provided for @mdfPayReasonMethod.
  ///
  /// In en, this message translates to:
  /// **'Wrong method'**
  String get mdfPayReasonMethod;

  /// No description provided for @mdfPayReasonBank.
  ///
  /// In en, this message translates to:
  /// **'Wrong bank'**
  String get mdfPayReasonBank;

  /// No description provided for @mdfPayReasonTwice.
  ///
  /// In en, this message translates to:
  /// **'Entered twice'**
  String get mdfPayReasonTwice;

  /// No description provided for @mdfPaymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get mdfPaymentCancelled;

  /// No description provided for @mdfHandOverCheck.
  ///
  /// In en, this message translates to:
  /// **'Check before hand-over'**
  String get mdfHandOverCheck;

  /// No description provided for @mdfHandOverStagesDone.
  ///
  /// In en, this message translates to:
  /// **'All stages done'**
  String get mdfHandOverStagesDone;

  /// No description provided for @mdfHandOverCounted.
  ///
  /// In en, this message translates to:
  /// **'Counted the pieces: {n}'**
  String mdfHandOverCounted(int n);

  /// No description provided for @mdfTakenByClient.
  ///
  /// In en, this message translates to:
  /// **'The customer'**
  String get mdfTakenByClient;

  /// No description provided for @mdfTakenByOther.
  ///
  /// In en, this message translates to:
  /// **'Someone else'**
  String get mdfTakenByOther;

  /// No description provided for @mdfTakenByName.
  ///
  /// In en, this message translates to:
  /// **'Taken by'**
  String get mdfTakenByName;

  /// No description provided for @mdfTakenByPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get mdfTakenByPhone;

  /// No description provided for @mdfHandedOverOn.
  ///
  /// In en, this message translates to:
  /// **'Handed over {date}'**
  String mdfHandedOverOn(String date);

  /// No description provided for @mdfHandedOverBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String mdfHandedOverBy(String name);

  /// No description provided for @mdfTakenBy.
  ///
  /// In en, this message translates to:
  /// **'taken by {who}'**
  String mdfTakenBy(String who);

  /// No description provided for @mdfHandedWithDebt.
  ///
  /// In en, this message translates to:
  /// **'with a debt of {amount}'**
  String mdfHandedWithDebt(String amount);

  /// No description provided for @mdfReturnToWork.
  ///
  /// In en, this message translates to:
  /// **'Back to work'**
  String get mdfReturnToWork;

  /// No description provided for @mdfReturnReason.
  ///
  /// In en, this message translates to:
  /// **'Why back to work'**
  String get mdfReturnReason;

  /// No description provided for @mdfHandedOverDone.
  ///
  /// In en, this message translates to:
  /// **'Order handed over'**
  String get mdfHandedOverDone;

  /// No description provided for @mdfPayOrderTotal.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get mdfPayOrderTotal;

  /// No description provided for @mdfPayPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get mdfPayPaid;

  /// No description provided for @mdfPayLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get mdfPayLeft;

  /// No description provided for @mdfPayAddPart.
  ///
  /// In en, this message translates to:
  /// **'Another method'**
  String get mdfPayAddPart;

  /// No description provided for @mdfPayAfter.
  ///
  /// In en, this message translates to:
  /// **'Total {sum} · debt after {debt}'**
  String mdfPayAfter(String sum, String debt);

  /// No description provided for @mdfPayOver.
  ///
  /// In en, this message translates to:
  /// **'{amount} more than is left. It may be paid already'**
  String mdfPayOver(String amount);

  /// No description provided for @mdfPayOverOk.
  ///
  /// In en, this message translates to:
  /// **'It is an overpayment / advance'**
  String get mdfPayOverOk;

  /// No description provided for @mdfNoteShort.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get mdfNoteShort;

  /// No description provided for @filmCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'PVC films'**
  String get filmCatalogTitle;

  /// No description provided for @filmMaker.
  ///
  /// In en, this message translates to:
  /// **'Maker'**
  String get filmMaker;

  /// No description provided for @filmType.
  ///
  /// In en, this message translates to:
  /// **'Film surface'**
  String get filmType;

  /// No description provided for @filmAllTypes.
  ///
  /// In en, this message translates to:
  /// **'Any surface'**
  String get filmAllTypes;

  /// No description provided for @filmSearchIn.
  ///
  /// In en, this message translates to:
  /// **'Search in {maker}'**
  String filmSearchIn(String maker);

  /// No description provided for @filmHave.
  ///
  /// In en, this message translates to:
  /// **'in stock · {metres} m'**
  String filmHave(String metres);

  /// No description provided for @filmToOrder.
  ///
  /// In en, this message translates to:
  /// **'to order'**
  String get filmToOrder;

  /// No description provided for @filmOff.
  ///
  /// In en, this message translates to:
  /// **'in the archive'**
  String get filmOff;

  /// No description provided for @filmUnassigned.
  ///
  /// In en, this message translates to:
  /// **'no maker'**
  String get filmUnassigned;

  /// No description provided for @filmUnassignedHint.
  ///
  /// In en, this message translates to:
  /// **'Colours of the old list, without a maker. If such a film is needed, add it at its maker with “Film” and remove it here. Old orders stay as they are.'**
  String get filmUnassignedHint;

  /// No description provided for @filmCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get filmCode;

  /// No description provided for @filmRal.
  ///
  /// In en, this message translates to:
  /// **'Nearest RAL'**
  String get filmRal;

  /// No description provided for @filmSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get filmSupplier;

  /// No description provided for @filmPriceM.
  ///
  /// In en, this message translates to:
  /// **'Purchase, ₸/m'**
  String get filmPriceM;

  /// No description provided for @filmUrl.
  ///
  /// In en, this message translates to:
  /// **'Web page'**
  String get filmUrl;

  /// No description provided for @filmSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get filmSave;

  /// No description provided for @filmAdd.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get filmAdd;

  /// No description provided for @filmEmpty.
  ///
  /// In en, this message translates to:
  /// **'{maker} has no films yet. Press “Film” to add the first.'**
  String filmEmpty(String maker);

  /// No description provided for @filmName.
  ///
  /// In en, this message translates to:
  /// **'Film name'**
  String get filmName;

  /// No description provided for @filmThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness, mm'**
  String get filmThickness;

  /// No description provided for @filmWidth.
  ///
  /// In en, this message translates to:
  /// **'Roll width, mm'**
  String get filmWidth;

  /// No description provided for @filmDeptTitle.
  ///
  /// In en, this message translates to:
  /// **'Film department'**
  String get filmDeptTitle;

  /// No description provided for @filmCatalogShort.
  ///
  /// In en, this message translates to:
  /// **'Catalogue'**
  String get filmCatalogShort;

  /// No description provided for @filmTabStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get filmTabStock;

  /// No description provided for @filmTabSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get filmTabSales;

  /// No description provided for @filmTabCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get filmTabCustomers;

  /// No description provided for @filmCorrectTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get filmCorrectTitle;

  /// No description provided for @filmCorrectReason.
  ///
  /// In en, this message translates to:
  /// **'Why it is corrected'**
  String get filmCorrectReason;

  /// No description provided for @filmCorrectHint.
  ///
  /// In en, this message translates to:
  /// **'The old entry stays, struck through — who corrected it and why is seen.'**
  String get filmCorrectHint;

  /// No description provided for @filmCorrectSave.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get filmCorrectSave;

  /// No description provided for @filmCorrectCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel the entry'**
  String get filmCorrectCancel;

  /// No description provided for @filmCorrected.
  ///
  /// In en, this message translates to:
  /// **'corrected {date} · {who} · “{reason}”'**
  String filmCorrected(String date, String who, String reason);

  /// No description provided for @filmSaleAddPart.
  ///
  /// In en, this message translates to:
  /// **'another way'**
  String get filmSaleAddPart;

  /// No description provided for @filmSalePaidFull.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get filmSalePaidFull;

  /// No description provided for @filmSaleOverpaid.
  ///
  /// In en, this message translates to:
  /// **'{amount} over the total — not allowed'**
  String filmSaleOverpaid(String amount);

  /// No description provided for @filmThicknessUnknown.
  ///
  /// In en, this message translates to:
  /// **'thickness not given'**
  String get filmThicknessUnknown;

  /// No description provided for @filmThicknessHint.
  ///
  /// In en, this message translates to:
  /// **'Not known? Leave it empty and fill it in later'**
  String get filmThicknessHint;

  /// No description provided for @filmNoThickness.
  ///
  /// In en, this message translates to:
  /// **'No thickness · {count}'**
  String filmNoThickness(String count);

  /// No description provided for @filmVariants.
  ///
  /// In en, this message translates to:
  /// **'Thicknesses'**
  String get filmVariants;

  /// No description provided for @filmVariantAdd.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get filmVariantAdd;

  /// No description provided for @filmVariantDeleteAsk.
  ///
  /// In en, this message translates to:
  /// **'Remove the {thickness} mm thickness?'**
  String filmVariantDeleteAsk(String thickness);

  /// No description provided for @filmReceiveSetPrice.
  ///
  /// In en, this message translates to:
  /// **'Put the purchase price on the card: {price} ₸'**
  String filmReceiveSetPrice(String price);

  /// No description provided for @filmReceiveUpdatePrice.
  ///
  /// In en, this message translates to:
  /// **'Update the card\'s purchase price: {before} → {after} ₸'**
  String filmReceiveUpdatePrice(String before, String after);

  /// No description provided for @filmSaleRememberRetail.
  ///
  /// In en, this message translates to:
  /// **'Remember {price} ₸ as the retail price'**
  String filmSaleRememberRetail(String price);

  /// No description provided for @filmSaleRememberWholesale.
  ///
  /// In en, this message translates to:
  /// **'Remember {price} ₸ as the trade price'**
  String filmSaleRememberWholesale(String price);

  /// No description provided for @filmPriceSince.
  ///
  /// In en, this message translates to:
  /// **'since {date} · {via}'**
  String filmPriceSince(String date, String via);

  /// No description provided for @filmPriceByHand.
  ///
  /// In en, this message translates to:
  /// **'by hand'**
  String get filmPriceByHand;

  /// No description provided for @filmMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin: +{amount} ₸/m · {percent}%'**
  String filmMargin(String amount, String percent);

  /// No description provided for @filmSaveMore.
  ///
  /// In en, this message translates to:
  /// **'Save and add another'**
  String get filmSaveMore;

  /// No description provided for @filmAddedOne.
  ///
  /// In en, this message translates to:
  /// **'Added: {name}'**
  String filmAddedOne(String name);

  /// No description provided for @filmArchive.
  ///
  /// In en, this message translates to:
  /// **'To the archive'**
  String get filmArchive;

  /// No description provided for @filmRestore.
  ///
  /// In en, this message translates to:
  /// **'Bring back from the archive'**
  String get filmRestore;

  /// No description provided for @filmArchiveChip.
  ///
  /// In en, this message translates to:
  /// **'Archive · {name}'**
  String filmArchiveChip(String name);

  /// No description provided for @filmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get filmDelete;

  /// No description provided for @filmDeleteAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete the film “{name}”?'**
  String filmDeleteAsk(String name);

  /// No description provided for @filmDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Only a film nothing was done with can be deleted. If it has receipts, sales or orders, send it to the archive.'**
  String get filmDeleteHint;

  /// No description provided for @filmChanges.
  ///
  /// In en, this message translates to:
  /// **'History of changes'**
  String get filmChanges;

  /// No description provided for @filmChangesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No changes yet.'**
  String get filmChangesEmpty;

  /// No description provided for @filmCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get filmCollection;

  /// No description provided for @filmCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get filmCollections;

  /// No description provided for @filmAllCollections.
  ///
  /// In en, this message translates to:
  /// **'All collections'**
  String get filmAllCollections;

  /// No description provided for @filmCollectionAdd.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get filmCollectionAdd;

  /// No description provided for @filmCollectionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename the collection'**
  String get filmCollectionRename;

  /// No description provided for @filmCollectionName.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get filmCollectionName;

  /// No description provided for @filmCollectionRemoveAsk.
  ///
  /// In en, this message translates to:
  /// **'Remove the collection “{name}”?'**
  String filmCollectionRemoveAsk(String name);

  /// No description provided for @filmCollectionRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Its films stay in the catalogue, without a collection.'**
  String get filmCollectionRemoveHint;

  /// No description provided for @filmCollectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'{name} has no collections yet. Press + to add one.'**
  String filmCollectionsEmpty(String name);

  /// No description provided for @filmLooseDropAsk.
  ///
  /// In en, this message translates to:
  /// **'Remove the colour “{name}”?'**
  String filmLooseDropAsk(String name);

  /// No description provided for @filmLooseDropHint.
  ///
  /// In en, this message translates to:
  /// **'Orders that name it stay as written.'**
  String get filmLooseDropHint;

  /// No description provided for @filmTabSources.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get filmTabSources;

  /// No description provided for @filmSourceAdd.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get filmSourceAdd;

  /// No description provided for @filmSourcesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No suppliers yet. Add where film is bought: a maker\'s branch in a city or a wholesaler.'**
  String get filmSourcesEmpty;

  /// No description provided for @filmSourceName.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Adilet · Almaty)'**
  String get filmSourceName;

  /// No description provided for @filmSrcKind.
  ///
  /// In en, this message translates to:
  /// **'Who it is (branch, wholesaler)'**
  String get filmSrcKind;

  /// No description provided for @filmSrcCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get filmSrcCity;

  /// No description provided for @filmSrcContact.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get filmSrcContact;

  /// No description provided for @filmSrcPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get filmSrcPhone;

  /// No description provided for @filmSrcPhone2.
  ///
  /// In en, this message translates to:
  /// **'Second phone'**
  String get filmSrcPhone2;

  /// No description provided for @filmSrcWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get filmSrcWhatsapp;

  /// No description provided for @filmSrcAddress.
  ///
  /// In en, this message translates to:
  /// **'Warehouse address'**
  String get filmSrcAddress;

  /// No description provided for @filmSrcLead.
  ///
  /// In en, this message translates to:
  /// **'Delivery time'**
  String get filmSrcLead;

  /// No description provided for @filmSrcMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Smallest order'**
  String get filmSrcMinOrder;

  /// No description provided for @filmSrcNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get filmSrcNote;

  /// No description provided for @filmSrcMakers.
  ///
  /// In en, this message translates to:
  /// **'Whose films it sells'**
  String get filmSrcMakers;

  /// No description provided for @filmSourceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from the list'**
  String get filmSourceRemove;

  /// No description provided for @filmSourceRemoveAsk.
  ///
  /// In en, this message translates to:
  /// **'Remove supplier “{name}”?'**
  String filmSourceRemoveAsk(String name);

  /// No description provided for @filmSourceRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Its receipts stay in the history.'**
  String get filmSourceRemoveHint;

  /// No description provided for @filmMakerCard.
  ///
  /// In en, this message translates to:
  /// **'Maker\'s card'**
  String get filmMakerCard;

  /// No description provided for @filmMakerSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get filmMakerSite;

  /// No description provided for @filmMakerSources.
  ///
  /// In en, this message translates to:
  /// **'Where this film is bought'**
  String get filmMakerSources;

  /// No description provided for @filmMakerNoSources.
  ///
  /// In en, this message translates to:
  /// **'Nowhere to buy it is named yet. Add a source.'**
  String get filmMakerNoSources;

  /// No description provided for @filmSourceNew.
  ///
  /// In en, this message translates to:
  /// **'Add a source'**
  String get filmSourceNew;

  /// No description provided for @filmReceiveFrom.
  ///
  /// In en, this message translates to:
  /// **'Where it came from'**
  String get filmReceiveFrom;

  /// No description provided for @filmSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get filmSell;

  /// No description provided for @filmReceive.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get filmReceive;

  /// No description provided for @filmToShop.
  ///
  /// In en, this message translates to:
  /// **'To the shop'**
  String get filmToShop;

  /// No description provided for @filmWriteOff.
  ///
  /// In en, this message translates to:
  /// **'Write off'**
  String get filmWriteOff;

  /// No description provided for @filmEditCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get filmEditCard;

  /// No description provided for @filmHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get filmHistory;

  /// No description provided for @filmHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has come or left yet.'**
  String get filmHistoryEmpty;

  /// No description provided for @filmMetresLabel.
  ///
  /// In en, this message translates to:
  /// **'Metres'**
  String get filmMetresLabel;

  /// No description provided for @filmNotEnough.
  ///
  /// In en, this message translates to:
  /// **'not that much in stock'**
  String get filmNotEnough;

  /// No description provided for @filmReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get filmReason;

  /// No description provided for @filmForOrder.
  ///
  /// In en, this message translates to:
  /// **'For order (optional)'**
  String get filmForOrder;

  /// No description provided for @filmReasonSample.
  ///
  /// In en, this message translates to:
  /// **'Sample for a customer'**
  String get filmReasonSample;

  /// No description provided for @filmReasonDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged roll'**
  String get filmReasonDamaged;

  /// No description provided for @filmReasonTest.
  ///
  /// In en, this message translates to:
  /// **'Press test'**
  String get filmReasonTest;

  /// No description provided for @filmRetailM.
  ///
  /// In en, this message translates to:
  /// **'Retail, ₸/m'**
  String get filmRetailM;

  /// No description provided for @filmWholesaleM.
  ///
  /// In en, this message translates to:
  /// **'Wholesale, ₸/m'**
  String get filmWholesaleM;

  /// No description provided for @filmRetail.
  ///
  /// In en, this message translates to:
  /// **'retail'**
  String get filmRetail;

  /// No description provided for @filmWholesale.
  ///
  /// In en, this message translates to:
  /// **'wholesale'**
  String get filmWholesale;

  /// No description provided for @filmDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount, %'**
  String get filmDiscount;

  /// No description provided for @filmSalePriceM.
  ///
  /// In en, this message translates to:
  /// **'Price, ₸/m'**
  String get filmSalePriceM;

  /// No description provided for @filmSaleAddLine.
  ///
  /// In en, this message translates to:
  /// **'Another film'**
  String get filmSaleAddLine;

  /// No description provided for @filmSaleTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String filmSaleTotal(String amount);

  /// No description provided for @filmSalePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid now, ₸'**
  String get filmSalePaid;

  /// No description provided for @filmSaleDebt.
  ///
  /// In en, this message translates to:
  /// **'debt {amount}'**
  String filmSaleDebt(String amount);

  /// No description provided for @filmSalesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sales yet.'**
  String get filmSalesEmpty;

  /// No description provided for @filmCustomersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No film customers yet — they appear after the first sale.'**
  String get filmCustomersEmpty;

  /// No description provided for @filmStockEmpty.
  ///
  /// In en, this message translates to:
  /// **'No films yet. Add them in the catalogue.'**
  String get filmStockEmpty;

  /// No description provided for @filmLow.
  ///
  /// In en, this message translates to:
  /// **'{metres} m · low'**
  String filmLow(String metres);

  /// No description provided for @filmLowCount.
  ///
  /// In en, this message translates to:
  /// **'low in stock · {n}'**
  String filmLowCount(int n);

  /// No description provided for @filmAsleep.
  ///
  /// In en, this message translates to:
  /// **'asleep · {days} d'**
  String filmAsleep(int days);

  /// No description provided for @filmMonthMetres.
  ///
  /// In en, this message translates to:
  /// **'{metres} m this month'**
  String filmMonthMetres(String metres);

  /// No description provided for @filmMoveReceipt.
  ///
  /// In en, this message translates to:
  /// **'receipt'**
  String get filmMoveReceipt;

  /// No description provided for @filmMoveSale.
  ///
  /// In en, this message translates to:
  /// **'sale'**
  String get filmMoveSale;

  /// No description provided for @filmMoveShop.
  ///
  /// In en, this message translates to:
  /// **'to the shop'**
  String get filmMoveShop;

  /// No description provided for @filmMoveWriteOff.
  ///
  /// In en, this message translates to:
  /// **'write-off'**
  String get filmMoveWriteOff;

  /// No description provided for @filmMoveOther.
  ///
  /// In en, this message translates to:
  /// **'issue'**
  String get filmMoveOther;

  /// No description provided for @filmDeptHint.
  ///
  /// In en, this message translates to:
  /// **'Film stock, sales by the metre, customers'**
  String get filmDeptHint;

  /// No description provided for @filmPayDebt.
  ///
  /// In en, this message translates to:
  /// **'Pay off, ₸'**
  String get filmPayDebt;

  /// No description provided for @filmCancelMove.
  ///
  /// In en, this message translates to:
  /// **'Cancel the sale'**
  String get filmCancelMove;

  /// No description provided for @filmCancelReason.
  ///
  /// In en, this message translates to:
  /// **'Why cancel'**
  String get filmCancelReason;

  /// No description provided for @filmClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get filmClose;

  /// No description provided for @filmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get filmDelivery;

  /// No description provided for @filmTransport.
  ///
  /// In en, this message translates to:
  /// **'How it came'**
  String get filmTransport;

  /// No description provided for @filmCity.
  ///
  /// In en, this message translates to:
  /// **'From (city)'**
  String get filmCity;

  /// No description provided for @filmDeliveryCost.
  ///
  /// In en, this message translates to:
  /// **'Delivery cost, ₸'**
  String get filmDeliveryCost;

  /// No description provided for @filmDeliveryPerM.
  ///
  /// In en, this message translates to:
  /// **'≈ {per} a metre'**
  String filmDeliveryPerM(String per);

  /// No description provided for @filmReceivedBy.
  ///
  /// In en, this message translates to:
  /// **'Taken in by'**
  String get filmReceivedBy;

  /// No description provided for @filmUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get filmUrgent;

  /// No description provided for @filmSeller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get filmSeller;

  /// No description provided for @filmTakenBy.
  ///
  /// In en, this message translates to:
  /// **'taken in by {name}'**
  String filmTakenBy(String name);

  /// No description provided for @filmSoldBy.
  ///
  /// In en, this message translates to:
  /// **'sold by {name}'**
  String filmSoldBy(String name);

  /// No description provided for @filmTabTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get filmTabTeam;

  /// No description provided for @filmTeamTotals.
  ///
  /// In en, this message translates to:
  /// **'{metres} m · {sales} sales · paid {paid} · margin {margin}'**
  String filmTeamTotals(
    String metres,
    String sales,
    String paid,
    String margin,
  );

  /// No description provided for @filmTeamPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan: {done}% of {plan} m'**
  String filmTeamPlan(String done, String plan);

  /// No description provided for @filmTeamNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No plan set for the month'**
  String get filmTeamNoPlan;

  /// No description provided for @filmTeamPot.
  ///
  /// In en, this message translates to:
  /// **'Pot: {pct}% of margin = {pot}'**
  String filmTeamPot(String pct, String pot);

  /// No description provided for @filmTeamShare.
  ///
  /// In en, this message translates to:
  /// **'share {share}% · bonus {bonus}'**
  String filmTeamShare(String share, String bonus);

  /// No description provided for @filmTeamEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sales this month'**
  String get filmTeamEmpty;

  /// No description provided for @filmTeamHint.
  ///
  /// In en, this message translates to:
  /// **'The bonus is counted on margin — only money paid, in the month it was paid.'**
  String get filmTeamHint;

  /// No description provided for @filmTeamSettings.
  ///
  /// In en, this message translates to:
  /// **'Plan and bonus'**
  String get filmTeamSettings;

  /// No description provided for @filmTeamPlanM.
  ///
  /// In en, this message translates to:
  /// **'Plan for the month, m'**
  String get filmTeamPlanM;

  /// No description provided for @filmTeamPct.
  ///
  /// In en, this message translates to:
  /// **'Pot when the plan is met, %'**
  String get filmTeamPct;

  /// No description provided for @filmTeamPctBelow.
  ///
  /// In en, this message translates to:
  /// **'Pot when the plan is missed, %'**
  String get filmTeamPctBelow;

  /// No description provided for @filmTeamSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get filmTeamSave;

  /// No description provided for @filmArrival.
  ///
  /// In en, this message translates to:
  /// **'When it arrives'**
  String get filmArrival;

  /// No description provided for @filmArrivalHere.
  ///
  /// In en, this message translates to:
  /// **'Already in stock'**
  String get filmArrivalHere;

  /// No description provided for @filmArrivalTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get filmArrivalTomorrow;

  /// No description provided for @filmArrivalTwo.
  ///
  /// In en, this message translates to:
  /// **'In 2 days'**
  String get filmArrivalTwo;

  /// No description provided for @filmArrivalThree.
  ///
  /// In en, this message translates to:
  /// **'3 days'**
  String get filmArrivalThree;

  /// No description provided for @filmArrivalWeek.
  ///
  /// In en, this message translates to:
  /// **'A week'**
  String get filmArrivalWeek;

  /// No description provided for @filmArrivalPick.
  ///
  /// In en, this message translates to:
  /// **'Date…'**
  String get filmArrivalPick;

  /// No description provided for @filmArrivesOn.
  ///
  /// In en, this message translates to:
  /// **'Arrives: {day}'**
  String filmArrivesOn(String day);

  /// No description provided for @filmArrivalOrder.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get filmArrivalOrder;

  /// No description provided for @filmComing.
  ///
  /// In en, this message translates to:
  /// **'on its way {metres} m · arrives {day}'**
  String filmComing(String metres, String day);

  /// No description provided for @filmComingLate.
  ///
  /// In en, this message translates to:
  /// **'on its way {metres} m · {days} d late'**
  String filmComingLate(String metres, String days);

  /// No description provided for @filmComingArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get filmComingArrived;

  /// No description provided for @filmComingMove.
  ///
  /// In en, this message translates to:
  /// **'Another date'**
  String get filmComingMove;

  /// No description provided for @filmComingDrop.
  ///
  /// In en, this message translates to:
  /// **'Won\'t come'**
  String get filmComingDrop;

  /// No description provided for @filmComingDropReason.
  ///
  /// In en, this message translates to:
  /// **'Why it won\'t come'**
  String get filmComingDropReason;

  /// No description provided for @filmComingMetres.
  ///
  /// In en, this message translates to:
  /// **'Metres that came'**
  String get filmComingMetres;

  /// No description provided for @filmOnShelf.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get filmOnShelf;

  /// No description provided for @filmOnWay.
  ///
  /// In en, this message translates to:
  /// **'On its way'**
  String get filmOnWay;

  /// No description provided for @filmOnlyHave.
  ///
  /// In en, this message translates to:
  /// **'only {metres} m in stock'**
  String filmOnlyHave(String metres);

  /// No description provided for @filmLeft.
  ///
  /// In en, this message translates to:
  /// **'{metres} m left'**
  String filmLeft(String metres);

  /// No description provided for @filmLeftLow.
  ///
  /// In en, this message translates to:
  /// **'{metres} m left — low'**
  String filmLeftLow(String metres);

  /// No description provided for @filmTakeAll.
  ///
  /// In en, this message translates to:
  /// **'Take all {metres} m'**
  String filmTakeAll(String metres);

  /// No description provided for @filmMoreComing.
  ///
  /// In en, this message translates to:
  /// **'+{metres} m on its way, arrives {day}'**
  String filmMoreComing(String metres, String day);

  /// No description provided for @filmDeliveryPayer.
  ///
  /// In en, this message translates to:
  /// **'Who paid'**
  String get filmDeliveryPayer;

  /// No description provided for @filmPayerCash.
  ///
  /// In en, this message translates to:
  /// **'Film cash'**
  String get filmPayerCash;

  /// No description provided for @filmPayerEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee, own money'**
  String get filmPayerEmployee;

  /// No description provided for @filmPayerUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Not paid yet'**
  String get filmPayerUnpaid;

  /// No description provided for @filmPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid out of pocket by'**
  String get filmPaidBy;

  /// No description provided for @filmPaidCash.
  ///
  /// In en, this message translates to:
  /// **'from the cash'**
  String get filmPaidCash;

  /// No description provided for @filmPaidByBack.
  ///
  /// In en, this message translates to:
  /// **'paid by {who}, given back'**
  String filmPaidByBack(String who);

  /// No description provided for @filmPaidByOwed.
  ///
  /// In en, this message translates to:
  /// **'paid by {who} — to give back'**
  String filmPaidByOwed(String who);

  /// No description provided for @filmCarrierPaid.
  ///
  /// In en, this message translates to:
  /// **'carrier paid'**
  String get filmCarrierPaid;

  /// No description provided for @filmCarrierOwed.
  ///
  /// In en, this message translates to:
  /// **'carrier not paid'**
  String get filmCarrierOwed;

  /// No description provided for @filmPaidSupplier.
  ///
  /// In en, this message translates to:
  /// **'on the supplier'**
  String get filmPaidSupplier;

  /// No description provided for @filmTabCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get filmTabCash;

  /// No description provided for @filmSettleBy.
  ///
  /// In en, this message translates to:
  /// **'Paid: {how}'**
  String filmSettleBy(String how);

  /// No description provided for @filmGaveBack.
  ///
  /// In en, this message translates to:
  /// **'Gave back'**
  String get filmGaveBack;

  /// No description provided for @filmPaidCarrier.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get filmPaidCarrier;

  /// No description provided for @filmCashToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get filmCashToday;

  /// No description provided for @filmCashMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get filmCashMonth;

  /// No description provided for @filmCashIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get filmCashIn;

  /// No description provided for @filmCashOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get filmCashOut;

  /// No description provided for @filmCashNothing.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get filmCashNothing;

  /// No description provided for @filmCashTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get filmCashTotal;

  /// No description provided for @filmCashBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get filmCashBalance;

  /// No description provided for @filmCashLogistics.
  ///
  /// In en, this message translates to:
  /// **'Logistics in the period: {sum} — not in the bonus'**
  String filmCashLogistics(String sum);

  /// No description provided for @filmCashLogisticsPerM.
  ///
  /// In en, this message translates to:
  /// **'Logistics in the period: {sum} (≈ {per} a metre) — not in the bonus'**
  String filmCashLogisticsPerM(String sum, String per);

  /// No description provided for @filmOwedEmployees.
  ///
  /// In en, this message translates to:
  /// **'Owed to employees'**
  String get filmOwedEmployees;

  /// No description provided for @filmOwedCarriers.
  ///
  /// In en, this message translates to:
  /// **'Owed to carriers'**
  String get filmOwedCarriers;

  /// No description provided for @filmOwedSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Owed to suppliers'**
  String get filmOwedSuppliers;

  /// No description provided for @filmPaidToSupplier.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get filmPaidToSupplier;

  /// No description provided for @filmSupplierPay.
  ///
  /// In en, this message translates to:
  /// **'Paying the supplier'**
  String get filmSupplierPay;

  /// No description provided for @filmSupplierPaidNow.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get filmSupplierPaidNow;

  /// No description provided for @filmSupplierOnCredit.
  ///
  /// In en, this message translates to:
  /// **'On credit'**
  String get filmSupplierOnCredit;

  /// No description provided for @filmSupplierOwedNote.
  ///
  /// In en, this message translates to:
  /// **'owed to the supplier'**
  String get filmSupplierOwedNote;

  /// No description provided for @filmCashChartA11y.
  ///
  /// In en, this message translates to:
  /// **'In {incoming}, out {outgoing}'**
  String filmCashChartA11y(String incoming, String outgoing);

  /// No description provided for @filmCashVersus.
  ///
  /// In en, this message translates to:
  /// **'{arrow} {pct}% on the period before'**
  String filmCashVersus(String arrow, String pct);

  /// No description provided for @filmPayFromCash.
  ///
  /// In en, this message translates to:
  /// **'From the film cash: {how}'**
  String filmPayFromCash(String how);

  /// No description provided for @filmPayElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Not from the film cash'**
  String get filmPayElsewhere;

  /// No description provided for @filmToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get filmToday;

  /// No description provided for @filmYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get filmYesterday;

  /// No description provided for @filmHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filmHistoryAll;

  /// No description provided for @filmHistoryReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get filmHistoryReceipts;

  /// No description provided for @filmHistorySales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get filmHistorySales;

  /// No description provided for @filmHistoryShop.
  ///
  /// In en, this message translates to:
  /// **'To the shop'**
  String get filmHistoryShop;

  /// No description provided for @filmHistoryWriteOffs.
  ///
  /// In en, this message translates to:
  /// **'Write-offs'**
  String get filmHistoryWriteOffs;

  /// No description provided for @filmAfter.
  ///
  /// In en, this message translates to:
  /// **'then {metres} m'**
  String filmAfter(String metres);

  /// No description provided for @filmReorderBanner.
  ///
  /// In en, this message translates to:
  /// **'Time to order — films running low: {count}'**
  String filmReorderBanner(int count);

  /// No description provided for @filmReorderOpen.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get filmReorderOpen;

  /// No description provided for @filmReorderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order film'**
  String get filmReorderTitle;

  /// No description provided for @filmReorderLeft.
  ///
  /// In en, this message translates to:
  /// **'{metres} m left'**
  String filmReorderLeft(String metres);

  /// No description provided for @filmReorderTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {sum} · arrives {day}'**
  String filmReorderTotal(String sum, String day);

  /// No description provided for @filmReorderSave.
  ///
  /// In en, this message translates to:
  /// **'Place ({count})'**
  String filmReorderSave(int count);

  /// No description provided for @filmDebtors.
  ///
  /// In en, this message translates to:
  /// **'Owing: {count} · {sum}'**
  String filmDebtors(int count, String sum);

  /// No description provided for @filmRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind in WhatsApp'**
  String get filmRemind;

  /// No description provided for @filmRemindText.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}! A reminder about the film payment: {sum} left. Thank you!'**
  String filmRemindText(String name, String sum);

  /// No description provided for @filmDebtDays.
  ///
  /// In en, this message translates to:
  /// **'owing {days} d'**
  String filmDebtDays(int days);

  /// No description provided for @filmReportTop.
  ///
  /// In en, this message translates to:
  /// **'What sold this month'**
  String get filmReportTop;

  /// No description provided for @filmReportTotals.
  ///
  /// In en, this message translates to:
  /// **'{metres} m · takings {amount} · margin {margin}'**
  String filmReportTotals(String metres, String amount, String margin);

  /// No description provided for @filmReportMarginM.
  ///
  /// In en, this message translates to:
  /// **'margin {sum}/m'**
  String filmReportMarginM(String sum);

  /// No description provided for @filmReportIdle.
  ///
  /// In en, this message translates to:
  /// **'Unmoved for over {days} d'**
  String filmReportIdle(int days);

  /// No description provided for @filmReportIdleDays.
  ///
  /// In en, this message translates to:
  /// **'{days} d unmoved'**
  String filmReportIdleDays(int days);

  /// No description provided for @filmReportFrozen.
  ///
  /// In en, this message translates to:
  /// **'{sum} tied up'**
  String filmReportFrozen(String sum);

  /// No description provided for @filmReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get filmReceipt;

  /// No description provided for @filmReceiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get filmReceiptDate;

  /// No description provided for @filmReceiptCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get filmReceiptCustomer;

  /// No description provided for @filmReceiptFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get filmReceiptFilm;

  /// No description provided for @filmReceiptMetres.
  ///
  /// In en, this message translates to:
  /// **'Metres'**
  String get filmReceiptMetres;

  /// No description provided for @filmReceiptPrice.
  ///
  /// In en, this message translates to:
  /// **'Price a metre'**
  String get filmReceiptPrice;

  /// No description provided for @filmReceiptAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get filmReceiptAmount;

  /// No description provided for @filmReceiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get filmReceiptTotal;

  /// No description provided for @filmReceiptPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get filmReceiptPaid;

  /// No description provided for @filmReceiptDebt.
  ///
  /// In en, this message translates to:
  /// **'Owing'**
  String get filmReceiptDebt;

  /// No description provided for @filmHold.
  ///
  /// In en, this message translates to:
  /// **'Put by'**
  String get filmHold;

  /// No description provided for @filmHoldRelease.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get filmHoldRelease;

  /// No description provided for @filmHoldUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get filmHoldUntil;

  /// No description provided for @filmHeldFor.
  ///
  /// In en, this message translates to:
  /// **'{metres} m put by for {customer} until {day}'**
  String filmHeldFor(String metres, String customer, String day);

  /// No description provided for @facadePricesUnsoldMillings.
  ///
  /// In en, this message translates to:
  /// **'Millings with no price: {count}'**
  String facadePricesUnsoldMillings(int count);

  /// No description provided for @facadePricesShowUnsold.
  ///
  /// In en, this message translates to:
  /// **'Not sold: {count} — show'**
  String facadePricesShowUnsold(int count);

  /// No description provided for @facadePricesHideUnsold.
  ///
  /// In en, this message translates to:
  /// **'Hide the unsold'**
  String get facadePricesHideUnsold;

  /// No description provided for @mdfGroupSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get mdfGroupSales;

  /// No description provided for @mdfGroupShop.
  ///
  /// In en, this message translates to:
  /// **'Shop floor'**
  String get mdfGroupShop;

  /// No description provided for @mdfGroupStock.
  ///
  /// In en, this message translates to:
  /// **'Stock and buying'**
  String get mdfGroupStock;

  /// No description provided for @mdfGroupSettings.
  ///
  /// In en, this message translates to:
  /// **'Lists and prices'**
  String get mdfGroupSettings;

  /// No description provided for @filmDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get filmDriver;

  /// No description provided for @filmDriverPhone.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s phone'**
  String get filmDriverPhone;

  /// No description provided for @filmFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get filmFree;

  /// No description provided for @filmHeld.
  ///
  /// In en, this message translates to:
  /// **'Put by'**
  String get filmHeld;

  /// No description provided for @filmReceiptPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get filmReceiptPayment;

  /// No description provided for @filmReceiptServedBy.
  ///
  /// In en, this message translates to:
  /// **'Seller (responsible): {name}'**
  String filmReceiptServedBy(String name);

  /// No description provided for @filmReceiptThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for choosing us!'**
  String get filmReceiptThanks;

  /// No description provided for @filmReceiptWish.
  ///
  /// In en, this message translates to:
  /// **'A fine choice — may your facades bring you joy for years. We look forward to seeing you again!'**
  String get filmReceiptWish;

  /// No description provided for @filmReceiptCode.
  ///
  /// In en, this message translates to:
  /// **'code {code}'**
  String filmReceiptCode(String code);

  /// No description provided for @filmReceiptThickness.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm'**
  String filmReceiptThickness(String mm);

  /// No description provided for @filmReceiptPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String filmReceiptPhone(String phone);

  /// No description provided for @filmReceiptSignSold.
  ///
  /// In en, this message translates to:
  /// **'Sold by'**
  String get filmReceiptSignSold;

  /// No description provided for @filmReceiptSignGot.
  ///
  /// In en, this message translates to:
  /// **'Received by'**
  String get filmReceiptSignGot;

  /// No description provided for @facadePricesAddVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get facadePricesAddVariant;

  /// No description provided for @facadePricesVariant.
  ///
  /// In en, this message translates to:
  /// **'Milling variant'**
  String get facadePricesVariant;

  /// No description provided for @facadePricesVariantHint.
  ///
  /// In en, this message translates to:
  /// **'Priced as its kind. In an order it shows as «kind variant».'**
  String get facadePricesVariantHint;

  /// No description provided for @filmIssuedBy.
  ///
  /// In en, this message translates to:
  /// **'Handed out by'**
  String get filmIssuedBy;

  /// No description provided for @filmReceiptIssuedBy.
  ///
  /// In en, this message translates to:
  /// **'Handed out by: {name}'**
  String filmReceiptIssuedBy(String name);

  /// No description provided for @filmReceiptSignIssued.
  ///
  /// In en, this message translates to:
  /// **'Handed out'**
  String get filmReceiptSignIssued;

  /// No description provided for @filmHeldShort.
  ///
  /// In en, this message translates to:
  /// **'{metres} m put by'**
  String filmHeldShort(String metres);

  /// No description provided for @filmOnWayShort.
  ///
  /// In en, this message translates to:
  /// **'{metres} m on its way'**
  String filmOnWayShort(String metres);

  /// No description provided for @filmReceivePick.
  ///
  /// In en, this message translates to:
  /// **'Receipt — which film?'**
  String get filmReceivePick;

  /// No description provided for @searchSectionFilms.
  ///
  /// In en, this message translates to:
  /// **'Film ({count})'**
  String searchSectionFilms(int count);

  /// No description provided for @searchSectionFilmCustomers.
  ///
  /// In en, this message translates to:
  /// **'Film customers ({count})'**
  String searchSectionFilmCustomers(int count);

  /// No description provided for @filmDebtLine.
  ///
  /// In en, this message translates to:
  /// **'owes {sum} ₸'**
  String filmDebtLine(String sum);

  /// No description provided for @filmTeamSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get filmTeamSold;

  /// No description provided for @filmTeamPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get filmTeamPaid;

  /// No description provided for @filmTeamMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get filmTeamMargin;

  /// No description provided for @filmTeamPotLabel.
  ///
  /// In en, this message translates to:
  /// **'Pot'**
  String get filmTeamPotLabel;

  /// No description provided for @filmTeamPotNote.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of margin'**
  String filmTeamPotNote(String pct);

  /// No description provided for @filmTeamVsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'vs last month'**
  String get filmTeamVsLastMonth;

  /// No description provided for @filmTeamMarginShare.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of what was paid'**
  String filmTeamMarginShare(String pct);

  /// No description provided for @filmTeamSellers.
  ///
  /// In en, this message translates to:
  /// **'Sellers'**
  String get filmTeamSellers;

  /// No description provided for @filmTeamSellerLine.
  ///
  /// In en, this message translates to:
  /// **'{name} · {sales} sales · {metres} m'**
  String filmTeamSellerLine(String name, String sales, String metres);

  /// No description provided for @filmTeamBonus.
  ///
  /// In en, this message translates to:
  /// **'bonus {sum}'**
  String filmTeamBonus(String sum);

  /// No description provided for @filmTeamShareLine.
  ///
  /// In en, this message translates to:
  /// **'share {share}% · margin {margin} · paid {paid}'**
  String filmTeamShareLine(String share, String margin, String paid);

  /// No description provided for @filmReportMarginLegend.
  ///
  /// In en, this message translates to:
  /// **'Green — a good margin, amber — under 300 ₸ a metre, red — sold under cost.'**
  String get filmReportMarginLegend;

  /// No description provided for @filmCashWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get filmCashWeek;

  /// No description provided for @filmCashSales.
  ///
  /// In en, this message translates to:
  /// **'{count} sales'**
  String filmCashSales(int count);

  /// No description provided for @filmCashSpent.
  ///
  /// In en, this message translates to:
  /// **'{count} paid out'**
  String filmCashSpent(int count);

  /// No description provided for @filmCashWhere.
  ///
  /// In en, this message translates to:
  /// **'Where the money is'**
  String get filmCashWhere;

  /// No description provided for @filmCashMoves.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get filmCashMoves;

  /// No description provided for @filmCustomersAll.
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String filmCustomersAll(int count);

  /// No description provided for @filmCustomersRegular.
  ///
  /// In en, this message translates to:
  /// **'⭐ Regular {count}'**
  String filmCustomersRegular(int count);

  /// No description provided for @filmCustomersAsleep.
  ///
  /// In en, this message translates to:
  /// **'😴 Gone quiet {count}'**
  String filmCustomersAsleep(int count);

  /// No description provided for @filmCustomersByMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get filmCustomersByMonth;

  /// No description provided for @filmCustomersByAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get filmCustomersByAll;

  /// No description provided for @filmCustomersLegend.
  ///
  /// In en, this message translates to:
  /// **'Top — who buys most. Stripe: green — paid up, red — owes, grey — gone quiet.'**
  String get filmCustomersLegend;

  /// No description provided for @filmRegularBadge.
  ///
  /// In en, this message translates to:
  /// **'⭐ regular'**
  String get filmRegularBadge;

  /// No description provided for @filmNoDebt.
  ///
  /// In en, this message translates to:
  /// **'nothing owed'**
  String get filmNoDebt;

  /// No description provided for @filmCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get filmCall;

  /// No description provided for @filmWrite.
  ///
  /// In en, this message translates to:
  /// **'Write in WhatsApp'**
  String get filmWrite;

  /// No description provided for @filmCustomerLast.
  ///
  /// In en, this message translates to:
  /// **'last bought {day}'**
  String filmCustomerLast(String day);

  /// No description provided for @filmCustomerBought.
  ///
  /// In en, this message translates to:
  /// **'Bought in all'**
  String get filmCustomerBought;

  /// No description provided for @filmCustomerSum.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get filmCustomerSum;

  /// No description provided for @filmCustomerDebt.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get filmCustomerDebt;

  /// No description provided for @filmCustomerMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get filmCustomerMonth;

  /// No description provided for @filmCustomerFavourite.
  ///
  /// In en, this message translates to:
  /// **'Takes most'**
  String get filmCustomerFavourite;

  /// No description provided for @filmCustomerTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms: retail / trade, discount'**
  String get filmCustomerTerms;

  /// No description provided for @filmCustomerHistory.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get filmCustomerHistory;

  /// No description provided for @filmCashShould.
  ///
  /// In en, this message translates to:
  /// **'Cash in the drawer should be: {sum}'**
  String filmCashShould(String sum);

  /// No description provided for @filmCashClosed.
  ///
  /// In en, this message translates to:
  /// **'Day closed: counted {sum} · {who}'**
  String filmCashClosed(String sum, String who);

  /// No description provided for @filmCashGap.
  ///
  /// In en, this message translates to:
  /// **'off by {sum}: {why}'**
  String filmCashGap(String sum, String why);

  /// No description provided for @filmCashCloseDay.
  ///
  /// In en, this message translates to:
  /// **'Close the day'**
  String get filmCashCloseDay;

  /// No description provided for @filmCashRecount.
  ///
  /// In en, this message translates to:
  /// **'Count again'**
  String get filmCashRecount;

  /// No description provided for @filmCashCounted.
  ///
  /// In en, this message translates to:
  /// **'Cash counted'**
  String get filmCashCounted;

  /// No description provided for @filmCashShort.
  ///
  /// In en, this message translates to:
  /// **'Short by {sum}'**
  String filmCashShort(String sum);

  /// No description provided for @filmCashOver.
  ///
  /// In en, this message translates to:
  /// **'Over by {sum}'**
  String filmCashOver(String sum);

  /// No description provided for @filmCashMatches.
  ///
  /// In en, this message translates to:
  /// **'It matches'**
  String get filmCashMatches;

  /// No description provided for @filmCashWhy.
  ///
  /// In en, this message translates to:
  /// **'Why it is off'**
  String get filmCashWhy;

  /// No description provided for @filmSupSoldMonth.
  ///
  /// In en, this message translates to:
  /// **'Sold this month'**
  String get filmSupSoldMonth;

  /// No description provided for @filmSupSoldAll.
  ///
  /// In en, this message translates to:
  /// **'Sold in all'**
  String get filmSupSoldAll;

  /// No description provided for @filmSupOnHand.
  ///
  /// In en, this message translates to:
  /// **'On the shelf'**
  String get filmSupOnHand;

  /// No description provided for @filmSupComing.
  ///
  /// In en, this message translates to:
  /// **'On its way'**
  String get filmSupComing;

  /// No description provided for @filmSupReorder.
  ///
  /// In en, this message translates to:
  /// **'To order'**
  String get filmSupReorder;

  /// No description provided for @filmSupM.
  ///
  /// In en, this message translates to:
  /// **'{metres} m'**
  String filmSupM(String metres);

  /// No description provided for @filmSupComingRolls.
  ///
  /// In en, this message translates to:
  /// **'rolls: {count}'**
  String filmSupComingRolls(int count);

  /// No description provided for @filmSupReorderFilms.
  ///
  /// In en, this message translates to:
  /// **'films: {count}'**
  String filmSupReorderFilms(int count);

  /// No description provided for @filmSupShare.
  ///
  /// In en, this message translates to:
  /// **'{share}% of sales'**
  String filmSupShare(String share);

  /// No description provided for @filmSupRevenue.
  ///
  /// In en, this message translates to:
  /// **'revenue {sum}'**
  String filmSupRevenue(String sum);

  /// No description provided for @filmSupShelf.
  ///
  /// In en, this message translates to:
  /// **'{metres} m on the shelf'**
  String filmSupShelf(String metres);

  /// No description provided for @filmSupLead.
  ///
  /// In en, this message translates to:
  /// **'brings in {days} d (promised {promised})'**
  String filmSupLead(int days, int promised);

  /// No description provided for @filmSupChipReorder.
  ///
  /// In en, this message translates to:
  /// **'To order: {count}'**
  String filmSupChipReorder(int count);

  /// No description provided for @filmSupChipComing.
  ///
  /// In en, this message translates to:
  /// **'{metres} m on its way · {day}'**
  String filmSupChipComing(String metres, String day);

  /// No description provided for @filmSupChipComingLate.
  ///
  /// In en, this message translates to:
  /// **'{metres} m on its way · {days} d late'**
  String filmSupChipComingLate(String metres, int days);

  /// No description provided for @filmSupChipLate.
  ///
  /// In en, this message translates to:
  /// **'Late by {days} d on average'**
  String filmSupChipLate(int days);

  /// No description provided for @filmSupChipIdle.
  ///
  /// In en, this message translates to:
  /// **'Lying idle: {count} · {metres} m'**
  String filmSupChipIdle(int count, String metres);

  /// No description provided for @filmSupChipOk.
  ///
  /// In en, this message translates to:
  /// **'All is well'**
  String get filmSupChipOk;

  /// No description provided for @filmSupOrder.
  ///
  /// In en, this message translates to:
  /// **'Order by WhatsApp'**
  String get filmSupOrder;

  /// No description provided for @filmSupOrderText.
  ///
  /// In en, this message translates to:
  /// **'Hello! We need film:\n{list}\nWhen can you bring it?'**
  String filmSupOrderText(String list);

  /// No description provided for @filmSupOrderLine.
  ///
  /// In en, this message translates to:
  /// **'— {title} — {metres} m'**
  String filmSupOrderLine(String title, String metres);

  /// No description provided for @filmSupLegend.
  ///
  /// In en, this message translates to:
  /// **'Top — whose film sells best. A film of two sources is shared by what each brought.'**
  String get filmSupLegend;

  /// No description provided for @filmSrcOrderUntil.
  ///
  /// In en, this message translates to:
  /// **'Takes orders until (e.g. 16:00)'**
  String get filmSrcOrderUntil;

  /// No description provided for @filmReceiveAddFilm.
  ///
  /// In en, this message translates to:
  /// **'Another film'**
  String get filmReceiveAddFilm;

  /// No description provided for @filmReceiveAddLow.
  ///
  /// In en, this message translates to:
  /// **'Add all that ran low ({count})'**
  String filmReceiveAddLow(int count);

  /// No description provided for @filmReceiveForWhom.
  ///
  /// In en, this message translates to:
  /// **'For whom'**
  String get filmReceiveForWhom;

  /// No description provided for @filmReceiveForShelf.
  ///
  /// In en, this message translates to:
  /// **'For the shelf'**
  String get filmReceiveForShelf;

  /// No description provided for @filmReceiveForCustomer.
  ///
  /// In en, this message translates to:
  /// **'For: {name}'**
  String filmReceiveForCustomer(String name);

  /// No description provided for @filmReceiveRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get filmReceiveRemove;

  /// No description provided for @filmReceiveSum.
  ///
  /// In en, this message translates to:
  /// **'comes to {sum}'**
  String filmReceiveSum(String sum);

  /// No description provided for @filmReceiveSumWithDelivery.
  ///
  /// In en, this message translates to:
  /// **'comes to {sum} · {perM} a metre delivered'**
  String filmReceiveSumWithDelivery(String sum, String perM);

  /// No description provided for @filmReceiveMany.
  ///
  /// In en, this message translates to:
  /// **'Delivery · films: {count}'**
  String filmReceiveMany(int count);

  /// No description provided for @filmReceiveTotal.
  ///
  /// In en, this message translates to:
  /// **'In all: {count} films · {metres} m · {sum} delivered'**
  String filmReceiveTotal(int count, String metres, String sum);

  /// No description provided for @filmPickSearch.
  ///
  /// In en, this message translates to:
  /// **'Maker, colour or code'**
  String get filmPickSearch;

  /// No description provided for @filmPickNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get filmPickNone;

  /// No description provided for @filmPickFree.
  ///
  /// In en, this message translates to:
  /// **'{metres} m'**
  String filmPickFree(String metres);

  /// No description provided for @filmPickReorder.
  ///
  /// In en, this message translates to:
  /// **'to order'**
  String get filmPickReorder;

  /// No description provided for @filmOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'To order'**
  String get filmOrdersTitle;

  /// No description provided for @filmOrdersSendAll.
  ///
  /// In en, this message translates to:
  /// **'Send to all ({count})'**
  String filmOrdersSendAll(int count);

  /// No description provided for @filmOrdersSummary.
  ///
  /// In en, this message translates to:
  /// **'Films: {count} · {metres} m · suppliers: {suppliers}'**
  String filmOrdersSummary(int count, String metres, int suppliers);

  /// No description provided for @filmOrdersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a film'**
  String get filmOrdersAdd;

  /// No description provided for @filmOrdersAddSave.
  ///
  /// In en, this message translates to:
  /// **'Add to the order'**
  String get filmOrdersAddSave;

  /// No description provided for @filmOrdersEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to order yet. Add a film when a customer wants more than there is — films that run low show up here by themselves.'**
  String get filmOrdersEmpty;

  /// No description provided for @filmOrdersLegend.
  ///
  /// In en, this message translates to:
  /// **'Red — ran out, blue — for a customer, grey — for the shelf. Tap to change the metres; × — remove.'**
  String get filmOrdersLegend;

  /// No description provided for @filmOrderLine.
  ///
  /// In en, this message translates to:
  /// **'{n}. {title} — {metres} m'**
  String filmOrderLine(int n, String title, String metres);

  /// No description provided for @filmOrderText.
  ///
  /// In en, this message translates to:
  /// **'Hello! Order for {date}:\n{lines}\nIn all: {count} items, {metres} m.\nPlease confirm what you have and when you will bring it.'**
  String filmOrderText(String date, String lines, int count, String metres);

  /// No description provided for @filmOrderCopied.
  ///
  /// In en, this message translates to:
  /// **'The order for «{name}» is copied — paste it into a message.'**
  String filmOrderCopied(String name);

  /// No description provided for @filmOrdersNoSupplier.
  ///
  /// In en, this message translates to:
  /// **'No supplier named'**
  String get filmOrdersNoSupplier;

  /// No description provided for @filmOrdersGroupTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} films · {metres} m'**
  String filmOrdersGroupTotal(int count, String metres);

  /// No description provided for @filmOrdersUntil.
  ///
  /// In en, this message translates to:
  /// **'takes orders until {time}'**
  String filmOrdersUntil(String time);

  /// No description provided for @filmOrdersSend.
  ///
  /// In en, this message translates to:
  /// **'Send by WhatsApp'**
  String get filmOrdersSend;

  /// No description provided for @filmOrdersCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy the order'**
  String get filmOrdersCopy;

  /// No description provided for @filmOrdersSentAt.
  ///
  /// In en, this message translates to:
  /// **'Sent at {time} · waiting for an answer'**
  String filmOrdersSentAt(String time);

  /// No description provided for @filmOrdersConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed — enter the delivery'**
  String get filmOrdersConfirmed;

  /// No description provided for @filmOrdersForShelf.
  ///
  /// In en, this message translates to:
  /// **'shelf {metres} m'**
  String filmOrdersForShelf(String metres);

  /// No description provided for @filmOrdersForCustomer.
  ///
  /// In en, this message translates to:
  /// **'{name} {metres} m'**
  String filmOrdersForCustomer(String name, String metres);

  /// No description provided for @filmOrdersRanOut.
  ///
  /// In en, this message translates to:
  /// **'ran out · {metres} m'**
  String filmOrdersRanOut(String metres);

  /// No description provided for @filmOrdersButton.
  ///
  /// In en, this message translates to:
  /// **'To order · {count}'**
  String filmOrdersButton(int count);

  /// No description provided for @filmOrdersButtonWaiting.
  ///
  /// In en, this message translates to:
  /// **'To order · {count} · waiting: {waiting}'**
  String filmOrdersButtonWaiting(int count, int waiting);

  /// No description provided for @mdfSumTitle.
  ///
  /// In en, this message translates to:
  /// **'MDF summary'**
  String get mdfSumTitle;

  /// No description provided for @mdfSumWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get mdfSumWeek;

  /// No description provided for @mdfSumShare.
  ///
  /// In en, this message translates to:
  /// **'Copy the summary'**
  String get mdfSumShare;

  /// No description provided for @mdfSumCopied.
  ///
  /// In en, this message translates to:
  /// **'The summary is copied — paste it into WhatsApp.'**
  String get mdfSumCopied;

  /// No description provided for @mdfSumUp.
  ///
  /// In en, this message translates to:
  /// **'▲ {percent}% on the last'**
  String mdfSumUp(int percent);

  /// No description provided for @mdfSumDown.
  ///
  /// In en, this message translates to:
  /// **'▼ {percent}% on the last'**
  String mdfSumDown(int percent);

  /// No description provided for @mdfSumAvg.
  ///
  /// In en, this message translates to:
  /// **'Average order'**
  String get mdfSumAvg;

  /// No description provided for @mdfSumAvgNote.
  ///
  /// In en, this message translates to:
  /// **'{area} m² · {rate}/m²'**
  String mdfSumAvgNote(String area, String rate);

  /// No description provided for @mdfSumCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get mdfSumCustomers;

  /// No description provided for @mdfSumNewCustomers.
  ///
  /// In en, this message translates to:
  /// **'new: {count}'**
  String mdfSumNewCustomers(int count);

  /// No description provided for @mdfSumPlan.
  ///
  /// In en, this message translates to:
  /// **'The month: plan and forecast'**
  String get mdfSumPlan;

  /// No description provided for @mdfSumPlanDone.
  ///
  /// In en, this message translates to:
  /// **'Done this month'**
  String get mdfSumPlanDone;

  /// No description provided for @mdfSumGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get mdfSumGoal;

  /// No description provided for @mdfSumGoalOf.
  ///
  /// In en, this message translates to:
  /// **'{goal} m² · {percent}%'**
  String mdfSumGoalOf(String goal, int percent);

  /// No description provided for @mdfSumGoalNone.
  ///
  /// In en, this message translates to:
  /// **'No goal for the month — tap ✎ to set one.'**
  String get mdfSumGoalNone;

  /// No description provided for @mdfSumGoalSet.
  ///
  /// In en, this message translates to:
  /// **'The month’s goal'**
  String get mdfSumGoalSet;

  /// No description provided for @mdfSumGoalM2.
  ///
  /// In en, this message translates to:
  /// **'m² this month'**
  String get mdfSumGoalM2;

  /// No description provided for @mdfSumForecast.
  ///
  /// In en, this message translates to:
  /// **'At this pace by the month’s end ({days} d left)'**
  String mdfSumForecast(int days);

  /// No description provided for @mdfSumShop.
  ///
  /// In en, this message translates to:
  /// **'The shop’s load'**
  String get mdfSumShop;

  /// No description provided for @mdfSumInWork.
  ///
  /// In en, this message translates to:
  /// **'In work'**
  String get mdfSumInWork;

  /// No description provided for @mdfSumInWorkValue.
  ///
  /// In en, this message translates to:
  /// **'{area} m² · {count} orders'**
  String mdfSumInWorkValue(String area, int count);

  /// No description provided for @mdfSumPace.
  ///
  /// In en, this message translates to:
  /// **'The shop finishes'**
  String get mdfSumPace;

  /// No description provided for @mdfSumPaceValue.
  ///
  /// In en, this message translates to:
  /// **'{area} m² a day'**
  String mdfSumPaceValue(String area);

  /// No description provided for @mdfSumPaceUnknown.
  ///
  /// In en, this message translates to:
  /// **'The shop’s pace is not known yet: a few finished orders are needed.'**
  String get mdfSumPaceUnknown;

  /// No description provided for @mdfSumNewReady.
  ///
  /// In en, this message translates to:
  /// **'A new order would be ready'**
  String get mdfSumNewReady;

  /// No description provided for @mdfSumNewReadyValue.
  ///
  /// In en, this message translates to:
  /// **'in {days} d · {day}'**
  String mdfSumNewReadyValue(int days, String day);

  /// No description provided for @mdfSumOverdueNow.
  ///
  /// In en, this message translates to:
  /// **'Overdue now'**
  String get mdfSumOverdueNow;

  /// No description provided for @mdfSumTop.
  ///
  /// In en, this message translates to:
  /// **'Who orders most'**
  String get mdfSumTop;

  /// No description provided for @mdfSumTopValue.
  ///
  /// In en, this message translates to:
  /// **'{count} orders · {area} m²'**
  String mdfSumTopValue(int count, String area);

  /// No description provided for @mdfSumMaker.
  ///
  /// In en, this message translates to:
  /// **'furniture maker'**
  String get mdfSumMaker;

  /// No description provided for @mdfSumNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get mdfSumNew;

  /// No description provided for @mdfSumNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this period.'**
  String get mdfSumNothing;

  /// No description provided for @mdfSumAsleep.
  ///
  /// In en, this message translates to:
  /// **'Gone quiet — time to get in touch'**
  String get mdfSumAsleep;

  /// No description provided for @mdfSumAsleepNone.
  ///
  /// In en, this message translates to:
  /// **'Every customer orders in his usual rhythm.'**
  String get mdfSumAsleepNone;

  /// No description provided for @mdfSumAsleepRhythm.
  ///
  /// In en, this message translates to:
  /// **'usually every {rhythm} d · none for {days} d'**
  String mdfSumAsleepRhythm(int rhythm, int days);

  /// No description provided for @mdfSumAsleepOnce.
  ///
  /// In en, this message translates to:
  /// **'one order · none for {days} d'**
  String mdfSumAsleepOnce(int days);

  /// No description provided for @mdfSumGone.
  ///
  /// In en, this message translates to:
  /// **'gone'**
  String get mdfSumGone;

  /// No description provided for @mdfSumDozing.
  ///
  /// In en, this message translates to:
  /// **'dozing'**
  String get mdfSumDozing;

  /// No description provided for @mdfSumWakeText.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}! It has been a while — how are your orders? We can take facades in now, the lead times are good.'**
  String mdfSumWakeText(String name);

  /// No description provided for @mdfSumMore.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String mdfSumMore(int count);

  /// No description provided for @mdfSumFilms.
  ///
  /// In en, this message translates to:
  /// **'What is ordered · is there film enough'**
  String get mdfSumFilms;

  /// No description provided for @mdfSumFilmShort.
  ///
  /// In en, this message translates to:
  /// **'{metres} m short'**
  String mdfSumFilmShort(String metres);

  /// No description provided for @mdfSumFilmEnough.
  ///
  /// In en, this message translates to:
  /// **'enough'**
  String get mdfSumFilmEnough;

  /// No description provided for @mdfSumToOrder.
  ///
  /// In en, this message translates to:
  /// **'To order'**
  String get mdfSumToOrder;

  /// No description provided for @mdfSumOrdered.
  ///
  /// In en, this message translates to:
  /// **'«{decor}» is on the order list.'**
  String mdfSumOrdered(String decor);

  /// No description provided for @mdfSumDeadlines.
  ///
  /// In en, this message translates to:
  /// **'Deadlines and quality'**
  String get mdfSumDeadlines;

  /// No description provided for @mdfSumOnTime.
  ///
  /// In en, this message translates to:
  /// **'Handed over on time (of {count})'**
  String mdfSumOnTime(int count);

  /// No description provided for @mdfSumNoHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Nothing handed over in the period.'**
  String get mdfSumNoHandedOver;

  /// No description provided for @mdfSumLateAvg.
  ///
  /// In en, this message translates to:
  /// **'Late on average'**
  String get mdfSumLateAvg;

  /// No description provided for @mdfSumDays.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String mdfSumDays(String days);

  /// No description provided for @mdfSumRework.
  ///
  /// In en, this message translates to:
  /// **'Reworks and warranty'**
  String get mdfSumRework;

  /// No description provided for @mdfSumReworkValue.
  ///
  /// In en, this message translates to:
  /// **'{count} · {area} m² · {percent}%'**
  String mdfSumReworkValue(int count, String area, int percent);

  /// No description provided for @mdfSumReasons.
  ///
  /// In en, this message translates to:
  /// **'Why they came back: {list}'**
  String mdfSumReasons(String list);

  /// No description provided for @mdfSumDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts by age'**
  String get mdfSumDebts;

  /// No description provided for @mdfSumDebtWeek.
  ///
  /// In en, this message translates to:
  /// **'up to 7 days'**
  String get mdfSumDebtWeek;

  /// No description provided for @mdfSumDebtMonth.
  ///
  /// In en, this message translates to:
  /// **'8–30 days'**
  String get mdfSumDebtMonth;

  /// No description provided for @mdfSumDebtOlder.
  ///
  /// In en, this message translates to:
  /// **'over 30 days'**
  String get mdfSumDebtOlder;

  /// No description provided for @mdfSumDebtor.
  ///
  /// In en, this message translates to:
  /// **'{name} · {days} d'**
  String mdfSumDebtor(String name, int days);

  /// No description provided for @mdfSumManagers.
  ///
  /// In en, this message translates to:
  /// **'Who took the orders'**
  String get mdfSumManagers;

  /// No description provided for @mdfSumAlertOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String mdfSumAlertOverdue(int count);

  /// No description provided for @mdfSumAlertAtRisk.
  ///
  /// In en, this message translates to:
  /// **'{count} will miss their date'**
  String mdfSumAlertAtRisk(int count);

  /// No description provided for @mdfSumAlertDebt.
  ///
  /// In en, this message translates to:
  /// **'Owed over a month: {sum}'**
  String mdfSumAlertDebt(String sum);

  /// No description provided for @mdfSumAlertFilm.
  ///
  /// In en, this message translates to:
  /// **'Film short: {count}'**
  String mdfSumAlertFilm(int count);

  /// No description provided for @mdfSumStages.
  ///
  /// In en, this message translates to:
  /// **'Where the orders are now'**
  String get mdfSumStages;

  /// No description provided for @mdfSumIntake.
  ///
  /// In en, this message translates to:
  /// **'Taken in by day'**
  String get mdfSumIntake;

  /// No description provided for @mdfSumIntakeMonthly.
  ///
  /// In en, this message translates to:
  /// **'Taken in by month'**
  String get mdfSumIntakeMonthly;

  /// No description provided for @mdfSumIntakeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar for that day\'s orders.'**
  String get mdfSumIntakeHint;

  /// No description provided for @mdfSumIntakeDay.
  ///
  /// In en, this message translates to:
  /// **'{day}: {count} orders · {area} m² · {sum}'**
  String mdfSumIntakeDay(String day, int count, String area, String sum);

  /// No description provided for @mdfSumManagerValue.
  ///
  /// In en, this message translates to:
  /// **'{count} · {area} m² · {sum}'**
  String mdfSumManagerValue(int count, String area, String sum);

  /// No description provided for @mdfSumTextHead.
  ///
  /// In en, this message translates to:
  /// **'MDF summary {since} — {until}'**
  String mdfSumTextHead(String since, String until);

  /// No description provided for @mdfSumTextOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders: {count} · {area} m² · {sum}'**
  String mdfSumTextOrders(int count, String area, String sum);

  /// No description provided for @mdfSumTextMoney.
  ///
  /// In en, this message translates to:
  /// **'Received: {paid} · owed: {debt}'**
  String mdfSumTextMoney(String paid, String debt);

  /// No description provided for @mdfSumTextChange.
  ///
  /// In en, this message translates to:
  /// **'Volume on the last period: {percent}%'**
  String mdfSumTextChange(String percent);

  /// No description provided for @mdfSumTextForecast.
  ///
  /// In en, this message translates to:
  /// **'Month forecast: {area} m²'**
  String mdfSumTextForecast(String area);

  /// No description provided for @mdfSumTextAsleep.
  ///
  /// In en, this message translates to:
  /// **'Customers gone quiet: {count}'**
  String mdfSumTextAsleep(int count);

  /// No description provided for @mdfOrdersSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get mdfOrdersSummary;

  /// No description provided for @mdfPressOpen.
  ///
  /// In en, this message translates to:
  /// **'Press layout'**
  String get mdfPressOpen;

  /// No description provided for @mdfPressFilm.
  ///
  /// In en, this message translates to:
  /// **'Film {metres} m · {loads} loads'**
  String mdfPressFilm(String metres, int loads);

  /// No description provided for @mdfPressCorrected.
  ///
  /// In en, this message translates to:
  /// **'corrected by hand'**
  String get mdfPressCorrected;

  /// No description provided for @mdfPressSaved.
  ///
  /// In en, this message translates to:
  /// **'smart layout −{metres} m'**
  String mdfPressSaved(String metres);

  /// No description provided for @mdfPressTooBig.
  ///
  /// In en, this message translates to:
  /// **'too big for the press: {count}'**
  String mdfPressTooBig(int count);

  /// No description provided for @pressSmartSaved.
  ///
  /// In en, this message translates to:
  /// **'Smart layout: the plain one would take {plain} m — {saved} m saved.'**
  String pressSmartSaved(String plain, String saved);

  /// No description provided for @pressEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit the layout'**
  String get pressEdit;

  /// No description provided for @pressEditReset.
  ///
  /// In en, this message translates to:
  /// **'Lay out again'**
  String get pressEditReset;

  /// No description provided for @pressEditSave.
  ///
  /// In en, this message translates to:
  /// **'Keep my layout'**
  String get pressEditSave;

  /// No description provided for @pressEditTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {metres} m · the system laid out {auto} m'**
  String pressEditTotal(String metres, String auto);

  /// No description provided for @pressEditClash.
  ///
  /// In en, this message translates to:
  /// **'Red parts lie too close to each other or off the table — move them.'**
  String get pressEditClash;

  /// No description provided for @pressEditHint.
  ///
  /// In en, this message translates to:
  /// **'Press a part and drag it. Let go and it lines up by itself.'**
  String get pressEditHint;

  /// No description provided for @pressEditPart.
  ///
  /// In en, this message translates to:
  /// **'Position {pos} · {size}'**
  String pressEditPart(int pos, String size);

  /// No description provided for @pressEditRotate.
  ///
  /// In en, this message translates to:
  /// **'Turn'**
  String get pressEditRotate;

  /// No description provided for @pressEditMoveTo.
  ///
  /// In en, this message translates to:
  /// **'To load {count}'**
  String pressEditMoveTo(int count);

  /// No description provided for @pressEditMoveNew.
  ///
  /// In en, this message translates to:
  /// **'To a new load'**
  String get pressEditMoveNew;

  /// No description provided for @pressEditSectionAuto.
  ///
  /// In en, this message translates to:
  /// **'Section: auto'**
  String get pressEditSectionAuto;

  /// No description provided for @pressEditSection.
  ///
  /// In en, this message translates to:
  /// **'Section {metres} m'**
  String pressEditSection(String metres);

  /// No description provided for @pressManual.
  ///
  /// In en, this message translates to:
  /// **'Own layout — the parts were placed by hand.'**
  String get pressManual;

  /// No description provided for @pressApprove.
  ///
  /// In en, this message translates to:
  /// **'Layout checked — start'**
  String get pressApprove;

  /// No description provided for @pressApproved.
  ///
  /// In en, this message translates to:
  /// **'Layout checked: {by}, {at}'**
  String pressApproved(String by, String at);

  /// No description provided for @pressUnapprove.
  ///
  /// In en, this message translates to:
  /// **'Take the mark off'**
  String get pressUnapprove;

  /// No description provided for @pressShortAdded.
  ///
  /// In en, this message translates to:
  /// **'Film is short, added to the order list: {films} m'**
  String pressShortAdded(String films);

  /// No description provided for @pressPrintApproved.
  ///
  /// In en, this message translates to:
  /// **'Layout approved: {by}, {at}'**
  String pressPrintApproved(String by, String at);

  /// No description provided for @pressPrintSigns.
  ///
  /// In en, this message translates to:
  /// **'Operator ____________   Foreman ____________'**
  String get pressPrintSigns;

  /// No description provided for @mdfPressManual.
  ///
  /// In en, this message translates to:
  /// **'own layout'**
  String get mdfPressManual;

  /// No description provided for @mdfPressApproved.
  ///
  /// In en, this message translates to:
  /// **'layout checked'**
  String get mdfPressApproved;

  /// No description provided for @filmFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All · {n}'**
  String filmFilterAll(int n);

  /// No description provided for @filmFilterHave.
  ///
  /// In en, this message translates to:
  /// **'In stock · {n}'**
  String filmFilterHave(int n);

  /// No description provided for @filmFilterOnWay.
  ///
  /// In en, this message translates to:
  /// **'On the way · {n}'**
  String filmFilterOnWay(int n);

  /// No description provided for @filmFilterNone.
  ///
  /// In en, this message translates to:
  /// **'Out of stock · {n}'**
  String filmFilterNone(int n);

  /// No description provided for @filmStockSearch.
  ///
  /// In en, this message translates to:
  /// **'Find a film'**
  String get filmStockSearch;

  /// No description provided for @filmComingRolls.
  ///
  /// In en, this message translates to:
  /// **'{count} rolls on the way · {metres} m · due {day}'**
  String filmComingRolls(int count, String metres, String day);

  /// No description provided for @filmDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'lasts ≈ {days} d'**
  String filmDaysLeft(int days);

  /// No description provided for @filmWantShort.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get filmWantShort;

  /// No description provided for @filmM.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get filmM;

  /// No description provided for @filmReceiveLineSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get filmReceiveLineSum;

  /// No description provided for @filmReceivePerMWithDelivery.
  ///
  /// In en, this message translates to:
  /// **'a metre with delivery {perM}'**
  String filmReceivePerMWithDelivery(String perM);

  /// No description provided for @filmPriceUp.
  ///
  /// In en, this message translates to:
  /// **'Dearer than last time: it was {old}/m{since} · {change}'**
  String filmPriceUp(String old, String since, String change);

  /// No description provided for @filmPriceDown.
  ///
  /// In en, this message translates to:
  /// **'Cheaper than last time: it was {old}/m{since} · {change}'**
  String filmPriceDown(String old, String since, String change);

  /// No description provided for @filmReceiveWhere.
  ///
  /// In en, this message translates to:
  /// **'Where it goes'**
  String get filmReceiveWhere;

  /// No description provided for @filmReceiveIntoProduction.
  ///
  /// In en, this message translates to:
  /// **'Into production · №{order} · {name} {due}'**
  String filmReceiveIntoProduction(String order, String name, String due);

  /// No description provided for @filmReceiveToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Sale · {name}'**
  String filmReceiveToCustomer(String name);

  /// No description provided for @filmReceiveToShelf.
  ///
  /// In en, this message translates to:
  /// **'To the shelf · free to sell'**
  String get filmReceiveToShelf;

  /// No description provided for @filmReceiveShort.
  ///
  /// In en, this message translates to:
  /// **'{metres} m short'**
  String filmReceiveShort(String metres);

  /// No description provided for @filmReceiveShortToList.
  ///
  /// In en, this message translates to:
  /// **'To the order list'**
  String get filmReceiveShortToList;

  /// No description provided for @filmReceiveShortListed.
  ///
  /// In en, this message translates to:
  /// **'on the order list'**
  String get filmReceiveShortListed;

  /// No description provided for @filmReceiveToProduction.
  ///
  /// In en, this message translates to:
  /// **'Into production'**
  String get filmReceiveToProduction;

  /// No description provided for @filmReceiveToSale.
  ///
  /// In en, this message translates to:
  /// **'Sale to a customer'**
  String get filmReceiveToSale;

  /// No description provided for @filmReceiveNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No facade orders lack this film right now.'**
  String get filmReceiveNoOrders;

  /// No description provided for @filmReceiveOrderLine.
  ///
  /// In en, this message translates to:
  /// **'№{order} · {name} · needs {metres} m · due {due}'**
  String filmReceiveOrderLine(
    String order,
    String name,
    String metres,
    String due,
  );

  /// No description provided for @filmReceiveOrdersWait.
  ///
  /// In en, this message translates to:
  /// **'facade orders waiting: {count}'**
  String filmReceiveOrdersWait(int count);

  /// No description provided for @filmReceiveFilmTotal.
  ///
  /// In en, this message translates to:
  /// **'Film · {count} rolls · {metres} m'**
  String filmReceiveFilmTotal(int count, String metres);

  /// No description provided for @filmReceiveGrand.
  ///
  /// In en, this message translates to:
  /// **'Total bought'**
  String get filmReceiveGrand;

  /// No description provided for @filmReceivePerM.
  ///
  /// In en, this message translates to:
  /// **'A metre with delivery: {films}'**
  String filmReceivePerM(String films);

  /// No description provided for @filmReceiveSumProduction.
  ///
  /// In en, this message translates to:
  /// **'into production {metres} m'**
  String filmReceiveSumProduction(String metres);

  /// No description provided for @filmReceiveSumSale.
  ///
  /// In en, this message translates to:
  /// **'sale {metres} m'**
  String filmReceiveSumSale(String metres);

  /// No description provided for @filmReceiveSumShelf.
  ///
  /// In en, this message translates to:
  /// **'shelf {metres} m'**
  String filmReceiveSumShelf(String metres);

  /// No description provided for @pressFill.
  ///
  /// In en, this message translates to:
  /// **'{percent}% full · {waste} m² waste'**
  String pressFill(int percent, String waste);

  /// No description provided for @pressPositionsHint.
  ///
  /// In en, this message translates to:
  /// **'Point at a part or tap a position — it lights up on every load.'**
  String get pressPositionsHint;

  /// No description provided for @pressPositionInfo.
  ///
  /// In en, this message translates to:
  /// **'Position {pos} · {size} · {count} in all · on loads {loads}'**
  String pressPositionInfo(int pos, String size, int count, String loads);

  /// No description provided for @pressPositionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pcs'**
  String pressPositionCount(int count);

  /// No description provided for @mdfPressCheckedBy.
  ///
  /// In en, this message translates to:
  /// **'✓ layout checked by {by}'**
  String mdfPressCheckedBy(String by);

  /// No description provided for @mdfPressNotChecked.
  ///
  /// In en, this message translates to:
  /// **'layout not checked'**
  String get mdfPressNotChecked;

  /// No description provided for @pressPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Press'**
  String get pressPanelTitle;

  /// No description provided for @pressSectionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the section'**
  String get pressSectionRemove;

  /// No description provided for @pressLevel.
  ///
  /// In en, this message translates to:
  /// **'How hard to look'**
  String get pressLevel;

  /// No description provided for @pressLevelFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get pressLevelFast;

  /// No description provided for @pressLevelSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get pressLevelSmart;

  /// No description provided for @pressLevelMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get pressLevelMax;

  /// No description provided for @pressDirection.
  ///
  /// In en, this message translates to:
  /// **'Laying'**
  String get pressDirection;

  /// No description provided for @pressDirectionAny.
  ///
  /// In en, this message translates to:
  /// **'As is best'**
  String get pressDirectionAny;

  /// No description provided for @pressDirectionAlong.
  ///
  /// In en, this message translates to:
  /// **'Along'**
  String get pressDirectionAlong;

  /// No description provided for @pressDirectionAcross.
  ///
  /// In en, this message translates to:
  /// **'Across'**
  String get pressDirectionAcross;

  /// No description provided for @pressRotate.
  ///
  /// In en, this message translates to:
  /// **'Turn parts'**
  String get pressRotate;

  /// No description provided for @pressRotateYes.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get pressRotateYes;

  /// No description provided for @pressRotateNo.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get pressRotateNo;

  /// No description provided for @pressRotateTextured.
  ///
  /// In en, this message translates to:
  /// **'A textured film — never turned.'**
  String get pressRotateTextured;

  /// No description provided for @pressKeepForOrder.
  ///
  /// In en, this message translates to:
  /// **'For this order only'**
  String get pressKeepForOrder;

  /// No description provided for @pressKeepForPress.
  ///
  /// In en, this message translates to:
  /// **'Keep for the press'**
  String get pressKeepForPress;

  /// No description provided for @pressKeepForPressHint.
  ///
  /// In en, this message translates to:
  /// **'«For the press» changes every new layout.'**
  String get pressKeepForPressHint;

  /// No description provided for @pressTuneReset.
  ///
  /// In en, this message translates to:
  /// **'Back to the press\'s own'**
  String get pressTuneReset;

  /// No description provided for @pressTuneKept.
  ///
  /// In en, this message translates to:
  /// **'Layout kept for this order'**
  String get pressTuneKept;

  /// No description provided for @pressTuneSaved.
  ///
  /// In en, this message translates to:
  /// **'Press settings saved'**
  String get pressTuneSaved;

  /// No description provided for @pressWas.
  ///
  /// In en, this message translates to:
  /// **'Was {metres} m'**
  String pressWas(String metres);

  /// No description provided for @pressWillBe.
  ///
  /// In en, this message translates to:
  /// **'Will be {metres} m'**
  String pressWillBe(String metres);

  /// No description provided for @pressSaves.
  ///
  /// In en, this message translates to:
  /// **'saves {metres} m'**
  String pressSaves(String metres);

  /// No description provided for @pressCostsMore.
  ///
  /// In en, this message translates to:
  /// **'{metres} m more'**
  String pressCostsMore(String metres);

  /// No description provided for @pressSame.
  ///
  /// In en, this message translates to:
  /// **'the same'**
  String get pressSame;

  /// No description provided for @pressUnitM.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get pressUnitM;

  /// No description provided for @pressUnitMm.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get pressUnitMm;

  /// No description provided for @pressMm.
  ///
  /// In en, this message translates to:
  /// **'{value} mm'**
  String pressMm(int value);

  /// No description provided for @filmSalesToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get filmSalesToday;

  /// No description provided for @filmSalesWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get filmSalesWeek;

  /// No description provided for @filmSalesMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get filmSalesMonth;

  /// No description provided for @filmSalesPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get filmSalesPeriod;

  /// No description provided for @filmSalesAll.
  ///
  /// In en, this message translates to:
  /// **'All · {count}'**
  String filmSalesAll(int count);

  /// No description provided for @filmSalesPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid · {count}'**
  String filmSalesPaid(int count);

  /// No description provided for @filmSalesDebt.
  ///
  /// In en, this message translates to:
  /// **'Owing · {count}'**
  String filmSalesDebt(int count);

  /// No description provided for @filmSalesWholesale.
  ///
  /// In en, this message translates to:
  /// **'Trade · {count}'**
  String filmSalesWholesale(int count);

  /// No description provided for @filmSalesSearch.
  ///
  /// In en, this message translates to:
  /// **'customer, film'**
  String get filmSalesSearch;

  /// No description provided for @filmSalesSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get filmSalesSold;

  /// No description provided for @filmSalesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sales'**
  String filmSalesCount(int count);

  /// No description provided for @filmSalesMetres.
  ///
  /// In en, this message translates to:
  /// **'Metres'**
  String get filmSalesMetres;

  /// No description provided for @filmSalesAmount.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get filmSalesAmount;

  /// No description provided for @filmSalesChange.
  ///
  /// In en, this message translates to:
  /// **'{change}% on the last'**
  String filmSalesChange(String change);

  /// No description provided for @filmSalesProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get filmSalesProfit;

  /// No description provided for @filmSalesUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get filmSalesUnpaid;

  /// No description provided for @filmSalesDebtors.
  ///
  /// In en, this message translates to:
  /// **'customers: {count}'**
  String filmSalesDebtors(int count);

  /// No description provided for @filmSalesTodayOn.
  ///
  /// In en, this message translates to:
  /// **'Today, {day}'**
  String filmSalesTodayOn(String day);

  /// No description provided for @filmSalesYesterdayOn.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {day}'**
  String filmSalesYesterdayOn(String day);

  /// No description provided for @filmSalesWholesaleMark.
  ///
  /// In en, this message translates to:
  /// **'trade'**
  String get filmSalesWholesaleMark;

  /// No description provided for @filmSalesPaidMark.
  ///
  /// In en, this message translates to:
  /// **'✓ paid'**
  String get filmSalesPaidMark;

  /// No description provided for @filmSalesPartly.
  ///
  /// In en, this message translates to:
  /// **'part · owing {sum}'**
  String filmSalesPartly(String sum);

  /// No description provided for @filmSalesPerM.
  ///
  /// In en, this message translates to:
  /// **'{price}/m'**
  String filmSalesPerM(String price);

  /// No description provided for @filmDebtorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Owing · {sum}'**
  String filmDebtorsTitle(String sum);

  /// No description provided for @filmDebtorsShowSales.
  ///
  /// In en, this message translates to:
  /// **'Show their sales'**
  String get filmDebtorsShowSales;

  /// No description provided for @filmDebtorLine.
  ///
  /// In en, this message translates to:
  /// **'{sum} · {days} d'**
  String filmDebtorLine(String sum, int days);

  /// No description provided for @filmSaleRepeat.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get filmSaleRepeat;

  /// No description provided for @filmSaleBelow.
  ///
  /// In en, this message translates to:
  /// **'Below cost: bought at {cost}/m — a loss of ≈ {loss}'**
  String filmSaleBelow(String cost, String loss);

  /// No description provided for @filmSaleBelowWhy.
  ///
  /// In en, this message translates to:
  /// **'Why below cost?'**
  String get filmSaleBelowWhy;

  /// No description provided for @filmSaleBelowRest.
  ///
  /// In en, this message translates to:
  /// **'end of a roll'**
  String get filmSaleBelowRest;

  /// No description provided for @filmSaleBelowDefect.
  ///
  /// In en, this message translates to:
  /// **'defect'**
  String get filmSaleBelowDefect;

  /// No description provided for @filmSaleBelowAgreed.
  ///
  /// In en, this message translates to:
  /// **'agreed'**
  String get filmSaleBelowAgreed;

  /// No description provided for @filmSaleToOrders.
  ///
  /// In en, this message translates to:
  /// **'To the order list'**
  String get filmSaleToOrders;

  /// No description provided for @filmSaleUsually.
  ///
  /// In en, this message translates to:
  /// **'usually takes {film}'**
  String filmSaleUsually(String film);

  /// No description provided for @filmSaleEvery.
  ///
  /// In en, this message translates to:
  /// **'every {days} d'**
  String filmSaleEvery(int days);

  /// No description provided for @filmSaleNoDebt.
  ///
  /// In en, this message translates to:
  /// **'no debt'**
  String get filmSaleNoDebt;

  /// No description provided for @filmSaleLikeLast.
  ///
  /// In en, this message translates to:
  /// **'Like last time: {films}'**
  String filmSaleLikeLast(String films);

  /// No description provided for @filmDebtLimit.
  ///
  /// In en, this message translates to:
  /// **'Debt limit, ₸'**
  String get filmDebtLimit;

  /// No description provided for @filmDebtLimitDays.
  ///
  /// In en, this message translates to:
  /// **'Owing no longer, days'**
  String get filmDebtLimitDays;

  /// No description provided for @filmLimitDays.
  ///
  /// In en, this message translates to:
  /// **'up to {days} d'**
  String filmLimitDays(int days);

  /// No description provided for @filmSaleOverLimit.
  ///
  /// In en, this message translates to:
  /// **'The debt becomes {sum} — over the limit {limit}'**
  String filmSaleOverLimit(String sum, String limit);

  /// No description provided for @filmSaleOverDays.
  ///
  /// In en, this message translates to:
  /// **'owing {days} d — longer than {limit} d'**
  String filmSaleOverDays(int days, int limit);

  /// No description provided for @filmCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to call · {count}'**
  String filmCallTitle(int count);

  /// No description provided for @filmCallDebt.
  ///
  /// In en, this message translates to:
  /// **'{name} — owes {sum}, {days} d'**
  String filmCallDebt(String name, String sum, int days);

  /// No description provided for @filmCallRhythm.
  ///
  /// In en, this message translates to:
  /// **'{name} — buys every {every} d, none for {idle} d'**
  String filmCallRhythm(String name, int every, int idle);

  /// No description provided for @filmCustomerAverage.
  ///
  /// In en, this message translates to:
  /// **'Average sale'**
  String get filmCustomerAverage;

  /// No description provided for @filmCustomerRhythm.
  ///
  /// In en, this message translates to:
  /// **'Buys'**
  String get filmCustomerRhythm;

  /// No description provided for @filmCustomerLimit.
  ///
  /// In en, this message translates to:
  /// **'Debt limit'**
  String get filmCustomerLimit;

  /// No description provided for @filmStatement.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get filmStatement;

  /// No description provided for @filmStatementCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer: {name}'**
  String filmStatementCustomer(String name);

  /// No description provided for @filmStatementOn.
  ///
  /// In en, this message translates to:
  /// **'as of {day}'**
  String filmStatementOn(String day);

  /// No description provided for @filmStatementDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get filmStatementDate;

  /// No description provided for @filmStatementWhat.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get filmStatementWhat;

  /// No description provided for @filmStatementSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get filmStatementSold;

  /// No description provided for @filmStatementPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get filmStatementPaid;

  /// No description provided for @filmStatementBalance.
  ///
  /// In en, this message translates to:
  /// **'Owing'**
  String get filmStatementBalance;

  /// No description provided for @filmStatementSale.
  ///
  /// In en, this message translates to:
  /// **'Film: {films}'**
  String filmStatementSale(String films);

  /// No description provided for @filmStatementPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get filmStatementPayment;

  /// No description provided for @filmStatementOwes.
  ///
  /// In en, this message translates to:
  /// **'The customer owes {sum}'**
  String filmStatementOwes(String sum);

  /// No description provided for @filmStatementSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled, nothing owed.'**
  String get filmStatementSettled;

  /// No description provided for @filmStatementSigns.
  ///
  /// In en, this message translates to:
  /// **'Seller ____________     Customer ____________'**
  String get filmStatementSigns;

  /// No description provided for @mdfMarginTitle.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get mdfMarginTitle;

  /// No description provided for @mdfMarginRevenue.
  ///
  /// In en, this message translates to:
  /// **'Order total'**
  String get mdfMarginRevenue;

  /// No description provided for @mdfMarginMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get mdfMarginMaterial;

  /// No description provided for @mdfMarginWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get mdfMarginWork;

  /// No description provided for @mdfMarginEstimate.
  ///
  /// In en, this message translates to:
  /// **'An estimate at today\'s prices: nothing written off yet'**
  String get mdfMarginEstimate;

  /// No description provided for @mdfMarginMissing.
  ///
  /// In en, this message translates to:
  /// **'No price: {names}'**
  String mdfMarginMissing(String names);

  /// No description provided for @mdfMarginNotCounted.
  ///
  /// In en, this message translates to:
  /// **'Not counted: paint, glue, power, delivery'**
  String get mdfMarginNotCounted;

  /// No description provided for @mdfSumMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin of orders handed over'**
  String get mdfSumMargin;

  /// No description provided for @mdfSumMarginOrders.
  ///
  /// In en, this message translates to:
  /// **'Handed over: {count}'**
  String mdfSumMarginOrders(String count);

  /// No description provided for @mdfSumMarginEstimated.
  ///
  /// In en, this message translates to:
  /// **'By estimate, nothing written off: {count}'**
  String mdfSumMarginEstimated(String count);

  /// No description provided for @mdfSumMarginLowest.
  ///
  /// In en, this message translates to:
  /// **'Earned least'**
  String get mdfSumMarginLowest;

  /// No description provided for @mdfPaintTitle.
  ///
  /// In en, this message translates to:
  /// **'Paint shop'**
  String get mdfPaintTitle;

  /// No description provided for @mdfPaintHint.
  ///
  /// In en, this message translates to:
  /// **'What to paint by colour, what is drying'**
  String get mdfPaintHint;

  /// No description provided for @mdfPaintDryHours.
  ///
  /// In en, this message translates to:
  /// **'Drying time, hours'**
  String get mdfPaintDryHours;

  /// No description provided for @mdfPaintEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to paint'**
  String get mdfPaintEmpty;

  /// No description provided for @mdfPaintSummary.
  ///
  /// In en, this message translates to:
  /// **'To paint {waiting} · drying {drying} · on the way {coming}'**
  String mdfPaintSummary(String waiting, String drying, String coming);

  /// No description provided for @mdfPaintDrying.
  ///
  /// In en, this message translates to:
  /// **'Drying ({hours} h)'**
  String mdfPaintDrying(int hours);

  /// No description provided for @mdfPaintDry.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get mdfPaintDry;

  /// No description provided for @mdfPaintLeft.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min left · dry {day} at {time}'**
  String mdfPaintLeft(String hours, String minutes, String day, String time);

  /// No description provided for @mdfPaintMarkPainted.
  ///
  /// In en, this message translates to:
  /// **'Mark painted'**
  String get mdfPaintMarkPainted;

  /// No description provided for @mdfPaintUndo.
  ///
  /// In en, this message translates to:
  /// **'Not drying'**
  String get mdfPaintUndo;

  /// No description provided for @mdfPaintByColour.
  ///
  /// In en, this message translates to:
  /// **'To paint, by colour'**
  String get mdfPaintByColour;

  /// No description provided for @mdfPaintByColourHint.
  ///
  /// In en, this message translates to:
  /// **'The biggest colour first: mixed once, the gun cleaned once.'**
  String get mdfPaintByColourHint;

  /// No description provided for @mdfPaintColourNote.
  ///
  /// In en, this message translates to:
  /// **'{area} · orders: {orders}'**
  String mdfPaintColourNote(String area, String orders);

  /// No description provided for @mdfPaintStartDrying.
  ///
  /// In en, this message translates to:
  /// **'Painted — dry'**
  String get mdfPaintStartDrying;

  /// No description provided for @mdfPaintPopular.
  ///
  /// In en, this message translates to:
  /// **'Most painted colours, 90 days'**
  String get mdfPaintPopular;

  /// No description provided for @mdfPaintSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mdfPaintSave;

  /// No description provided for @mdfTagClientPaint.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s paint'**
  String get mdfTagClientPaint;

  /// No description provided for @mdfTagClientParts.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s LMDF'**
  String get mdfTagClientParts;

  /// No description provided for @mdfClientPaintBrought.
  ///
  /// In en, this message translates to:
  /// **'Paint brought'**
  String get mdfClientPaintBrought;

  /// No description provided for @mdfClientPaintWhat.
  ///
  /// In en, this message translates to:
  /// **'What was brought (e.g. 2 cans × 3 l)'**
  String get mdfClientPaintWhat;

  /// No description provided for @mdfClientPaintHere.
  ///
  /// In en, this message translates to:
  /// **'here'**
  String get mdfClientPaintHere;

  /// No description provided for @mdfClientPaintWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for paint'**
  String get mdfClientPaintWaiting;

  /// No description provided for @mdfPaintSettings.
  ///
  /// In en, this message translates to:
  /// **'Paint settings'**
  String get mdfPaintSettings;

  /// No description provided for @mdfPaintDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount for own paint, ₸/m²'**
  String get mdfPaintDiscount;

  /// No description provided for @mdfPaintDiscountHint.
  ///
  /// In en, this message translates to:
  /// **'Taken off the m² price when «Customer\'s paint» is on'**
  String get mdfPaintDiscountHint;

  /// No description provided for @mdfPaintComing.
  ///
  /// In en, this message translates to:
  /// **'On their way to you'**
  String get mdfPaintComing;

  /// No description provided for @mdfPaintNowAt.
  ///
  /// In en, this message translates to:
  /// **'now: {stage}'**
  String mdfPaintNowAt(String stage);

  /// No description provided for @mdfPaintTwoSided.
  ///
  /// In en, this message translates to:
  /// **'2 sides'**
  String get mdfPaintTwoSided;

  /// No description provided for @mdfTagClientFilm.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s film'**
  String get mdfTagClientFilm;

  /// No description provided for @mdfClientShort.
  ///
  /// In en, this message translates to:
  /// **'customer\'s'**
  String get mdfClientShort;

  /// No description provided for @mdfKpiOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get mdfKpiOverdue;

  /// No description provided for @mdfKpiDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due today or tomorrow'**
  String get mdfKpiDueSoon;

  /// No description provided for @mdfKpiReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to hand over'**
  String get mdfKpiReady;

  /// No description provided for @mdfKpiDebt.
  ///
  /// In en, this message translates to:
  /// **'Customers owe'**
  String get mdfKpiDebt;

  /// No description provided for @mdfKpiDebtors.
  ///
  /// In en, this message translates to:
  /// **'customers: {count}'**
  String mdfKpiDebtors(String count);

  /// No description provided for @mdfSectionOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get mdfSectionOverdue;

  /// No description provided for @mdfSectionSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get mdfSectionSoon;

  /// No description provided for @mdfSectionShop.
  ///
  /// In en, this message translates to:
  /// **'In the shop'**
  String get mdfSectionShop;

  /// No description provided for @mdfSectionReady.
  ///
  /// In en, this message translates to:
  /// **'Ready — waiting for the customer'**
  String get mdfSectionReady;

  /// No description provided for @mdfSectionDraft.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get mdfSectionDraft;

  /// No description provided for @mdfSectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get mdfSectionClosed;

  /// No description provided for @mdfRowNowAt.
  ///
  /// In en, this message translates to:
  /// **'now: {stage}'**
  String mdfRowNowAt(String stage);

  /// No description provided for @mdfRowLate.
  ///
  /// In en, this message translates to:
  /// **'{days} d late'**
  String mdfRowLate(String days);

  /// No description provided for @mdfRowDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'in {days} d'**
  String mdfRowDaysLeft(String days);

  /// No description provided for @mdfRowToday.
  ///
  /// In en, this message translates to:
  /// **'due today'**
  String get mdfRowToday;

  /// No description provided for @mdfRowReadyFor.
  ///
  /// In en, this message translates to:
  /// **'ready {days} d'**
  String mdfRowReadyFor(String days);

  /// No description provided for @mdfRowPaid.
  ///
  /// In en, this message translates to:
  /// **'paid'**
  String get mdfRowPaid;

  /// No description provided for @mdfFilterDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get mdfFilterDueSoon;

  /// No description provided for @filmCashOpening.
  ///
  /// In en, this message translates to:
  /// **'Cash at the start'**
  String get filmCashOpening;

  /// No description provided for @filmCashOpeningNote.
  ///
  /// In en, this message translates to:
  /// **'counted {day}'**
  String filmCashOpeningNote(String day);

  /// No description provided for @filmCashQuiet.
  ///
  /// In en, this message translates to:
  /// **'No money moved in this period.'**
  String get filmCashQuiet;

  /// No description provided for @filmFigOnHand.
  ///
  /// In en, this message translates to:
  /// **'On the shelf'**
  String get filmFigOnHand;

  /// No description provided for @filmFigOnWay.
  ///
  /// In en, this message translates to:
  /// **'On its way'**
  String get filmFigOnWay;

  /// No description provided for @filmFigRolls.
  ///
  /// In en, this message translates to:
  /// **'deliveries: {count}'**
  String filmFigRolls(int count);

  /// No description provided for @filmFigRunsOut.
  ///
  /// In en, this message translates to:
  /// **'Running out'**
  String get filmFigRunsOut;

  /// No description provided for @filmFigRunsOutNote.
  ///
  /// In en, this message translates to:
  /// **'under {days} days left'**
  String filmFigRunsOutNote(int days);

  /// No description provided for @filmFigToOrder.
  ///
  /// In en, this message translates to:
  /// **'To order'**
  String get filmFigToOrder;

  /// No description provided for @filmFigToOrderNote.
  ///
  /// In en, this message translates to:
  /// **'≈ {metres} m'**
  String filmFigToOrderNote(String metres);

  /// No description provided for @filmStockBought.
  ///
  /// In en, this message translates to:
  /// **'bought at {price}/m'**
  String filmStockBought(String price);

  /// No description provided for @filmStockOrder.
  ///
  /// In en, this message translates to:
  /// **'order {metres} m'**
  String filmStockOrder(String metres);

  /// No description provided for @filmSalesAverage.
  ///
  /// In en, this message translates to:
  /// **'Average sale'**
  String get filmSalesAverage;

  /// No description provided for @filmSalesQuietToday.
  ///
  /// In en, this message translates to:
  /// **'No sales yet today'**
  String get filmSalesQuietToday;

  /// No description provided for @filmSalesYesterdayWas.
  ///
  /// In en, this message translates to:
  /// **'yesterday: {count}, {metres} m'**
  String filmSalesYesterdayWas(String count, String metres);

  /// No description provided for @filmSalesByDay.
  ///
  /// In en, this message translates to:
  /// **'Sold by day, m'**
  String get filmSalesByDay;

  /// No description provided for @filmSalesChartA11y.
  ///
  /// In en, this message translates to:
  /// **'Metres sold by day; {metres} m in all'**
  String filmSalesChartA11y(String metres);

  /// No description provided for @filmSalesTopFilms.
  ///
  /// In en, this message translates to:
  /// **'Films that sold most'**
  String get filmSalesTopFilms;

  /// No description provided for @filmSalesTopCustomers.
  ///
  /// In en, this message translates to:
  /// **'Who bought most'**
  String get filmSalesTopCustomers;

  /// No description provided for @filmSupOwed.
  ///
  /// In en, this message translates to:
  /// **'We owe'**
  String get filmSupOwed;

  /// No description provided for @filmSupOwedTo.
  ///
  /// In en, this message translates to:
  /// **'suppliers: {count}'**
  String filmSupOwedTo(int count);

  /// No description provided for @filmSupChipOwed.
  ///
  /// In en, this message translates to:
  /// **'we owe {amount}'**
  String filmSupChipOwed(String amount);

  /// No description provided for @filmSupChipOnTime.
  ///
  /// In en, this message translates to:
  /// **'on time {onTime} of {rolls}'**
  String filmSupChipOnTime(int onTime, int rolls);

  /// No description provided for @filmSupChipPrice.
  ///
  /// In en, this message translates to:
  /// **'price {change}%'**
  String filmSupChipPrice(String change);

  /// No description provided for @filmTeamPlanNeed.
  ///
  /// In en, this message translates to:
  /// **'{days} days left — {metres} m a day'**
  String filmTeamPlanNeed(int days, String metres);

  /// No description provided for @filmTeamNoPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Set the month\'s plan: the bonus share depends on it.'**
  String get filmTeamNoPlanHint;

  /// No description provided for @filmTeamSetPlan.
  ///
  /// In en, this message translates to:
  /// **'Set the plan'**
  String get filmTeamSetPlan;

  /// No description provided for @filmTeamMarginM.
  ///
  /// In en, this message translates to:
  /// **'{margin}/m'**
  String filmTeamMarginM(String margin);

  /// No description provided for @filmTeamOwed.
  ///
  /// In en, this message translates to:
  /// **'his customers owe {amount}'**
  String filmTeamOwed(String amount);
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
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
