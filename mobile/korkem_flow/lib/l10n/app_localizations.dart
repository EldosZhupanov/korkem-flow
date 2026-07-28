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

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

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

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

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

  /// Persistent banner while the device has no connectivity
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing saved data.'**
  String get offlineBanner;

  /// Freshness indicator on cached content
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String staleData(String time);

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

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @loadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more'**
  String get loadingMore;

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

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

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

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @profileServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get profileServer;

  /// CRM Deal stage. Display only — the wire value 'Qualification' is what the backend stores.
  ///
  /// In en, this message translates to:
  /// **'Qualification'**
  String get dealStatusQualification;

  /// No description provided for @dealStatusDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo / Making'**
  String get dealStatusDemo;

  /// No description provided for @dealStatusProposal.
  ///
  /// In en, this message translates to:
  /// **'Proposal'**
  String get dealStatusProposal;

  /// No description provided for @dealStatusNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Negotiation'**
  String get dealStatusNegotiation;

  /// No description provided for @dealStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to close'**
  String get dealStatusReady;

  /// No description provided for @dealStatusWon.
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get dealStatusWon;

  /// No description provided for @dealStatusLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get dealStatusLost;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium priority'**
  String get taskPriorityMedium;

  /// No description provided for @taskPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low priority'**
  String get taskPriorityLow;

  /// No description provided for @authTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authTitle;

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

  /// No description provided for @dashboardNoAccess.
  ///
  /// In en, this message translates to:
  /// **'Not available for your role'**
  String get dashboardNoAccess;

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

  /// No description provided for @customerEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get customerEmployees;

  /// No description provided for @customerIndustry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get customerIndustry;

  /// No description provided for @customerTerritory.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get customerTerritory;

  /// No description provided for @detailPipeline.
  ///
  /// In en, this message translates to:
  /// **'Pipeline'**
  String get detailPipeline;

  /// No description provided for @detailContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get detailContact;

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

  /// No description provided for @fieldJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job title'**
  String get fieldJobTitle;

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

  /// No description provided for @detailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This record no longer exists.'**
  String get detailNotFound;

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

  /// No description provided for @fieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get fieldQuantity;

  /// No description provided for @fieldProduced.
  ///
  /// In en, this message translates to:
  /// **'Produced'**
  String get fieldProduced;

  /// No description provided for @fieldPlannedEnd.
  ///
  /// In en, this message translates to:
  /// **'Planned finish'**
  String get fieldPlannedEnd;

  /// No description provided for @fieldItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get fieldItem;

  /// No description provided for @fieldDeal.
  ///
  /// In en, this message translates to:
  /// **'Deal'**
  String get fieldDeal;

  /// No description provided for @fieldWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get fieldWarehouse;

  /// No description provided for @fieldProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get fieldProgress;

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
