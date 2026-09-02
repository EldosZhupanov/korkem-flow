// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KORKEM Flow';

  @override
  String get filterNoResults => 'Nothing matches this filter.';

  @override
  String get actionClearHistory => 'Clear history';

  @override
  String get actionClearSearch => 'Clear search';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionClearFilter => 'Clear filter';

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionSelectAll => 'All';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get errorOffline => 'No connection to the server.';

  @override
  String get outboxQueued =>
      'No connection. The command is waiting to be sent.';

  @override
  String outboxPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commands waiting to send',
      one: '1 command waiting to send',
    );
    return '$_temp0';
  }

  @override
  String get outboxRetry => 'Send now';

  @override
  String outboxRejected(String reason) {
    return 'A queued command was refused: $reason';
  }

  @override
  String get errorNoAccess => 'You don\'t have access to this.';

  @override
  String get errorNotFound => 'Not found.';

  @override
  String get emptyTitle => 'Nothing here yet';

  @override
  String get emptyGeneric => 'New items will appear here as they are created.';

  @override
  String get searchHint => 'Search';

  @override
  String searchNoResults(String query) {
    return 'No matches for \"$query\"';
  }

  @override
  String semanticStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get navDeals => 'Deals';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navProfile => 'Profile';

  @override
  String get tasksOverdue => 'Overdue';

  @override
  String get tasksToday => 'Today';

  @override
  String get tasksUpcoming => 'Upcoming';

  @override
  String get tasksEmpty => 'No open tasks';

  @override
  String get tasksEmptyBody => 'Assigned work will appear here.';

  @override
  String get taskComplete => 'Complete';

  @override
  String get taskCompleted => 'Task completed';

  @override
  String taskCompleteFailed(String reason) {
    return 'Couldn\'t complete the task. $reason';
  }

  @override
  String get actionUndo => 'Undo';

  @override
  String get taskProduction => 'Production';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileVersion => 'Version';

  @override
  String get themeSystem => 'System';

  @override
  String get languageSystem => 'Device language';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get profileServer => 'Server';

  @override
  String get taskPriorityHigh => 'High priority';

  @override
  String get authSubtitle => 'Connect to your KORKEM workspace';

  @override
  String get authServer => 'Server address';

  @override
  String get authServerHint => 'korkem.example.kz';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignOutConfirm => 'Sign out of this device?';

  @override
  String get authSignOutBody =>
      'You will need the server address and your password to sign back in.';

  @override
  String get authFieldRequired => 'Required';

  @override
  String get authInvalidServer => 'That is not a valid address.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSignedInAs => 'Signed in as';

  @override
  String get settingsConnection => 'Connection';

  @override
  String get navDashboard => 'Home';

  @override
  String get dashboardGreeting => 'Today';

  @override
  String get dashboardMyWork => 'My work';

  @override
  String dashboardWorkload(int overdue, int total) {
    return '$overdue of $total are overdue';
  }

  @override
  String get dashboardAttention => 'Needs attention';

  @override
  String get dashboardAllClear => 'Nothing needs you right now';

  @override
  String get dashboardAllClearBody =>
      'Overdue work and decisions waiting on you appear here.';

  @override
  String get metricOpenDeals => 'Open deals';

  @override
  String get metricOpenLeads => 'Leads';

  @override
  String get metricMyOpenTasks => 'My tasks';

  @override
  String get metricOverdueTasks => 'Overdue';

  @override
  String get metricPendingActions => 'Awaiting approval';

  @override
  String get metricWorkOrders => 'In production';

  @override
  String get attentionPendingAction => 'Decision required';

  @override
  String get attentionOverdueTask => 'Overdue task';

  @override
  String get navSales => 'Sales';

  @override
  String get navLeads => 'Leads';

  @override
  String get navCustomers => 'Customers';

  @override
  String get dealsEmptyAssigned => 'Nothing assigned to you yet';

  @override
  String get dealsEmptyAssignedBody =>
      'You only see deals you own or are assigned to. Ask a manager to assign you one.';

  @override
  String get leadsEmpty => 'No leads';

  @override
  String get leadsEmptyBody => 'New enquiries appear here as they arrive.';

  @override
  String get leadConverted => 'Converted';

  @override
  String get customersEmpty => 'No customers';

  @override
  String get customersEmptyBody =>
      'Organizations appear here once a deal is created for them.';

  @override
  String get detailPipeline => 'Pipeline';

  @override
  String get detailCommercial => 'Commercial';

  @override
  String get detailOwnership => 'Ownership';

  @override
  String get detailCompany => 'Company';

  @override
  String get fieldStage => 'Stage';

  @override
  String get fieldValue => 'Value';

  @override
  String get fieldProbability => 'Probability';

  @override
  String get fieldExpectedClose => 'Expected close';

  @override
  String get fieldNextStep => 'Next step';

  @override
  String get fieldOwner => 'Owner';

  @override
  String get fieldSource => 'Source';

  @override
  String get fieldTerritory => 'Territory';

  @override
  String get fieldIndustry => 'Industry';

  @override
  String get fieldWebsite => 'Website';

  @override
  String get fieldEmployees => 'Employees';

  @override
  String get fieldRevenue => 'Annual revenue';

  @override
  String get fieldOriginLead => 'Converted from lead';

  @override
  String get fieldUpdated => 'Updated';

  @override
  String get actionCall => 'Call';

  @override
  String get actionEmail => 'Email';

  @override
  String get actionWhatsApp => 'WhatsApp';

  @override
  String get navApprovals => 'Approvals';

  @override
  String get navProduction => 'Production';

  @override
  String get approvalsEmpty => 'Nothing awaiting you';

  @override
  String get approvalsEmptyBody =>
      'Decisions an agent is waiting on will appear here.';

  @override
  String get approvalApprove => 'Approve';

  @override
  String get approvalReject => 'Reject';

  @override
  String get approvalApproved => 'Approved';

  @override
  String get approvalRejected => 'Rejected';

  @override
  String get approvalExpires => 'Expires';

  @override
  String get approvalExpired => 'Expired';

  @override
  String get productionEmpty => 'No work orders';

  @override
  String get productionEmptyBody =>
      'Orders appear here once a deal moves into production.';

  @override
  String get paPending => 'Pending';

  @override
  String get paApproved => 'Approved';

  @override
  String get paRejected => 'Rejected';

  @override
  String get paExpired => 'Expired';

  @override
  String get woDraft => 'Draft';

  @override
  String get woSubmitted => 'Submitted';

  @override
  String get woNotStarted => 'Not started';

  @override
  String get woInProcess => 'In process';

  @override
  String get woStockReserved => 'Stock reserved';

  @override
  String get woStockPartial => 'Stock partly reserved';

  @override
  String get woCompleted => 'Completed';

  @override
  String get woStopped => 'Stopped';

  @override
  String get woClosed => 'Closed';

  @override
  String get woCancelled => 'Cancelled';

  @override
  String get navQuotes => 'Quotes';

  @override
  String get navWarehouse => 'Warehouse';

  @override
  String get navOperations => 'Operations';

  @override
  String get quotesEmpty => 'No quotes';

  @override
  String get quotesEmptyBody =>
      'Quotes appear here once one is raised for a deal.';

  @override
  String get warehouseEmpty => 'No items';

  @override
  String get warehouseEmptyBody => 'Stock items appear here.';

  @override
  String get fieldValidTill => 'Valid till';

  @override
  String get fieldReserved => 'Reserved';

  @override
  String get warehouseNoStock => 'Not stocked anywhere';

  @override
  String get quoteExpiredSoon => 'Expires soon';

  @override
  String get qDraft => 'Draft';

  @override
  String get qOpen => 'Open';

  @override
  String get qReplied => 'Replied';

  @override
  String get qPartiallyOrdered => 'Partly ordered';

  @override
  String get qOrdered => 'Ordered';

  @override
  String get qLost => 'Lost';

  @override
  String get qCancelled => 'Cancelled';

  @override
  String get qExpired => 'Expired';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get notificationsEmpty => 'Nothing has been sent yet.';

  @override
  String get notificationsEmptyBody =>
      'Assignments, mentions and alerts appear here.';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get navAssistant => 'Assistant';

  @override
  String get navMenu => 'Menu';

  @override
  String get chatNew => 'New chat';

  @override
  String get chatRecent => 'Recent';

  @override
  String get chatGreeting => 'How can I help?';

  @override
  String get chatPlaceholder => 'Ask KORKEM anything…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatDictate => 'Dictate';

  @override
  String get chatDictateStop => 'Stop dictating';

  @override
  String get chatLocalMode => 'Local mode · KORKEM data';

  @override
  String get chatThinking => 'Thinking';

  @override
  String get chatEmptyThreads => 'No conversations yet';

  @override
  String get chatOpen => 'Open';

  @override
  String get chatNotConnected =>
      'I\'m not connected to a language model yet, so I can\'t answer that. I can show you data from KORKEM:';

  @override
  String get chatSuggestDeals => 'Show my deals';

  @override
  String get chatSuggestAttention => 'What needs attention?';

  @override
  String get chatSuggestOverdue => 'What is overdue?';

  @override
  String get chatSuggestProduction => 'What\'s in production?';

  @override
  String get chatCardOpenDeals => 'Open deals';

  @override
  String get chatCardAttention => 'Needs attention';

  @override
  String get chatCardTasks => 'My tasks';

  @override
  String get chatCardProduction => 'In production';

  @override
  String get chatHistory => 'History';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatEarlier => 'Earlier';

  @override
  String get chatScrollToEnd => 'Jump to latest';

  @override
  String get chatWorkspace => 'AI Workspace';

  @override
  String get chatRename => 'Rename';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatDeleteTitle => 'Delete conversation?';

  @override
  String chatDeleteBody(String title) {
    return '“$title” will be removed from this device. This cannot be undone.';
  }

  @override
  String get chatRenameTitle => 'Conversation name';

  @override
  String get navClients => 'Clients';

  @override
  String get chatErrorNotConfigured =>
      'AI is not set up on the server yet. Ask your KORKEM administrator.';

  @override
  String get chatErrorOffline =>
      'Could not reach KORKEM. Check your connection.';

  @override
  String get chatErrorRefused => 'You do not have permission for that.';

  @override
  String get chatErrorUnknown => 'Could not answer just now. Try again.';

  @override
  String get chatWorking => 'Working…';

  @override
  String get chatToolDeals => 'Searching deals…';

  @override
  String get chatToolLeads => 'Searching leads…';

  @override
  String get chatToolCustomers => 'Searching customers…';

  @override
  String get chatToolTasks => 'Searching tasks…';

  @override
  String get chatToolProduction => 'Checking production…';

  @override
  String get chatToolOrders => 'Checking orders…';

  @override
  String get chatToolShortage => 'Working out the shortage…';

  @override
  String get chatToolStock => 'Checking stock…';

  @override
  String get chatToolProcurement => 'Preparing the purchase request…';

  @override
  String get chatToolProfile => 'Checking your profile…';

  @override
  String get chatErrorProviderUnavailable =>
      'The AI service is not responding. Try again shortly.';

  @override
  String get chatErrorRateLimited =>
      'The AI service is busy. Wait a moment and try again.';

  @override
  String get chatErrorToolError => 'Could not complete that action in KORKEM.';

  @override
  String get chatConfirmTitle => 'Confirm this action';

  @override
  String get chatConfirmBody =>
      'The assistant wants to make a change. Nothing has happened yet.';

  @override
  String get chatConfirmApprove => 'Approve';

  @override
  String get chatConfirmReject => 'Cancel';

  @override
  String get chatConfirmRejected => 'Cancelled. Nothing was changed.';

  @override
  String get chatFallbackBadge => 'Not AI — direct data';

  @override
  String get chatErrorTimedOut => 'The AI service took too long. Try again.';

  @override
  String get chatErrorModelNotFound =>
      'The selected AI model is unavailable. Choose another in AI Settings.';

  @override
  String get chatErrorContextTooLarge =>
      'This conversation is too long. Start a new chat.';

  @override
  String get aiSettingsTitle => 'AI providers';

  @override
  String get aiSettingsSubtitle => 'Choose which AI answers, and connect it.';

  @override
  String get aiSettingsDefault => 'Default';

  @override
  String get aiSettingsMakeDefault => 'Use by default';

  @override
  String get aiSettingsNotConfigured => 'Not set up';

  @override
  String get aiSettingsConnected => 'Connected';

  @override
  String get aiSettingsTestFailed => 'Connection failed';

  @override
  String get aiSettingsTest => 'Test connection';

  @override
  String get aiSettingsSave => 'Save';

  @override
  String get aiSettingsApiKey => 'API key';

  @override
  String get aiSettingsApiKeyStored =>
      'A key is stored. Leave blank to keep it.';

  @override
  String get aiSettingsModel => 'Model';

  @override
  String get aiSettingsBaseUrl => 'Base URL';

  @override
  String get aiSettingsKeyNeverLeaves =>
      'Keys are stored on the KORKEM server and never sent to this device.';

  @override
  String get aiSettingsCapabilities => 'Capabilities';

  @override
  String get aiSettingsLocalNoKey => 'Runs locally — no key needed.';

  @override
  String get channelsTitle => 'Chat channels';

  @override
  String get channelsSubtitle =>
      'Connect the Telegram and WhatsApp bots and say who is on the other end.';

  @override
  String get channelsSecretsNote =>
      'Tokens are stored on the KORKEM server and never sent to this device.';

  @override
  String get channelsStateNotConfigured => 'Not set up';

  @override
  String get channelsStateDisabled => 'Off';

  @override
  String get channelsStateReady => 'Ready';

  @override
  String get channelsTest => 'Test connection';

  @override
  String get channelsTestOk => 'Connected';

  @override
  String get channelsTestFailed => 'Connection failed';

  @override
  String get channelsEnabled => 'Enabled';

  @override
  String get channelsSave => 'Save';

  @override
  String get channelsStored => 'Stored. Leave blank to keep it.';

  @override
  String get channelsBotToken => 'Bot token';

  @override
  String get channelsWebhookSecret => 'Webhook secret';

  @override
  String get channelsAccessToken => 'Access token';

  @override
  String get channelsPhoneNumberId => 'Phone number ID';

  @override
  String get channelsVerifyToken => 'Verify token';

  @override
  String get channelsWebhookUrl => 'Webhook URL';

  @override
  String get channelsIdentities => 'Who writes in';

  @override
  String get channelsIdentityUnlinked => 'Not linked';

  @override
  String get channelsLink => 'Link';

  @override
  String get channelsUnlink => 'Unlink';

  @override
  String get channelsUser => 'KORKEM user';

  @override
  String get channelsIdentitiesEmpty => 'Nobody has written to the bots yet.';

  @override
  String get channelsStateConnected => 'Connected';

  @override
  String get channelsStateInvalid => 'Credentials rejected';

  @override
  String get channelsStateWebhookError => 'Webhook problem';

  @override
  String get channelsStateUnavailable => 'Provider unreachable';

  @override
  String get channelsConfigureWebhook => 'Configure webhook';

  @override
  String get channelsRemoveWebhook => 'Remove webhook';

  @override
  String get channelsWebhookManual =>
      'Paste this URL into the provider\'s dashboard.';

  @override
  String get channelsLastChecked => 'Last checked';

  @override
  String get channelsPending => 'Waiting at the provider';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'What the system told people, and what could not be delivered.';

  @override
  String get notificationsRetry => 'Retry';

  @override
  String get notificationsRetryAll => 'Retry all';

  @override
  String get notificationsCancel => 'Cancel';

  @override
  String get notificationsAttempts => 'Attempts';

  @override
  String get notificationsNextAttempt => 'Next attempt';

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get instructionsTitle => 'Work instructions';

  @override
  String get instructionsSubtitle => 'Who was asked, and what they answered.';

  @override
  String get instructionsEmpty => 'Nobody has been given work yet.';

  @override
  String get instructionsAnsweredIn => 'Answered in';

  @override
  String get channelsSendTest => 'Send test message';

  @override
  String get channelsDisconnect => 'Disconnect';

  @override
  String get channelsLastInbound => 'Last received';

  @override
  String get channelsLastOutbound => 'Last sent';

  @override
  String get channelsFailedDeliveries => 'Failed deliveries';

  @override
  String get channelsPendingRetries => 'Waiting to retry';

  @override
  String get channelsStateForbidden => 'Blocked by the provider';

  @override
  String get channelsStateRateLimited => 'Rate limited';

  @override
  String get ordersTitle => 'Sales Orders';

  @override
  String get ordersEmpty => 'No sales orders yet';

  @override
  String get ordersEmptyBody => 'New customer orders will appear here.';

  @override
  String get ordersActionStartProduction => 'Start production';

  @override
  String get ordersStartingProduction => 'Starting production...';

  @override
  String ordersStartSuccess(String id) {
    return 'Production started for $id';
  }

  @override
  String ordersTopUpSuccess(String id) {
    return 'Material transferred for $id';
  }

  @override
  String ordersAlreadyStarted(String id) {
    return 'Production for $id is already started';
  }

  @override
  String ordersNothingToStart(String id) {
    return 'Nothing to start for $id';
  }

  @override
  String get ordersBlockedTitle => 'Insufficient materials';

  @override
  String get ordersBlockedBody =>
      'Not enough materials in stock to start production:';

  @override
  String ordersBlockedSummary(String id) {
    return 'Cannot start $id: missing materials on the shelf';
  }

  @override
  String ordersDeliveredProgress(String percent) {
    return '$percent% delivered';
  }

  @override
  String ordersDeliveryDate(String date) {
    return 'Delivery: $date';
  }

  @override
  String ordersTransactionDate(String date) {
    return 'Date: $date';
  }

  @override
  String get soDraft => 'Draft';

  @override
  String get soToDeliverAndBill => 'To Deliver & Bill';

  @override
  String get soToBill => 'To Bill';

  @override
  String get soToDeliver => 'To Deliver';

  @override
  String get soCompleted => 'Completed';

  @override
  String get soCancelled => 'Cancelled';

  @override
  String get soClosed => 'Closed';

  @override
  String get soOnHold => 'On Hold';

  @override
  String get todayTitle => 'Today';

  @override
  String get todaySubtitle => 'Shop floor operational overview';

  @override
  String get todayActiveOrders => 'Active Orders';

  @override
  String todayLateOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overdue',
      one: '$count overdue',
    );
    return '$_temp0';
  }

  @override
  String get todayOrdersAllOnTrack => 'All on track';

  @override
  String get todayInProduction => 'In Production';

  @override
  String todayWorkOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '$count job',
    );
    return '$_temp0';
  }

  @override
  String get todayProductionAllOnTrack => 'No delays';

  @override
  String get todayApprovals => 'Pending Approvals';

  @override
  String todayApprovalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count decisions',
      one: '$count decision',
    );
    return '$_temp0';
  }

  @override
  String get todayApprovalsNone => 'All approved';

  @override
  String get todayStockDeficit => 'Stock Shortage';

  @override
  String todayDeficitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in deficit',
      one: '$count item in deficit',
    );
    return '$_temp0';
  }

  @override
  String get todayDeficitNone => 'No shortages';

  @override
  String get todayAttentionTitle => 'Needs Attention';

  @override
  String get todayAllClearTitle => 'All Clear';

  @override
  String get todayAllClearSubtitle =>
      'No critical delays or material shortages on the shop floor.';

  @override
  String get todayQuickNav => 'Quick Navigation';

  @override
  String get todayTileError => 'Failed to load';

  @override
  String get orderProductionSection => 'Production';

  @override
  String get orderNoProductionTitle => 'Production has not started';

  @override
  String get orderNoProductionBody =>
      'No jobs have been raised for this order. Start production once the order is confirmed.';

  @override
  String get workOrderLinkedSalesOrder => 'Linked Sales Order';

  @override
  String get workOrderNoLinkedSalesOrder => 'No linked sales order';

  @override
  String workOrderPlannedEnd(String date) {
    return 'Planned finish: $date';
  }

  @override
  String workOrderActualEnd(String date) {
    return 'Actual finish: $date';
  }

  @override
  String workOrderBomNo(String bom) {
    return 'BOM: $bom';
  }

  @override
  String workOrderWipWarehouse(String warehouse) {
    return 'WIP warehouse: $warehouse';
  }

  @override
  String workOrderFgWarehouse(String warehouse) {
    return 'Finished goods warehouse: $warehouse';
  }

  @override
  String workOrderProducedProgress(String produced, String qty) {
    return 'Produced: $produced of $qty';
  }

  @override
  String get workOrderOperationsSection => 'Operations';

  @override
  String get workOrderNoOperationsTitle => 'No operations';

  @override
  String get workOrderNoOperationsBody =>
      'This work order has no operations defined.';

  @override
  String workOrderOperationSequence(int sequence) {
    return 'Op #$sequence';
  }

  @override
  String workOrderOperationWorkstation(String workstation) {
    return 'Workstation: $workstation';
  }

  @override
  String workOrderOperationCompleted(String qty) {
    return 'Completed: $qty';
  }

  @override
  String workOrderOperationScrap(String qty) {
    return 'Scrap: $qty';
  }

  @override
  String workOrderOperationTime(int minutes) {
    return 'Planned: $minutes min';
  }

  @override
  String get opPending => 'Pending';

  @override
  String get opInProgress => 'In Progress';

  @override
  String get opCompleted => 'Completed';

  @override
  String get opClosed => 'Closed';

  @override
  String get opCancelled => 'Cancelled';

  @override
  String get stockBalancesSection => 'Warehouse Balances';

  @override
  String get stockSummarySection => 'Total Across Warehouses';

  @override
  String get stockActualQty => 'Actual Stock';

  @override
  String get stockReservedQty => 'Reserved';

  @override
  String get stockProjectedQty => 'Projected';

  @override
  String get stockDeficitAlert => 'Stock Deficit';

  @override
  String get stockNoBalancesTitle => 'Not stocked anywhere';

  @override
  String get stockNoBalancesBody =>
      'This item is not currently held in any company warehouse.';

  @override
  String get warehouseActionOpen => 'Open';

  @override
  String get outboxTitle => 'Command Queue';

  @override
  String get outboxEmptyTitle => 'All commands sent';

  @override
  String get outboxEmptyBody =>
      'There are no pending or refused commands. When offline, new actions will wait here.';

  @override
  String outboxPendingSection(int count) {
    return 'Waiting to send ($count)';
  }

  @override
  String outboxRejectedSection(int count) {
    return 'Refused ($count)';
  }

  @override
  String outboxRejectedPending(int count) {
    return 'Commands needing attention: $count';
  }

  @override
  String get outboxDismissRejected => 'Got it, remove';

  @override
  String get outboxDismissAll => 'Remove all';

  @override
  String outboxCommandStartProduction(String order) {
    return 'Start production for $order';
  }

  @override
  String outboxCommandCompleteOperation(String operation) {
    return 'Operation: $operation';
  }

  @override
  String outboxCommandReceiveReceipt(String order) {
    return 'Receive for $order';
  }

  @override
  String outboxCommandCreatePurchaseOrder(String request) {
    return 'Purchase order for $request';
  }

  @override
  String outboxCommandCreateDelivery(String order) {
    return 'Delivery for $order';
  }

  @override
  String outboxCommandGeneric(String path) {
    return 'Command: $path';
  }

  @override
  String outboxParamItem(String item) {
    return 'Item: $item';
  }

  @override
  String outboxParamSupplier(String supplier) {
    return 'Supplier: $supplier';
  }

  @override
  String outboxParamWorkOrder(String workOrder) {
    return 'Work order: $workOrder';
  }

  @override
  String outboxParamCompletedQty(String qty) {
    return 'Completed: $qty';
  }

  @override
  String outboxParamScrapQty(String qty) {
    return 'Scrap: $qty';
  }

  @override
  String get todayOutboxTitle => 'Not Sent';

  @override
  String get todayOutboxAllSent => 'All sent';

  @override
  String get orderDeliveriesSection => 'Deliveries';

  @override
  String get orderNoDeliveriesTitle => 'No shipments yet';

  @override
  String get orderNoDeliveriesBody =>
      'Deliveries will appear here when goods are shipped.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchPlaceholder => 'Order, customer, material...';

  @override
  String get searchEmptyPromptTitle => 'Search across everything';

  @override
  String get searchEmptyPromptBody =>
      'Enter an order number, customer name, work order, or item code.';

  @override
  String get searchNoResultsTitle => 'Nothing found';

  @override
  String searchNoResultsBody(String query) {
    return 'No results matching «$query».';
  }

  @override
  String searchSectionOrders(int count) {
    return 'Orders ($count)';
  }

  @override
  String searchSectionWorkOrders(int count) {
    return 'Work Orders ($count)';
  }

  @override
  String searchSectionStock(int count) {
    return 'Stock ($count)';
  }

  @override
  String searchSectionError(String section) {
    return 'Failed to load $section';
  }

  @override
  String get searchNavTooltip => 'Search';

  @override
  String get ordersSelectPromptTitle => 'Select an order';

  @override
  String get ordersSelectPromptBody =>
      'Select an order from the list on the left to view details and production.';

  @override
  String get productionSelectPromptTitle => 'Select a work order';

  @override
  String get productionSelectPromptBody =>
      'Select a work order from the list to view its details and operations.';

  @override
  String get warehouseSelectPromptTitle => 'Select an item';

  @override
  String get warehouseSelectPromptBody =>
      'Select an item from the list to view warehouse balances and details.';

  @override
  String get completeOperationAction => 'Complete';

  @override
  String get completeOperationTitle => 'Complete Operation';

  @override
  String get completeOperationQtyLabel => 'Completed quantity';

  @override
  String get completeOperationScrapQtyLabel => 'Scrap quantity';

  @override
  String completeOperationSuccess(String operation) {
    return 'Operation $operation completed';
  }

  @override
  String get completeOperationAlreadyComplete =>
      'Operation is already completed';

  @override
  String get completeOperationInvalidQty => 'Enter a valid non-negative number';

  @override
  String get completeOperationBlockedTitle => 'Cannot Complete Operation';

  @override
  String get ordersActionCreateDelivery => 'Create delivery';

  @override
  String orderDeliverySuccess(String note) {
    return 'Delivery note $note created';
  }

  @override
  String orderDeliveryAdjustedSuccess(String note) {
    return 'Partial delivery $note created for available stock';
  }

  @override
  String get orderAlreadyDelivered => 'Order is already delivered';

  @override
  String get orderNothingShippable => 'Nothing is in stock to deliver';

  @override
  String get orderDeliveryBlockedTitle => 'Cannot Create Delivery';

  @override
  String get warehouseActionReceive => 'Receive delivery';

  @override
  String get receiveDeliveryDialogTitle => 'Receive Delivery';

  @override
  String get receivePurchaseOrderFieldLabel => 'Purchase Order #';

  @override
  String get receivePurchaseOrderFieldHint => 'e.g. PUR-ORD-2026-00001';

  @override
  String receiveSuccess(String receipt) {
    return 'Purchase receipt $receipt booked';
  }

  @override
  String get receiveNothingOutstanding =>
      'All items on this purchase order are already received';

  @override
  String get receiveBlockedTitle => 'Cannot Receive Delivery';

  @override
  String get warehouseActionPurchaseOrder => 'Create purchase order';

  @override
  String get createPurchaseOrderDialogTitle => 'Create Purchase Order';

  @override
  String get materialRequestFieldLabel => 'Material Request #';

  @override
  String get materialRequestFieldHint => 'e.g. MAT-MR-2026-00001';

  @override
  String get supplierFieldLabel => 'Supplier (optional)';

  @override
  String purchaseOrderSuccess(String order) {
    return 'Purchase order $order created';
  }

  @override
  String get purchaseOrderBlockedTitle => 'Cannot Create Purchase Order';

  @override
  String get receiveNoOrdersTitle => 'No deliveries pending';

  @override
  String get receiveNoOrdersBody =>
      'All purchase orders have already been received or none are open.';

  @override
  String get orderableNoRequestsTitle => 'No material requests';

  @override
  String get orderableNoRequestsBody =>
      'All material purchase requests have already been ordered.';

  @override
  String materialRequestNeededDate(String date) {
    return 'Needed by: $date';
  }

  @override
  String purchaseOrderExpectedDate(String date) {
    return 'Expected: $date';
  }
}
