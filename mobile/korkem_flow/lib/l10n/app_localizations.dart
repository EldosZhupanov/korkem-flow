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

  /// No description provided for @chatEmptyThreads.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatEmptyThreads;

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

  /// Error text for an individual tile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get todayTileError;

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
