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

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
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
  /// **'Message KORKEM AI…'**
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
