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
  String taskForeignAssigneeExplanation(String assignee) {
    return 'Assigned to $assignee. Can be completed by the assignee or shift supervisor';
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
  String get authRegister => 'Register';

  @override
  String get authNoAccount => 'Don\'t have an account? Register';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get authRegisterSubtitle =>
      'Create a workspace for your furniture business';

  @override
  String get authCompanyName => 'Company / workshop name';

  @override
  String get authCompanyNameHint => 'E.g. Astana Furniture, IP Marat';

  @override
  String get authOwnerName => 'Your name';

  @override
  String get authOwnerNameHint => 'First and last name';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters.';

  @override
  String get authCustomServer => 'Server settings';

  @override
  String get authHideServer => 'Hide server settings';

  @override
  String get claimTitle => 'First run';

  @override
  String get claimSubtitle => 'Create your company and owner account';

  @override
  String get claimCode => 'Launch code';

  @override
  String get claimCodeHint => '16 characters from node log';

  @override
  String get claimCodeHelper =>
      'The code is shown in the node terminal on first launch';

  @override
  String get claimCompany => 'Company name';

  @override
  String get claimOwnerName => 'Owner name';

  @override
  String get claimOwnerEmail => 'Owner email';

  @override
  String get claimOwnerPassword => 'Owner password';

  @override
  String get claimConfirmPassword => 'Confirm password';

  @override
  String get claimPasswordMismatch => 'Passwords do not match';

  @override
  String get claimLanguage => 'System language';

  @override
  String get claimSubmit => 'Create company';

  @override
  String get claimAlreadyClaimed =>
      'This node is already claimed. Ask the owner for an invitation';

  @override
  String get claimCodeRefused =>
      'Invalid code. It is shown in the node log at startup';

  @override
  String get claimNodeUnconfiguredBanner =>
      'This node is waiting for setup. Create a company to become the owner.';

  @override
  String get claimSetupCompanyAction => 'Set up company';

  @override
  String get claimLangRu => 'Russian';

  @override
  String get claimLangKk => 'Kazakh';

  @override
  String get claimLangEn => 'English';

  @override
  String get adminStatsTitle => 'Digital administrator';

  @override
  String get adminStatsSubtitle =>
      'Proof of value: results achieved without hiring an administrator';

  @override
  String get adminStatsPeriodWeek => 'Week';

  @override
  String get adminStatsPeriodMonth => 'Month';

  @override
  String get adminStatsPeriodQuarter => '3 months';

  @override
  String get adminStatsStaleHeroLabel => 'NEEDS ATTENTION: STALE';

  @override
  String adminStatsStaleHeroText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures have not been handed over for more than 24 hours',
      one: '1 capture has not been handed over for more than 24 hours',
    );
    return '$_temp0';
  }

  @override
  String get adminStatsZeroStaleHeroLabel => 'GREAT RESULT';

  @override
  String adminStatsZeroStaleHeroText(int days) {
    return 'Zero captures lost over $days days';
  }

  @override
  String get adminStatsZeroStaleHeroSub =>
      'All recorded captures were handed over on time or completed';

  @override
  String get adminStatsEmptyTitle => 'Nothing captured yet';

  @override
  String get adminStatsEmptyMessage =>
      'No customer requests recorded for the selected period. New messages from channels and messengers will appear here.';

  @override
  String get adminStatsCaught => 'Captured requests';

  @override
  String get adminStatsCaughtHelper => 'Total recorded by system';

  @override
  String get adminStatsHandedOver => 'Handed over to person';

  @override
  String get adminStatsHandedOverHelper => 'Tasks created for team';

  @override
  String get adminStatsConverted => 'Converted to orders';

  @override
  String get adminStatsConvertedHelper => 'Led to agreement and payment';

  @override
  String get adminStatsDismissed => 'Dismissed';

  @override
  String get adminStatsDismissedHelper => 'Spam or customer decline';

  @override
  String get adminStatsStaleMetric => 'Stale (no task)';

  @override
  String get adminStatsStaleMetricHelper => 'Unassigned for >24h';

  @override
  String get adminStatsSummaryTitle => 'Hiring decision summary';

  @override
  String adminStatsSummaryText(int caught, int converted, int stale) {
    return 'The system processed $caught requests. $converted became orders, $stale require attention.';
  }

  @override
  String get adminStatsRetry => 'Retry';

  @override
  String get teamTitle => 'Team';

  @override
  String get teamSubtitle => 'Company employees and their assigned positions';

  @override
  String get teamInviteButton => 'Invite employee';

  @override
  String get teamInviteTitle => 'Invite employee';

  @override
  String get teamInviteSubtitle => 'Select position and enter email for access';

  @override
  String get teamEmailLabel => 'Email address';

  @override
  String get teamEmailHint => 'worker@company.kz';

  @override
  String get teamEmailError => 'Enter a valid email address';

  @override
  String get teamFirstNameLabel => 'Employee name';

  @override
  String get teamFirstNameHint => 'Aidos';

  @override
  String get teamPositionLabel => 'Position';

  @override
  String get teamPositionManager => 'Manager';

  @override
  String get teamPositionManagerDesc => 'Sales department, customers, deals';

  @override
  String get teamPositionWarehouse => 'Warehouse keeper';

  @override
  String get teamPositionWarehouseDesc => 'Warehouse, inventory, receiving';

  @override
  String get teamPositionAccountant => 'Accountant';

  @override
  String get teamPositionAccountantDesc =>
      'Invoices, payments, financial reports';

  @override
  String get teamPositionShopFloor => 'Shop floor worker';

  @override
  String get teamPositionShopFloorDesc =>
      'Machines, work instructions, progress reporting';

  @override
  String get teamPositionMeasurer => 'Surveyor';

  @override
  String get teamPositionMeasurerDesc =>
      'Visits the client, takes measurements and photos';

  @override
  String get teamPositionDesigner => 'Design engineer';

  @override
  String get teamPositionDesignerDesc =>
      'Drawings, specifications, BAZIS imports';

  @override
  String get teamPositionShopManager => 'Shop manager';

  @override
  String get teamPositionShopManagerDesc =>
      'Assigns work and watches the deadlines';

  @override
  String get teamPositionCutter => 'Panel saw operator';

  @override
  String get teamPositionCutterDesc => 'Cuts board material';

  @override
  String get teamPositionEdgeBanding => 'Edge bander';

  @override
  String get teamPositionEdgeBandingDesc => 'Edge banding machine';

  @override
  String get teamPositionCnc => 'CNC operator';

  @override
  String get teamPositionCncDesc => 'Drilling and routing';

  @override
  String get teamPositionPainter => 'Finisher';

  @override
  String get teamPositionPainterDesc => 'Painting and coating';

  @override
  String get teamPositionAssembler => 'Assembler';

  @override
  String get teamPositionAssemblerDesc => 'Assembly and packing';

  @override
  String get teamPositionInstaller => 'Installer';

  @override
  String get teamPositionInstallerDesc =>
      'Delivery and installation at the client';

  @override
  String get teamPositionOwner => 'Owner';

  @override
  String get teamPositionOwnerDesc =>
      'Full company management and administration';

  @override
  String get teamEmptyTitle => 'You are alone for now';

  @override
  String get teamEmptyMessage =>
      'Invite shop floor, warehouse, or sales team members to assign tasks and manage production.';

  @override
  String get teamInviteSuccess => 'Invitation sent';

  @override
  String get teamInviteSuccessTitle => 'Employee invited';

  @override
  String teamInviteSuccessDetail(String name, String position) {
    return 'Employee $name added with position \'$position\'';
  }

  @override
  String get teamNextStepTitle => 'Next step';

  @override
  String get teamPasswordNotSet => 'Password not set';

  @override
  String get teamPositionsLoading => 'Loading positions...';

  @override
  String get teamPositionsLoadError => 'Could not load positions list';

  @override
  String get teamForbiddenTitle => 'Owner only';

  @override
  String get teamForbiddenMessage =>
      'Only the company owner can invite new employees and assign positions.';

  @override
  String get teamSendInvite => 'Send invitation';

  @override
  String get teamSectionMembers => 'Employees';

  @override
  String get teamChangePositionTitle => 'Change Position';

  @override
  String get teamChangePositionAction => 'Change Position';

  @override
  String get teamSavePosition => 'Save Position';

  @override
  String teamChangePositionSuccess(String name, String position) {
    return 'Position for $name updated to «$position»';
  }

  @override
  String get teamDeactivateAction => 'Revoke Access';

  @override
  String get teamDeactivateDialogTitle => 'Revoke Access?';

  @override
  String teamDeactivateConfirmMessage(String name) {
    return 'Revoke access for $name? The employee will lose system access and all open sessions will be closed.';
  }

  @override
  String get teamDeactivateConfirmButton => 'Revoke Access';

  @override
  String teamDeactivateSuccess(int count) {
    return 'Access revoked, sessions closed: $count';
  }

  @override
  String get teamReactivateAction => 'Restore Access';

  @override
  String get teamReactivateDialogTitle => 'Restore Access?';

  @override
  String teamReactivateConfirmMessage(String name) {
    return 'Restore access for $name?';
  }

  @override
  String get teamReactivateConfirmButton => 'Restore Access';

  @override
  String get teamReactivateSuccess => 'Access restored';

  @override
  String get teamStatusDisabled => 'Access Revoked';

  @override
  String get teamStatusActive => 'Active';

  @override
  String get teamSectionDisabled => 'Deactivated Employees';

  @override
  String get teamCannotModifySelf =>
      'You cannot change your own position or revoke your own access';

  @override
  String get settingsTeamTitle => 'Team and employees';

  @override
  String get settingsTeamSubtitle => 'Invite employees and assign positions';

  @override
  String get companyDetailsTitle => 'Company details';

  @override
  String get companyDetailsSubtitle => 'Address, BIN, and bank details';

  @override
  String get warehousesSettingsTitle => 'Warehouses';

  @override
  String get warehousesSettingsSubtitle =>
      'Storage locations and shipping warehouse';

  @override
  String get warehousesTitle => 'Warehouses';

  @override
  String get warehousesSubtitle =>
      'Storage locations and finished goods shipping warehouse';

  @override
  String get warehousesTipTitle => 'How to change warehouse name in documents';

  @override
  String get warehousesTipBody =>
      'ERPNext does not allow renaming warehouses directly. To have a clear name on waybills: create your warehouse with the desired name → set it as shipping default → disable the English Finished Goods.';

  @override
  String get warehousesSectionActive => 'Warehouses';

  @override
  String get warehousesSectionDisabled => 'Disabled Warehouses';

  @override
  String get warehousesShippingDefaultBadge => 'Shipping Default';

  @override
  String get warehousesStatusDisabled => 'Disabled';

  @override
  String warehousesPositionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item positions',
      one: '$count item position',
    );
    return '$_temp0';
  }

  @override
  String get warehousesActionSetShippingDefault => 'Set as shipping default';

  @override
  String get warehousesActionDisable => 'Disable warehouse';

  @override
  String get warehousesActionEnable => 'Enable warehouse';

  @override
  String get warehousesCreateButton => 'New warehouse';

  @override
  String get warehousesCreateDialogTitle => 'New warehouse';

  @override
  String get warehousesCreateDialogSubtitle =>
      'Second workshop, rented space, vehicle';

  @override
  String get warehousesNameLabel => 'Warehouse name';

  @override
  String get warehousesNameHint => 'e.g. Materials Warehouse';

  @override
  String get warehousesNameError => 'Enter warehouse name';

  @override
  String warehousesCreateSuccess(String name) {
    return 'Warehouse \'$name\' created';
  }

  @override
  String warehousesSetShippingDefaultSuccess(String name) {
    return 'Warehouse \'$name\' set as shipping default';
  }

  @override
  String get warehousesDisableDialogTitle => 'Disable warehouse?';

  @override
  String warehousesDisableDialogMessage(String name) {
    return 'Disable warehouse \'$name\'? It will no longer appear in new documents, stock history remains preserved.';
  }

  @override
  String warehousesDisableSuccess(String name) {
    return 'Warehouse \'$name\' disabled';
  }

  @override
  String get warehousesEnableDialogTitle => 'Enable warehouse?';

  @override
  String warehousesEnableDialogMessage(String name) {
    return 'Enable warehouse \'$name\'? It will become available again in stock documents.';
  }

  @override
  String warehousesEnableSuccess(String name) {
    return 'Warehouse \'$name\' enabled';
  }

  @override
  String get warehousesEmptyTitle => 'No warehouses found';

  @override
  String get warehousesEmptyMessage => 'Company warehouse list is empty.';

  @override
  String get bazisImportTitle => 'Bazis Specification';

  @override
  String get bazisImportSubtitle => 'Inspect CAD export and create product BOM';

  @override
  String get bazisPickFileAction => 'Select Bazis File';

  @override
  String get bazisChangeFileAction => 'Select another file';

  @override
  String get bazisPickFileHint =>
      'XML project export from Bazis-Mebelschik (.xml)';

  @override
  String bazisTotalsSummary(
    int products,
    int parts,
    int materials,
    int operations,
  ) {
    return 'Products: $products · Parts: $parts · Materials: $materials · Operations: $operations';
  }

  @override
  String get bazisCreateSpecificationAction => 'Create Specification';

  @override
  String get bazisCreatingSpecification => 'Creating specification…';

  @override
  String get bazisInspectingFile => 'Reading export…';

  @override
  String get bazisProductLabel => 'Product';

  @override
  String bazisArticleLabel(String article) {
    return 'Article: $article';
  }

  @override
  String bazisOrderLabel(String order) {
    return 'Order: $order';
  }

  @override
  String bazisPriceLabel(String price) {
    return 'Price: $price';
  }

  @override
  String bazisQtyLabel(String qty) {
    return '$qty pcs';
  }

  @override
  String bazisPartsTab(int count) {
    return 'Parts ($count)';
  }

  @override
  String bazisMaterialsTab(int count) {
    return 'Materials ($count)';
  }

  @override
  String bazisOperationsTab(int count) {
    return 'Operations ($count)';
  }

  @override
  String bazisPartBlockLabel(String block) {
    return 'Block: $block';
  }

  @override
  String bazisPartDimensions(String length, String width, String thickness) {
    return '$length × $width × $thickness mm';
  }

  @override
  String bazisPartEdges(String edges) {
    return 'Edge: $edges';
  }

  @override
  String bazisMaterialUnitQty(String qty, String unit) {
    return '$qty $unit';
  }

  @override
  String bazisOperationMinutes(String minutes) {
    return '$minutes min.';
  }

  @override
  String get bazisBomStatusCreated => 'Specification created';

  @override
  String get bazisBomStatusUpdated => 'Specification draft updated';

  @override
  String get bazisMaterialsWithoutQtyAlert =>
      'Materials without calculated quantity (omitted from BOM):';

  @override
  String get bazisOperationsAwaitingWorkstationAlert =>
      'Operations awaiting workstation assignment (added to catalog, not placed in routing):';

  @override
  String get bazisImportSuccessTitle => 'Specification prepared';

  @override
  String get bazisImportAnotherAction => 'Upload another export';

  @override
  String bazisBomDocLabel(String bom) {
    return 'BOM doc: $bom';
  }

  @override
  String bazisItemDocLabel(String item) {
    return 'Item: $item';
  }

  @override
  String get bazisEmptyParts => 'No parts in product';

  @override
  String get bazisEmptyMaterials => 'No materials in product';

  @override
  String get bazisEmptyOperations => 'No operations in product';

  @override
  String get integrationsTitle => 'Integrations';

  @override
  String get integrationsSubtitle => 'TrustMe and Kaspi Pay Keys';

  @override
  String get integrationsSecurityNote =>
      'These are your company keys. They are stored encrypted on your server and are never shared externally.';

  @override
  String get trustmeTitle => 'TrustMe';

  @override
  String get trustmeSubtitle => 'Digital contract signing';

  @override
  String get trustmeBinLabel => 'Organization BIN';

  @override
  String get trustmeBinHint => '12 digits';

  @override
  String get trustmeApiTokenLabel => 'API Token';

  @override
  String get trustmeApiTokenHint => 'Enter new token to change';

  @override
  String get trustmeWebhookSecretLabel => 'Webhook Secret';

  @override
  String get trustmeWebhookSecretHint => 'Enter new secret to change';

  @override
  String get kaspiTitle => 'Kaspi Pay';

  @override
  String get kaspiSubtitle => 'Payment acceptance and invoicing';

  @override
  String get kaspiMerchantIdLabel => 'Merchant / Point ID';

  @override
  String get kaspiMerchantIdHint => 'Identifier in Kaspi Pay';

  @override
  String get kaspiApiKeyLabel => 'API Key';

  @override
  String get kaspiApiKeyHint => 'Enter new key to change';

  @override
  String get kaspiWebhookSecretLabel => 'Webhook Secret';

  @override
  String get kaspiWebhookSecretHint => 'Enter new secret to change';

  @override
  String get integrationSecretConfigured => 'Configured';

  @override
  String get integrationSecretNotConfigured => 'Not configured';

  @override
  String get integrationClearSecretAction => 'Delete';

  @override
  String get integrationSaveAction => 'Save';

  @override
  String get integrationSavedSuccess => 'Settings saved';

  @override
  String get integrationClearDialogTitle => 'Delete key?';

  @override
  String integrationClearDialogMessage(String secretName, String providerName) {
    return 'Delete $secretName? $providerName integration will stop working until a new key is entered.';
  }

  @override
  String get integrationClearSuccess => 'Key deleted';

  @override
  String integrationLastStatusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String integrationLastErrorLabel(String error) {
    return 'Error: $error';
  }

  @override
  String integrationLastCheckedLabel(String date) {
    return 'Checked: $date';
  }

  @override
  String get integrationEnableToggle => 'Enable integration';

  @override
  String get companyDetailsDocNote =>
      'Details are used to generate contracts, invoices, and waybills.';

  @override
  String get companyDetailsSectionGeneral => 'General information';

  @override
  String get companyDetailsNameLabel => 'Company name';

  @override
  String get companyDetailsNameHint => 'Korkem Furniture LLC';

  @override
  String get companyDetailsBinLabel => 'BIN';

  @override
  String get companyDetailsBinHint => '12 digits';

  @override
  String get companyDetailsBinError => 'BIN must contain exactly 12 digits';

  @override
  String get companyDetailsSectionContacts => 'Contacts and address';

  @override
  String get companyDetailsCityLabel => 'City';

  @override
  String get companyDetailsCityHint => 'Almaty';

  @override
  String get companyDetailsAddressLabel => 'Legal address';

  @override
  String get companyDetailsAddressHint => '150 Abay ave., office 401';

  @override
  String get companyDetailsPhoneLabel => 'Phone';

  @override
  String get companyDetailsPhoneHint => '+7 777 123 45 67';

  @override
  String get companyDetailsEmailLabel => 'Email';

  @override
  String get companyDetailsEmailHint => 'info@korkem.kz';

  @override
  String get companyDetailsEmailError => 'Enter a valid email address';

  @override
  String get companyDetailsWebsiteLabel => 'Website';

  @override
  String get companyDetailsWebsiteHint => 'korkem.kz';

  @override
  String get companyDetailsReadOnlyNameNotice =>
      'Company name is set during creation and changed in company profile';

  @override
  String get companyDetailsSectionBank => 'Bank details';

  @override
  String get companyDetailsBankNameLabel => 'Bank name';

  @override
  String get companyDetailsBankNameHint => 'Kaspi Bank JSC';

  @override
  String get companyDetailsIbanLabel => 'Bank account (IBAN)';

  @override
  String get companyDetailsIbanHint => 'KZ...';

  @override
  String get companyDetailsIbanHelper =>
      'Format: KZ and 18 characters (e.g. KZ69...)';

  @override
  String get companyDetailsIbanError =>
      'Kazakhstan IBAN must start with KZ and contain 20 characters';

  @override
  String get companyDetailsBikLabel => 'Bank BIC';

  @override
  String get companyDetailsBikHint => 'CASPKZ2A';

  @override
  String get companyDetailsBikError => 'BIC must contain 8 to 11 characters';

  @override
  String get companyDetailsSaveButton => 'Save details';

  @override
  String get companyDetailsSaveSuccess => 'Company details saved successfully';

  @override
  String get companyDetailsLoadError => 'Failed to load company details';

  @override
  String get itemsTitle => 'Items and prices';

  @override
  String get itemsSubtitle => 'Product catalog, units of measure, and prices';

  @override
  String get itemsSearchHint => 'Search by name or code';

  @override
  String get itemsEmptyTitle => 'No items in catalog yet';

  @override
  String get itemsEmptyMessage => 'Add the first catalog item';

  @override
  String get itemsAddItem => 'Add item';

  @override
  String get itemsCreateTitle => 'New item';

  @override
  String get itemsNameLabel => 'Item name';

  @override
  String get itemsNameHint => 'Two-door wardrobe';

  @override
  String get itemsNameRequired => 'Enter item name';

  @override
  String get itemsCodeLabel => 'Item code (optional)';

  @override
  String get itemsCodeHint => 'CAB-01';

  @override
  String get itemsUnitLabel => 'Unit of measure';

  @override
  String get itemsUnitHint => 'Select unit';

  @override
  String get itemsUnitRequired => 'Unit of measure is required';

  @override
  String get itemsDescriptionLabel => 'Description';

  @override
  String get itemsDescriptionHint => 'Materials, hardware, notes';

  @override
  String get itemsPriceLabel => 'Sale price (optional)';

  @override
  String get itemsPriceHint => '0 ₸';

  @override
  String get itemsPriceOnRequest => 'Price on request';

  @override
  String get itemsPriceLabelShort => 'Price';

  @override
  String get itemsSetPriceTitle => 'Change price';

  @override
  String get itemsSetPriceAction => 'Set price';

  @override
  String get itemsPriceRequired => 'Enter price';

  @override
  String get itemsPriceInvalid => 'Invalid price amount';

  @override
  String get itemsPriceUpdated => 'Price updated';

  @override
  String get itemsCreateSuccess => 'Item added';

  @override
  String get itemsUnitsLoading => 'Loading units...';

  @override
  String get itemsUnitsLoadError => 'Could not load units of measure';

  @override
  String get itemsCatalogAction => 'Items catalog';

  @override
  String get navItems => 'Items';

  @override
  String get settingsEnquiryFlowTitle => 'Enquiry pipeline';

  @override
  String get settingsEnquiryFlowSubtitle =>
      'Pipeline from request to production order';

  @override
  String get enquiryFlowTitle => 'Enquiry pipeline';

  @override
  String get enquiryFlowSubtitle =>
      'Pipeline from customer request to production order';

  @override
  String get enquiryFlowStep1 => 'Enquiry';

  @override
  String get enquiryFlowStep2 => 'Measurement';

  @override
  String get enquiryFlowStep3 => 'Proposal';

  @override
  String get enquiryFlowStep4 => 'Order';

  @override
  String get enquiryFlowSelectCapture => 'Select a request to process';

  @override
  String get enquiryFlowSpokenText => 'Customer words';

  @override
  String get enquiryFlowCustomerName => 'Customer name';

  @override
  String get enquiryFlowAssignMeasurer => 'Assign measurer';

  @override
  String get enquiryFlowMeasureDate => 'Measurement date';

  @override
  String get enquiryFlowConvertAction => 'Create enquiry';

  @override
  String get enquiryFlowAmbiguousTitle => 'Multiple matching customers found';

  @override
  String get enquiryFlowAmbiguousSubtitle =>
      'Choose an existing customer or create a new one:';

  @override
  String get enquiryFlowCreateNewCustomer => 'Create as new customer';

  @override
  String get enquiryFlowDimensions => 'Dimensions';

  @override
  String get enquiryFlowDimensionsHint => '3200x600, h=2100, left corner';

  @override
  String get enquiryFlowNotes => 'Notes and materials';

  @override
  String get enquiryFlowNotesHint => 'MDF white gloss, Blum hardware';

  @override
  String get enquiryFlowAddress => 'Address';

  @override
  String get enquiryFlowAddressHint => 'Abay ave 45, apt 12';

  @override
  String get enquiryFlowCity => 'City';

  @override
  String get enquiryFlowCityHint => 'Almaty';

  @override
  String get enquiryFlowRecordMeasurementAction => 'Record measurement';

  @override
  String get enquiryFlowAttachPhotos => 'Photos and references';

  @override
  String get enquiryFlowTakePhoto => 'Take photo';

  @override
  String get enquiryFlowPickGallery => 'From gallery';

  @override
  String enquiryFlowPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos attached',
      one: '$count photo attached',
    );
    return '$_temp0';
  }

  @override
  String get enquiryFlowRemovePhoto => 'Remove photo';

  @override
  String get enquiryFlowPermissionDenied =>
      'Camera or gallery access was denied. Grant permission in device settings to attach measurement photos.';

  @override
  String get enquiryFlowItemCode => 'Item name';

  @override
  String get enquiryFlowItemCodeHint => 'Kitchen set';

  @override
  String get enquiryFlowItemDesc => 'Item description';

  @override
  String get enquiryFlowItemDescHint => 'MDF facades, stone countertop';

  @override
  String get enquiryFlowItemQty => 'Quantity';

  @override
  String get enquiryFlowItemRate => 'Unit price (₸)';

  @override
  String get enquiryFlowAddItem => '+ Add item';

  @override
  String get enquiryFlowValidDays => 'Validity period (days)';

  @override
  String get enquiryFlowDraftProposalAction => 'Draft proposal';

  @override
  String get enquiryFlowDeliveryDate => 'Delivery date';

  @override
  String get enquiryFlowDeliveryDateRequired =>
      'Specify delivery date to create order';

  @override
  String get enquiryFlowPickDeliveryDate => 'Select date';

  @override
  String get enquiryFlowAcceptOrderAction => 'Accept and create order';

  @override
  String get enquiryFlowOrderCompleted => 'Order sent to production';

  @override
  String get enquiryFlowViewOrder => 'View order';

  @override
  String get enquiryFlowEmptyCaptures => 'No requests available';

  @override
  String get enquiryFlowEmptyCapturesDesc =>
      'Create a new request by voice or text to process it through the pipeline.';

  @override
  String get orderDesignSection => 'Design & drawings';

  @override
  String get orderDesignStatusNotAssigned => 'Not assigned';

  @override
  String get orderDesignStatusAssigned => 'In progress';

  @override
  String get orderDesignStatusDelivered => 'Accepted';

  @override
  String get orderDesignStatusOverdue => 'Overdue';

  @override
  String get orderDesignNoTaskTitle => 'Design not assigned yet';

  @override
  String get orderDesignNoTaskBody =>
      'Drawings and specifications are required before production starts.';

  @override
  String get orderDesignAssignAction => 'Assign design';

  @override
  String get orderDesignDesignerLabel => 'Designer';

  @override
  String get orderDesignDueDateLabel => 'Drawing due date';

  @override
  String get orderDesignDueDateRequired => 'Specify drawing due date';

  @override
  String get orderDesignFilesHeader => 'Attached files';

  @override
  String get orderDesignNoFilesNotice =>
      'Drawing expected. Design cannot be accepted without an attached file.';

  @override
  String get orderDesignAttachFileAction => 'Attach drawing';

  @override
  String get orderDesignAttachDialogTitle => 'Attach drawing to order';

  @override
  String get orderDesignFileNameLabel => 'Drawing file name';

  @override
  String get orderDesignFileNameHint => 'drawing_kitchen.dxf';

  @override
  String get orderDesignAttachButton => 'Attach file';

  @override
  String get orderDesignDeliverAction => 'Accept design';

  @override
  String get orderDesignCompletedNotice => 'Design accepted, drawings verified';

  @override
  String get orderInstallationSection => 'Installation';

  @override
  String get orderInstallationStatusNotScheduled => 'Not scheduled';

  @override
  String get orderInstallationStatusScheduled => 'Scheduled';

  @override
  String get orderInstallationStatusCompleted => 'Completed';

  @override
  String get orderInstallationStatusOverdue => 'Overdue';

  @override
  String get orderInstallationNoDeliveryNotice =>
      'Shipment comes first, then installation. A crew arriving without furniture wastes a day, and the client loses trust.';

  @override
  String get orderInstallationReadyToSchedule =>
      'Furniture has been shipped. Schedule the installation crew arrival date.';

  @override
  String get orderInstallationScheduleAction => 'Schedule installation';

  @override
  String get orderInstallationInstallerLabel => 'Installer / Crew';

  @override
  String get orderInstallationDateLabel => 'Installation date';

  @override
  String get orderInstallationDateRequired => 'Specify installation date';

  @override
  String get orderInstallationCompleteAction => 'Installation completed';

  @override
  String get orderInstallationCompleteDialogTitle => 'Complete installation';

  @override
  String get orderInstallationNotesLabel => 'Crew notes';

  @override
  String get orderInstallationNotesHint =>
      'E.g. wall was uneven, installed with extension filler';

  @override
  String get orderInstallationCompletedNotice =>
      'Installation completed successfully';

  @override
  String get orderWarrantySection => 'Warranty';

  @override
  String get orderWarrantyNotStartedNotice =>
      'Warranty will start after shipment.';

  @override
  String orderWarrantyShippedOn(String date) {
    return 'Shipped on: $date';
  }

  @override
  String get orderWarrantyStatusActive => 'Active';

  @override
  String get orderWarrantyStatusExpired => 'Expired';

  @override
  String get orderWarrantyStatusNoWarranty => 'No warranty';

  @override
  String orderWarrantyUntil(String date) {
    return 'until $date';
  }

  @override
  String orderWarrantyPeriodDays(int days) {
    return '$days days';
  }

  @override
  String get orderWarrantyClaimAction => 'File warranty claim';

  @override
  String get orderWarrantyClaimDialogTitle => 'File warranty claim';

  @override
  String get orderWarrantyItemLabel => 'Item';

  @override
  String get orderWarrantyComplaintLabel => 'What happened';

  @override
  String get orderWarrantyComplaintHint =>
      'Describe the issue in detail: what broke, under what conditions';

  @override
  String get orderWarrantyComplaintRequired => 'Describe reason for the claim';

  @override
  String orderWarrantyClaimSuccessNotice(String claim) {
    return 'Claim $claim registered successfully';
  }

  @override
  String get orderInvoicingSection => 'Invoice';

  @override
  String get orderInvoicingStatusNotDrafted => 'Not issued';

  @override
  String get orderInvoicingStatusDrafted => 'Issued';

  @override
  String get orderInvoicingStatusPaid => 'Paid';

  @override
  String get orderInvoicingOrderNotSubmittedNotice =>
      'The order is not yet submitted. An invoice for a draft is an invoice for something not yet agreed upon.';

  @override
  String get orderInvoicingNoDeliveryNotice =>
      'Nothing has been shipped for this order yet. An invoice for undelivered furniture causes conflict with the client.';

  @override
  String get orderInvoicingCreateAction => 'Issue invoice';

  @override
  String get orderInvoicingNumberLabel => 'Invoice number';

  @override
  String get orderInvoicingTotalLabel => 'Invoice total';

  @override
  String orderInvoicingSuccessNotice(String invoice) {
    return 'Invoice $invoice created successfully';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSignedInAs => 'Signed in as';

  @override
  String get settingsConnection => 'Connection';

  @override
  String get settingsLookAndLanguage => 'Look and language';

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
  String get approvalRejectDialogTitle => 'Reject Action';

  @override
  String get approvalRejectReasonHint => 'Reason (optional)';

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
  String get chatDictateUnavailable =>
      'Dictation is unavailable. Allow microphone access in your phone settings, or type instead.';

  @override
  String get chatLocalMode => 'Local mode · KORKEM data';

  @override
  String get chatThinking => 'Thinking';

  @override
  String get chatEmptyThreads => 'No conversations yet';

  @override
  String get chatEmptyThreadsBody =>
      'Your conversations with the assistant will appear here.';

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
  String get chatHistoryEmpty => 'No conversations yet.';

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
  String get chatExternalMessageDefault => 'Customer message';

  @override
  String get chatExternalDataNotice =>
      'Someone else’s text — the assistant does not act on it';

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
  String get todayUnassignedCapturesTitle => 'Unassigned captures';

  @override
  String get todayUnassignedCapturesEmpty =>
      'Nothing lost: all captures have been assigned';

  @override
  String get todayOverdueTasksTitle => 'Overdue tasks';

  @override
  String get todayOverdueTasksEmpty =>
      'All on schedule: no overdue measurements, designs, or installations';

  @override
  String get todayOrdersWithoutDesignTitle => 'Orders without design';

  @override
  String get todayOrdersWithoutDesignEmpty =>
      'Design is assigned for all orders';

  @override
  String get todayDeliveredNotInvoicedTitle => 'Shipped without invoice';

  @override
  String get todayDeliveredNotInvoicedEmpty => 'All shipments are billed';

  @override
  String get todayAllClearHeadline => 'Everything is under control';

  @override
  String get todayAllClearDescription =>
      'All requests are assigned, nothing is overdue, designs are in progress, and all deliveries have invoices.';

  @override
  String todayOverdueWasDue(String date) {
    return 'Was due: $date';
  }

  @override
  String todayDeliveryDue(String date) {
    return 'Due delivery: $date';
  }

  @override
  String todayBilledProgress(String delivered, String billed) {
    return 'Shipped $delivered%, billed $billed%';
  }

  @override
  String todayHeaderDate(String date) {
    return 'Today, $date';
  }

  @override
  String get todayImportantOverdue => 'Overdue';

  @override
  String get todayImportantDueToday => 'Due today';

  @override
  String get todayImportantDueThisWeek => 'Due this week';

  @override
  String get todayImportantUnpaid => 'Unpaid';

  @override
  String get todayImportantMaterialDeficit => 'Material shortage';

  @override
  String get todayImportantInstallationToday => 'Installation today';

  @override
  String get todayImportantRequiresDecision => 'Requires decision';

  @override
  String todayOrdersCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'orders',
      one: 'order',
    );
    return '$_temp0';
  }

  @override
  String todayPositionsCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return '$_temp0';
  }

  @override
  String todayApprovalsCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'approvals',
      one: 'approval',
    );
    return '$_temp0';
  }

  @override
  String get todayEmptyStateTitle => 'Everything is under control';

  @override
  String get todayEmptyStateDescription =>
      'No overdue orders, material shortages, or actions requiring decisions for today.';

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

  @override
  String get workstationsTitle => 'Workstations';

  @override
  String get workstationsSubtitle => 'Operation queue by workstation';

  @override
  String get workstationsEmptyTitle => 'No active jobs';

  @override
  String get workstationsEmptyBody =>
      'All workstations are idle, no unfinished operations.';

  @override
  String get stationQueueEmptyTitle => 'All done at this workstation';

  @override
  String get stationQueueEmptyBody =>
      'No pending operations waiting at this station.';

  @override
  String workstationWaitingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count operations',
      one: '$count operation',
    );
    return '$_temp0';
  }

  @override
  String workstationDueOn(String date) {
    return 'Due: $date';
  }

  @override
  String workstationItemLabel(String item) {
    return 'Product: $item';
  }

  @override
  String workstationQtyLabel(String qty) {
    return 'Quantity: $qty';
  }

  @override
  String workstationDuration(String minutes) {
    return '$minutes min';
  }

  @override
  String updateAvailable(String version) {
    return 'Update $version is available';
  }

  @override
  String get updateInstall => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update Now';

  @override
  String get updateDialogTitle => 'KORKEM Flow Update';

  @override
  String updateBuildLabel(String version, int build) {
    return 'Version $version (build $build)';
  }

  @override
  String get updateNotesTitle => 'What\'s New:';

  @override
  String get updateDownloading => 'Downloading update...';

  @override
  String get updateCheckButton => 'Check for updates';

  @override
  String get updateUpToDate => 'Latest version is installed';

  @override
  String get updateOpenBrowser => 'Open in browser';

  @override
  String get updateInstallSystemPrompt =>
      'The system installer will open after the download completes.';

  @override
  String get aiCascadeTitle => 'Order of asking';

  @override
  String get aiCascadeSubtitle =>
      'Top down: when one runs out of quota, the next one answers.';

  @override
  String get aiCascadeFree => 'free';

  @override
  String get memoryTitle => 'What KORKEM Knows';

  @override
  String get memorySubtitle => 'Company knowledge and your work habits';

  @override
  String get memorySectionCompany => 'About company';

  @override
  String get memorySectionUser => 'About me';

  @override
  String get memoryEmptyTitle => 'KORKEM hasn\'t remembered anything yet';

  @override
  String get memoryEmptyBody =>
      'Knowledge about the workshop, business rules, and your preferences will appear here as the assistant learns.';

  @override
  String get memoryEmptyCompany => 'No company facts yet';

  @override
  String get memoryEmptyUser => 'No facts about you yet';

  @override
  String get memoryStatusConfirmed => 'Confirmed';

  @override
  String get memoryStatusUnconfirmed => 'System inferred';

  @override
  String get memoryActionView => 'View';

  @override
  String get memoryActionEdit => 'Edit';

  @override
  String get memoryActionDelete => 'Delete';

  @override
  String get memoryActionConfirm => 'Confirm';

  @override
  String get memoryActionSave => 'Save';

  @override
  String get memoryEditDialogTitle => 'Edit Fact';

  @override
  String get memoryEditHint => 'Fact text';

  @override
  String get memoryDeleteConfirmTitle => 'Delete fact?';

  @override
  String get memoryDeleteConfirmBody =>
      'Memory is easy to delete and cannot be restored. KORKEM will stop using this fact in conversations.';

  @override
  String get memoryFactUpdated => 'Fact updated';

  @override
  String get memoryFactConfirmed => 'Fact confirmed';

  @override
  String get memoryFactDeleted => 'Fact deleted';

  @override
  String memorySourcePrefix(String source) {
    return 'Source: $source';
  }

  @override
  String get promptBreakdownTitle => 'Last prompt breakdown';

  @override
  String promptBreakdownTokens(String count) {
    return '$count tokens';
  }

  @override
  String get promptBreakdownHeaviest => 'heaviest';

  @override
  String get promptBreakdownEmpty => 'No prompts yet';

  @override
  String get promptBreakdownEmptyBody =>
      'Token usage breakdown will appear here after the first assistant request.';

  @override
  String get tokenCategoryInstruction => 'System instruction';

  @override
  String get tokenCategoryTools => 'Tool schemas';

  @override
  String get tokenCategoryCompanyMemory => 'Company memory';

  @override
  String get tokenCategoryUserMemory => 'User memory';

  @override
  String get tokenCategoryConversation => 'Conversation';

  @override
  String get tokenCategoryOrderData => 'Order data';

  @override
  String get tokenCategoryOther => 'Other';

  @override
  String get aiWeeklySummaryTitle => 'Weekly summary';

  @override
  String get aiWeeklyTurns => 'Total turns';

  @override
  String get aiWeeklyPrimaryModel => 'Primary model';

  @override
  String get aiWeeklyReserve => 'KORKEM reserve';

  @override
  String get aiWeeklyAvgDuration => 'Average duration';

  @override
  String aiWeeklySeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get assistantCheckTitle => 'Assistant Quality Check';

  @override
  String get assistantCheckRunButton => 'Run';

  @override
  String get assistantCheckRunning => 'Running check...';

  @override
  String get assistantCheckNotRunTitle => 'Check has not been run';

  @override
  String get assistantCheckNotRunDescription =>
      'Run the check to verify the assistant performs correctly on typical workshop scenarios.';

  @override
  String assistantCheckPassedSummary(int passed, int total) {
    return 'Passed $passed of $total';
  }

  @override
  String assistantCheckLastRun(String time) {
    return 'last run $time';
  }

  @override
  String assistantCheckDurationSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get assistantCheckTakingLonger =>
      'The check is taking longer than usual. Please check back in a minute.';

  @override
  String get eventsTitle => 'Noticed by KORKEM';

  @override
  String get eventsAllClearTitle => 'Everything is under control';

  @override
  String get eventsAllClearDescription =>
      'Factory is running on schedule, no urgent events.';

  @override
  String get eventsSeverityHigh => 'Urgent';

  @override
  String get eventsSeverityMedium => 'Attention';

  @override
  String get eventsSeverityLow => 'Info';

  @override
  String get eventsActionDismiss => 'Dismiss';

  @override
  String get eventsLoadFailed => 'Could not load events';

  @override
  String get eventsDismissSuccess => 'Event dismissed';

  @override
  String get materialsTitle => 'Materials';

  @override
  String get materialsSubtitle => 'Board and edge catalogue';

  @override
  String get navMaterials => 'Materials';

  @override
  String get materialKindBoard => 'Board';

  @override
  String get materialKindEdge => 'Edge';

  @override
  String get materialsFilterAll => 'All';

  @override
  String get materialsFilterBoards => 'Boards';

  @override
  String get materialsFilterEdges => 'Edges';

  @override
  String materialsThicknessLabel(String thickness) {
    return '$thickness mm';
  }

  @override
  String materialsFormatDimensions(int width, int height) {
    return '$width×$height mm';
  }

  @override
  String get materialsColorWhite => 'White';

  @override
  String get materialsColorWood => 'Wood';

  @override
  String get materialsColorGrey => 'Grey';

  @override
  String get materialsColorBlack => 'Black';

  @override
  String get materialsFilterThickness16 => '16 mm';

  @override
  String get materialsFilterThickness18 => '18 mm';

  @override
  String get materialsSearchHint => 'Search by decor code, name, manufacturer';

  @override
  String get materialsEmptyTitle => 'Catalogue is empty';

  @override
  String get materialsEmptyMessage =>
      'Catalogue items will appear here once synchronized.';

  @override
  String get materialsEmptyFilteredTitle => 'No materials found';

  @override
  String get materialsEmptyFilteredMessage =>
      'Try adjusting your search terms or clearing active filters.';

  @override
  String get materialsFilterTitle => 'Filters';

  @override
  String get materialsFilterThickness => 'Thickness';

  @override
  String get materialsFilterColorFamily => 'Color family';

  @override
  String get materialsFilterKind => 'Type';

  @override
  String get materialsActive => 'Active';

  @override
  String get materialsInactive => 'Inactive';

  @override
  String materialsFitsThickness(String thickness) {
    return 'fits $thickness mm';
  }

  @override
  String materialsEdgeWidth(String width) {
    return 'width $width mm';
  }

  @override
  String get hardwareTitle => 'Hardware';

  @override
  String get hardwareSubtitle => 'Hinges, runners and fittings';

  @override
  String get navHardware => 'Hardware';

  @override
  String get hardwareTypeAll => 'All types';

  @override
  String get hardwareTypeHinge => 'Hinges';

  @override
  String get hardwareTypeRunner => 'Runners';

  @override
  String get hardwareTypeHandle => 'Handles';

  @override
  String get hardwareTypeLeg => 'Legs';

  @override
  String get hardwareTypeShelfSupport => 'Shelf supports';

  @override
  String get hardwareKindHinge => 'Hinge';

  @override
  String get hardwareKindRunner => 'Runner';

  @override
  String get hardwareKindHandle => 'Handle';

  @override
  String get hardwareKindLeg => 'Leg';

  @override
  String get hardwareKindShelfSupport => 'Shelf support';

  @override
  String get hardwareOverlayAll => 'Any overlay';

  @override
  String get hardwareOverlayFull => 'Full overlay';

  @override
  String get hardwareOverlayHalf => 'Half overlay';

  @override
  String get hardwareOverlayInset => 'Inset';

  @override
  String get hardwareOverlayFullExplanation =>
      'Door fully overlaps the cabinet edge';

  @override
  String get hardwareOverlayHalfExplanation =>
      'Two doors share one cabinet edge';

  @override
  String get hardwareOverlayInsetExplanation =>
      'Door sits flush inside the cabinet';

  @override
  String get hardwareMountingAustrian => 'Austrian (45 mm)';

  @override
  String get hardwareMountingItalian => 'Italian (48 mm)';

  @override
  String get hardwareMountingGerman => 'German (52 mm)';

  @override
  String get hardwareMountingMini => 'Mini (38 mm)';

  @override
  String hardwareOpeningAngle(String angle) {
    return '$angle°';
  }

  @override
  String hardwareCupSpec(String diameter, String depth) {
    return 'Cup Ø$diameter×$depth mm';
  }

  @override
  String hardwareCupDiameter(String diameter) {
    return 'Ø$diameter mm';
  }

  @override
  String hardwareLength(String length) {
    return '$length mm';
  }

  @override
  String hardwareLoad(String load) {
    return 'up to $load kg';
  }

  @override
  String hardwareHoleSpacing(String spacing) {
    return 'Hole spacing $spacing mm';
  }

  @override
  String get hardwareSoftClose => 'Soft-close';

  @override
  String get hardwareNoSoftClose => 'No soft-close';

  @override
  String get hardwareSearchHint => 'Search by model, brand, name';

  @override
  String get hardwareEmptyTitle => 'Hardware catalogue is empty';

  @override
  String get hardwareEmptyMessage =>
      'Hardware items will appear here once synchronized.';

  @override
  String get hardwareEmptyFilteredTitle => 'No hardware found';

  @override
  String get hardwareEmptyFilteredMessage =>
      'Try adjusting the hardware type, overlay, or clearing active filters.';

  @override
  String get priceVisibilityTitle => 'Prices for the shop floor';

  @override
  String get priceVisibilitySubtitle =>
      'Let production, warehouse and drivers see client prices and order totals';

  @override
  String get priceVisibilitySaveFailed => 'Could not save. Try again.';

  @override
  String get defectPhotoAdd => 'Defect photo (optional)';

  @override
  String get defectPhotoChosen => 'Photo attached';

  @override
  String get defectPhotoRemove => 'Remove';

  @override
  String get defectPhotoNotSent =>
      'The stage is recorded, but the defect photo was not sent.';

  @override
  String get defectPhotoCameraFailed => 'Could not open the camera.';

  @override
  String get facadePricesTitle => 'Facade prices';

  @override
  String get facadePricesSubtitle => 'Price per m² by milling and finish';

  @override
  String get facadePricesAddMilling => 'Add milling';

  @override
  String get facadePricesMilling => 'Milling';

  @override
  String get facadePricesFinish => 'Finish';

  @override
  String get facadePricesPricePerM2 => 'Price per m²';

  @override
  String get facadePricesSold => 'Sold';

  @override
  String get facadePricesNotSold => 'Not sold';

  @override
  String get facadePricesSaved => 'Price saved';

  @override
  String get facadePricesSave => 'Save';

  @override
  String get facadeQuoteTitle => 'Facade order calculation';

  @override
  String get facadeQuoteAddLine => 'Add facade';

  @override
  String get facadeQuoteDemolition => 'Demolition';

  @override
  String get facadeQuotePrepaymentManual => 'Prepayment (if different)';

  @override
  String facadeQuotePrepaymentDefault(String percent) {
    return 'By default $percent% of the total';
  }

  @override
  String get facadeQuoteCalculate => 'Calculate';

  @override
  String get facadeQuoteNumberRequired => 'Enter a number';

  @override
  String facadeQuoteLine(int number) {
    return 'Facade $number';
  }

  @override
  String get facadeQuoteRemoveLine => 'Remove';

  @override
  String get facadeQuoteWidth => 'Width, mm';

  @override
  String get facadeQuoteHeight => 'Height, mm';

  @override
  String get facadeQuoteQty => 'Pcs';

  @override
  String get facadeQuoteDoubleSided => 'Double-sided';

  @override
  String get facadeQuoteCustomerMaterial => 'Customer\'s material';

  @override
  String get facadeQuotePieces => 'Pieces';

  @override
  String get facadeQuoteArea => 'Area';

  @override
  String get facadeQuoteTotal => 'Total';

  @override
  String get facadeQuotePrepayment => 'Prepayment';

  @override
  String get facadeQuoteBalance => 'Balance';

  @override
  String get facadeRulesNotOffered => 'Not offered';

  @override
  String get facadeRulesTitle => 'Order rules';

  @override
  String get facadeRulesDoubleSidedFactor => 'Double-sided factor (×)';

  @override
  String get facadeRulesEmptyMeansOff => 'Empty — not offered';

  @override
  String get facadeRulesDiscount => 'Discount for customer\'s material';

  @override
  String get facadeRulesDemolitionRate => 'Demolition price';

  @override
  String get facadeRulesPrepayment => 'Prepayment by default';

  @override
  String get facadeOrderSection => 'Place the order';

  @override
  String get facadeOrderPickCustomer => 'Choose a customer';

  @override
  String get facadeOrderSearchCustomer => 'Name — press Enter';

  @override
  String get facadeOrderNoCustomers => 'No customers found';

  @override
  String get facadeOrderPickDate => 'Choose the due date';

  @override
  String facadeOrderDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get facadeOrderCreate => 'Create order';

  @override
  String facadeOrderCreated(String name) {
    return 'Order $name created';
  }

  @override
  String orderPrepaymentDue(String amount) {
    return 'Prepayment due: $amount';
  }

  @override
  String get facadeJobsTitle => 'Facades to make';

  @override
  String get facadeJobsEmptyTitle => 'No facades to make';

  @override
  String get facadeJobsEmptyMessage =>
      'Facades appear here once an order is placed.';

  @override
  String facadeJobsDue(String date) {
    return 'due $date';
  }

  @override
  String get pieceWorkTitle => 'Piece work';

  @override
  String get pieceWorkMine => 'My work';

  @override
  String get pieceWorkNothingYet => 'Nothing accrued yet';

  @override
  String get pieceWorkPending => 'Awaiting approval';

  @override
  String get pieceWorkApproved => 'Approved';

  @override
  String get pieceWorkPaid => 'Paid';

  @override
  String get pieceWorkRejected => 'Rejected';

  @override
  String get pieceWorkPcs => 'pcs';

  @override
  String get pieceWorkToApprove => 'To approve';

  @override
  String get pieceWorkNothingToApprove => 'Nothing to approve';

  @override
  String get pieceWorkApprove => 'Approve';

  @override
  String get pieceWorkReject => 'Reject';

  @override
  String get pieceWorkReason => 'Reason — the worker will see it';

  @override
  String get pieceWorkRates => 'Rates';

  @override
  String get pieceWorkAddRate => 'Add a rate';

  @override
  String get pieceWorkDisabled => 'Disabled';

  @override
  String get pieceWorkCoefficients => 'Overtime and weekends';

  @override
  String get pieceWorkOvertime => 'Overtime';

  @override
  String get pieceWorkWeekend => 'Weekend';

  @override
  String get pieceWorkAfter => 'after';

  @override
  String get pieceWorkNoCoefficient => 'as usual';

  @override
  String get pieceWorkOperation => 'Operation';

  @override
  String get pieceWorkOperationHint =>
      'As named in the shop, or «Фасад» for finished facades';

  @override
  String get pieceWorkPerPiece => 'per piece';

  @override
  String get pieceWorkRate => 'Rate';

  @override
  String get pieceWorkEnabled => 'In use';

  @override
  String get pieceWorkShiftEnd => 'Shift ends at (HH:MM)';

  @override
  String get pieceWorkSaturdayOff => 'Saturday is a day off';

  @override
  String get pieceWorkSundayOff => 'Sunday is a day off';

  @override
  String pieceWorkEstimate(String amount) {
    return 'Piece rate: ~$amount';
  }

  @override
  String get expensesTitle => 'Urgent expenses';

  @override
  String get expensesAdd => 'Add an expense';

  @override
  String get expensesPendingTotal => 'Awaiting a decision';

  @override
  String get expensesEmptyTitle => 'No expenses';

  @override
  String get expensesEmptyMessage =>
      'Spent money on the job? Write it down here, with the receipt.';

  @override
  String get expensesFiled => 'Expense recorded';

  @override
  String get expensesReceiptNotSent =>
      'Recorded, but the receipt photo was not sent.';

  @override
  String get expensesAmount => 'Amount';

  @override
  String get expensesPurpose => 'What for';

  @override
  String get expensesCategory => 'Category';

  @override
  String get expensesReceipt => 'Photo of the receipt';

  @override
  String get pinAdminTitle => 'PIN sign-in';

  @override
  String get pinAdminSubtitle => 'Shop-floor tablets and who signs in on them';

  @override
  String get pinAdminTablets => 'Tablets';

  @override
  String get pinAdminRegisterThis => 'Make this device a PIN tablet';

  @override
  String pinAdminThisIs(String label) {
    return 'This device: $label';
  }

  @override
  String get pinAdminRevoked => 'Switched off';

  @override
  String get pinAdminRevoke => 'Switch off';

  @override
  String get pinAdminPeople => 'People with a PIN';

  @override
  String get pinAdminLocked => 'Locked after wrong attempts';

  @override
  String get pinAdminClear => 'Remove PIN';

  @override
  String get pinAdminAssign => 'Assign a PIN';

  @override
  String get pinAdminTabletName => 'Tablet name, e.g. «Shop, cutting»';

  @override
  String get pinAdminRegistered => 'Tablet registered';

  @override
  String get pinAdminChoosePerson => 'Employee';

  @override
  String get pinAdminNewPin => 'PIN, 4 to 6 digits';

  @override
  String get pinAdminPinSet => 'PIN assigned';

  @override
  String get pinLoginTitle => 'Sign in with PIN';

  @override
  String get pinLoginSubtitle => 'Choose yourself and enter your PIN';

  @override
  String get pinLoginUnavailableTitle => 'This tablet is not set up for PINs';

  @override
  String get pinLoginUnavailableMessage =>
      'Ask the administrator to register it in Settings.';

  @override
  String get pinLoginPin => 'PIN';

  @override
  String get materialStockTitle => 'Materials';

  @override
  String get materialStockOnHand => 'On hand';

  @override
  String get materialStockReceive => 'Receive';

  @override
  String get materialStockLists => 'Lists';

  @override
  String get materialStockEmptyTitle => 'Nothing in stock yet';

  @override
  String get materialStockEmptyMessage =>
      'Purchases appear here once they are received.';

  @override
  String materialStockAverage(String price) {
    return 'Average price $price';
  }

  @override
  String get materialStockFillAll => 'Fill in every field.';

  @override
  String materialStockReceived(String title, String onHand) {
    return '$title: received, now $onHand';
  }

  @override
  String get materialStockName => 'Material name';

  @override
  String get materialStockSupplier => 'Bought from';

  @override
  String get materialStockQty => 'How many';

  @override
  String get materialStockUnit => 'Unit';

  @override
  String get materialStockPrice => 'Price per unit';

  @override
  String get materialStockSuppliers => 'Suppliers';

  @override
  String get materialStockAdd => 'Add';

  @override
  String materialStockAdded(String value) {
    return '«$value» added';
  }

  @override
  String materialStockOff(String value) {
    return '$value (off)';
  }

  @override
  String get materialStockOpen => 'Materials';

  @override
  String get directionAll => 'All';

  @override
  String get directionFurniture => 'Furniture';

  @override
  String get directionFacades => 'Facades';

  @override
  String get orderUrgent => 'Urgent';

  @override
  String get tierNew => 'New';

  @override
  String get tierRegular => 'Regular';

  @override
  String get tierVip => 'VIP';

  @override
  String get facadeSpecTitle => 'Technical details';

  @override
  String get facadeSpecThickness => 'Thickness, mm';

  @override
  String get facadeSpecDecorTop => 'Face decor';

  @override
  String get facadeSpecDecorBottom => 'Back decor';

  @override
  String get facadeSpecEdge => 'Edge profile';

  @override
  String get facadeSpecNone => '—';

  @override
  String facadeSpecGroup(String group) {
    return 'group “$group”';
  }

  @override
  String materialStockHeld(String onHand, String reserved) {
    return 'On hand $onHand · reserved $reserved';
  }

  @override
  String materialStockFree(String qty) {
    return '$qty free';
  }

  @override
  String get facadeMaterialsTitle => 'Materials for the order';

  @override
  String facadeMaterialsLine(String needed, String held, String issued) {
    return 'need $needed · held $held · written off $issued';
  }

  @override
  String facadeMaterialsShort(String qty) {
    return 'short $qty';
  }

  @override
  String get facadeMaterialsHeld => 'All held';

  @override
  String get facadeMaterialsReserve => 'Reserve what is free';

  @override
  String get facadeMaterialsEmpty => 'Nothing needed from the warehouse';

  @override
  String get crewTitle => 'Who made it?';

  @override
  String get crewHint =>
      'Tick the crew. Shares in % are optional — empty means equal.';

  @override
  String get crewTooSmall => 'A crew is at least two people.';

  @override
  String get crewSharesAllOrNone =>
      'Give everyone a share — or no one, for equal shares.';

  @override
  String get crewDone => 'Done';

  @override
  String get crewDoneTogether => 'Done — made together…';

  @override
  String get payrollTitle => 'Pay sheet';

  @override
  String get payrollCopyCsv => 'Copy for accounting (CSV)';

  @override
  String get payrollCsvCopied => 'Pay sheet copied — paste it into Excel';

  @override
  String get payrollPrevMonth => 'Previous month';

  @override
  String get payrollNextMonth => 'Next month';

  @override
  String get payrollEmpty => 'Nothing accrued this month';

  @override
  String get payrollTotal => 'Total to pay';

  @override
  String get payrollPiece => 'Piece work';

  @override
  String get payrollDailyBonus => 'Daily bonuses';

  @override
  String get payrollMonthlyBonus => 'Monthly bonus';

  @override
  String get payrollBonus => 'Bonus';

  @override
  String get payrollFine => 'Fines';

  @override
  String get payrollAdvance => 'Advances';

  @override
  String payrollPending(String amount) {
    return 'Not yet approved: $amount';
  }

  @override
  String get payrollAdjustments => 'Advances, fines, bonuses';

  @override
  String get payrollAddAdjustment => 'Add';

  @override
  String get payrollNoAdjustments => 'None this month';

  @override
  String get payrollReverse => 'Reverse';

  @override
  String get payrollEmployee => 'Employee';

  @override
  String get payrollAmount => 'Amount';

  @override
  String get payrollReason => 'Reason';

  @override
  String get bonusToday => 'Today\'s bonus';

  @override
  String get bonusMonth => 'This month\'s bonus';

  @override
  String bonusReached(String bonus) {
    return 'Reached — bonus $bonus';
  }

  @override
  String bonusLeft(String left, String bonus) {
    return '$left to go for $bonus';
  }

  @override
  String get bonusRules => 'Bonuses';

  @override
  String bonusRuleDay(String threshold, String bonus) {
    return 'From $threshold a day — $bonus';
  }

  @override
  String bonusRuleMonth(String threshold, String bonus) {
    return 'From $threshold a month — $bonus';
  }

  @override
  String get bonusDayThreshold => 'Daily threshold';

  @override
  String get bonusDayAmount => 'Daily bonus';

  @override
  String get bonusMonthThreshold => 'Monthly threshold';

  @override
  String get bonusMonthAmount => 'Monthly bonus';

  @override
  String get crewSplitPercent => 'In %';

  @override
  String crewSplitByAmount(String unit) {
    return 'Who made how much, $unit';
  }

  @override
  String get crewHintAmount =>
      'Tick the crew and enter how much each made. The amounts must add up to the total.';

  @override
  String get crewMadeTogether => 'Made together…';

  @override
  String crewChosen(int count) {
    return 'Crew: $count people';
  }

  @override
  String get crewClear => 'Remove the crew';

  @override
  String get unitPieces => 'pcs';

  @override
  String get unitSquareMetres => 'm²';

  @override
  String get payrollPaid => 'Paid out';

  @override
  String get payrollLeft => 'Left to pay';

  @override
  String get payrollMarkPaid => 'Mark as paid';

  @override
  String payrollMarkPaidConfirm(String name, String amount) {
    return '$name: paid $amount? The period closes — no more advances, fines or bonuses can be entered for it.';
  }

  @override
  String get payrollMarkPaidDone => 'Payout recorded';

  @override
  String get payrollTotalLeft => 'Left to pay in total';

  @override
  String get tradesAction => 'Shop trades';

  @override
  String get tradesTitle => 'What they do';

  @override
  String get tradesHint =>
      'Several are fine. Trades give no rights — the position does.';

  @override
  String get tradesOwn => 'Your own trade';

  @override
  String get tradesAdd => 'Add';

  @override
  String get tradesSaved => 'Trades saved';

  @override
  String get oneCTitle => 'Exchange with 1C';

  @override
  String get oneCSubtitle =>
      'Sales, payments, receipts and pay sheet for accounting';

  @override
  String get oneCEnabled => 'Exchange with 1C is on';

  @override
  String get oneCOffHint =>
      'Exchange is off. If the company keeps no 1C, leave it so.';

  @override
  String get oneCHowTo =>
      'In 1C: «Load data from a spreadsheet» — paste what you copied. Dates DD.MM.YYYY, decimal comma.';

  @override
  String get oneCCopy => 'Copy';

  @override
  String oneCCopied(String title, int count) {
    return '$title: $count rows. Paste into 1C.';
  }

  @override
  String get pressLayoutTitle => 'Press layout';

  @override
  String get pressTextured => 'TEXTURED — DO NOT TURN';

  @override
  String get pressPlain => 'Plain — may be turned';

  @override
  String pressLoad(int count, String metres) {
    return 'Load $count · section $metres m';
  }

  @override
  String pressFilmTotal(String metres) {
    return 'Film: $metres m';
  }

  @override
  String pressCorrected(String reason, String metres) {
    return 'Corrected by hand: $reason. Layout says $metres m.';
  }

  @override
  String pressTooBig(String positions) {
    return 'Larger than the press table: lines $positions';
  }

  @override
  String get pressCorrect => 'Correct the metres';

  @override
  String get pressMetres => 'Film, metres';

  @override
  String get pressReason => 'Why not as laid out';

  @override
  String get pressBackToLayout => 'Back to the layout';

  @override
  String get pressNoFilm => 'The order has no PVC-film facades.';

  @override
  String get pressSettingsTitle => 'Press: area, gap, sections';

  @override
  String get pressLength => 'Working length, mm';

  @override
  String get pressWidth => 'Working width, mm';

  @override
  String get pressMargin => 'Margin at the edge, mm';

  @override
  String get pressGap => 'Gap between parts, mm';

  @override
  String get pressSections => 'Sections: film and working length';

  @override
  String get pressSectionFilm => 'Film, m';

  @override
  String get pressAddSection => 'Add a section';

  @override
  String get pressSaved => 'Press settings saved';

  @override
  String get materialTextured => 'Textured film';

  @override
  String get materialTexturedHint =>
      'Parts are not turned on the press; the map says «DO NOT TURN»';

  @override
  String get pressPrint => 'Print the layout';

  @override
  String pressPrintLoad(int count, int total, String metres) {
    return 'Load $count of $total · section $metres m';
  }

  @override
  String pressPrintSheet(int count) {
    return 'Sheet $count';
  }

  @override
  String pressPrintCopies(int count) {
    return 'Copies: $count';
  }

  @override
  String pressPrintSize(String size) {
    return 'Size: $size mm';
  }

  @override
  String pressPrintSection(String metres) {
    return 'Film section: $metres m';
  }

  @override
  String pressPrintArea(String area) {
    return 'Sheet area: $area m²';
  }

  @override
  String pressPrintParts(String area, String share) {
    return 'Parts: $area m² ($share%)';
  }

  @override
  String pressPrintWaste(String area, String share) {
    return 'Waste: $area m² ($share%)';
  }

  @override
  String pressPrintCount(int count) {
    return 'Parts: $count';
  }

  @override
  String pressPrintPerimeter(String metres) {
    return 'Parts perimeter: $metres m';
  }

  @override
  String pressPrintGap(String gap, String margin) {
    return 'Gap: $gap mm · margin: $margin mm';
  }

  @override
  String get pressPrintDetails => 'Parts';

  @override
  String pressPrintPage(int count) {
    return 'Page $count';
  }

  @override
  String get logisticsTitle => 'Logistics';

  @override
  String get logisticsDeliveries => 'Deliveries';

  @override
  String get logisticsSummary => 'Summary';

  @override
  String get logisticsAdd => 'Record a delivery';

  @override
  String get logisticsEmpty => 'No deliveries this month';

  @override
  String get logisticsEmptyMessage =>
      'A van, a taxi, a transport company — write down what bringing the material cost.';

  @override
  String get logisticsAmount => 'Delivery cost';

  @override
  String get logisticsFrom => 'From (city)';

  @override
  String get logisticsTransport => 'Delivered by';

  @override
  String get logisticsCarrier => 'Carrier (optional)';

  @override
  String get logisticsWhat => 'What came';

  @override
  String get logisticsQty => 'Quantity';

  @override
  String get logisticsUnit => 'Unit';

  @override
  String get logisticsOrder => 'Order № (if for an order)';

  @override
  String get logisticsOrderedOn => 'Ordered';

  @override
  String get logisticsDeliveredOn => 'Arrived';

  @override
  String get logisticsUrgent => 'Urgent (paid extra for speed)';

  @override
  String get logisticsNote => 'Note';

  @override
  String get logisticsSaved => 'Delivery recorded';

  @override
  String get logisticsCancel => 'Cancel the record';

  @override
  String get logisticsCancelReason => 'Why cancel';

  @override
  String logisticsCancelled(String reason) {
    return 'Cancelled: $reason';
  }

  @override
  String logisticsDays(int count) {
    return '$count days on the road';
  }

  @override
  String logisticsTotal(String amount) {
    return 'This month: $amount';
  }

  @override
  String logisticsPrevious(String amount) {
    return 'Last month: $amount';
  }

  @override
  String get logisticsByCategory => 'By material';

  @override
  String get logisticsByCity => 'By city';

  @override
  String get logisticsByTransport => 'By way of delivery';

  @override
  String get logisticsByCarrier => 'By carrier';

  @override
  String get logisticsPerUnit => 'Per unit';

  @override
  String logisticsPerUnitLine(String amount, String unit, String qty) {
    return '$amount per $unit · $qty $unit delivered';
  }

  @override
  String logisticsCount(int count) {
    return 'deliveries: $count';
  }

  @override
  String logisticsAverageDays(String days) {
    return '$days days on the road on average';
  }

  @override
  String logisticsUrgentLine(int count, String amount) {
    return 'Urgent: $count for $amount';
  }

  @override
  String get logisticsUnlinked => 'Receipts without a delivery';

  @override
  String get logisticsUnlinkedHint =>
      'The material came but its delivery was not written down. Write it — or 0 ₸ if the supplier brought it.';

  @override
  String get logisticsWrite => 'Record';

  @override
  String get logisticsDeliveryOptional => 'Delivery (if paid for)';

  @override
  String get materialMin => 'Minimum on hand';

  @override
  String get materialMinHint =>
      'When free stock drops below it, the owner is told to order more. Empty or 0 — no warning.';

  @override
  String materialLow(String minimum) {
    return 'Low — minimum $minimum';
  }

  @override
  String get stockCountTab => 'Count';

  @override
  String get stockCountTitle => 'What is on the shelf now';

  @override
  String get stockCountHint =>
      'Type what you counted. Empty rows are left alone. Differences from the books are posted as one document, and the month\'s usage is counted from this figure.';

  @override
  String stockCountBooks(String qty) {
    return 'In the books: $qty';
  }

  @override
  String get stockCountOnShelf => 'on shelf';

  @override
  String get stockCountSave => 'Save the count';

  @override
  String get stockCountNothing => 'Nothing entered.';

  @override
  String stockCountSaved(int count) {
    return 'Count saved, differences: $count';
  }

  @override
  String get stockUsageTitle => 'The month\'s usage';

  @override
  String get stockUsageNotCounted =>
      'Not counted this month yet — «left» is still from the books.';

  @override
  String stockUsageCountedOn(String date) {
    return 'Counted on $date';
  }

  @override
  String stockUsageLine(String start, String bought, String end, String unit) {
    return 'Start $start · bought $bought · left $end $unit';
  }

  @override
  String stockUsageUsed(String used, String orders) {
    return 'Used in fact $used, by orders $orders';
  }

  @override
  String stockUsageLoss(String qty, String money) {
    return 'Unaccounted: $qty$money';
  }

  @override
  String get navFacades => 'Custom facades';

  @override
  String get navFilmSale => 'PVC film sales';

  @override
  String get navWorkshop => 'Production floor';

  @override
  String get navGroupSell => 'What we sell';

  @override
  String get navGroupMoney => 'Money';

  @override
  String get navGroupCompany => 'Company';

  @override
  String get facadesHint => 'MDF facades: from the quote to handing over';

  @override
  String get facadesPath => 'Order path — tap a stage to open the shop plan';

  @override
  String facadesStageM2(String area) {
    return '$area m²';
  }

  @override
  String get navMdf => 'MDF';

  @override
  String get mdfOrders => 'Orders';

  @override
  String get mdfOrdersHint => 'All orders: due dates, payments, debt';

  @override
  String get mdfQuoteHint => 'Lines, m², price — and the order';

  @override
  String get mdfJobsHint => 'Queued, in work, done';

  @override
  String get mdfPress => 'Press';

  @override
  String get mdfPressHint =>
      'Table and section sizes; the layout opens from an order';

  @override
  String get mdfStockHint => 'MDF and film: on hand, low, month-end count';

  @override
  String get mdfLogisticsHint => 'MDF and film deliveries and their cost';

  @override
  String get mdfPricesHint => 'Price per m² by milling and finish';

  @override
  String get materialsAdd => 'Add material';

  @override
  String get materialsName => 'Material name';

  @override
  String get materialsManufacturer => 'Manufacturer';

  @override
  String get materialsDecorCode => 'Decor code';

  @override
  String get materialsThicknessInput => 'Thickness, mm';

  @override
  String get materialsSheetWidthInput => 'Sheet width, mm';

  @override
  String get materialsSheetHeightInput => 'Sheet height, mm';

  @override
  String get materialsEdgeWidthInput => 'Edge width, mm';

  @override
  String get materialsFitsThicknessInput => 'For board thickness, mm';

  @override
  String get materialsPositiveDimension => 'Enter a positive number';

  @override
  String get materialsCreateSuccess => 'Material added';

  @override
  String get materialsSave => 'Save';

  @override
  String get facadePricesEmptyNotSold => 'Empty — not sold';

  @override
  String get facadePricesNeedOne => 'Enter a price for at least one finish.';

  @override
  String get mdfOrdersTitle => 'MDF orders';

  @override
  String get mdfOrderNew => 'New order';

  @override
  String get mdfOrderSearch => 'No., customer, phone, colour';

  @override
  String get mdfFilterAll => 'All';

  @override
  String get mdfFilterOverdue => 'Overdue';

  @override
  String get mdfFilterDebt => 'With debt';

  @override
  String get mdfStatusDraft => 'Draft';

  @override
  String get mdfStatusAccepted => 'Accepted';

  @override
  String get mdfStatusInShop => 'In the shop';

  @override
  String get mdfStatusReady => 'Ready';

  @override
  String get mdfStatusHandedOver => 'Handed over';

  @override
  String get mdfStatusOnHold => 'On hold';

  @override
  String get mdfStatusCancelled => 'Cancelled';

  @override
  String get mdfStageCut => 'Cut';

  @override
  String get mdfStageMill => 'Milling';

  @override
  String get mdfStageSand => 'Sanding';

  @override
  String get mdfStageVacuum => 'Vacuum';

  @override
  String get mdfStagePaint => 'Painting';

  @override
  String get mdfEmpty => 'No orders yet';

  @override
  String get mdfEmptyHint => 'Tap «New order» to write the first one.';

  @override
  String mdfDebt(String amount) {
    return 'Debt $amount';
  }

  @override
  String get mdfCustomer => 'Customer';

  @override
  String get mdfDue => 'Due';

  @override
  String get mdfHeadSection => 'Facade';

  @override
  String get mdfThickness => 'Thickness, mm';

  @override
  String get mdfFinish => 'Finish';

  @override
  String get mdfDecorTop => 'Face decor';

  @override
  String get mdfDecorBottom => 'Back decor';

  @override
  String get mdfPatina => 'Patina';

  @override
  String get mdfMilling => 'Milling';

  @override
  String get mdfEdge => 'Edge';

  @override
  String get mdfExtraName => 'Project (kitchen, address)';

  @override
  String get mdfDefaultRate => 'Default price per m²';

  @override
  String get mdfNone => '—';

  @override
  String get mdfLinesSection => 'Lines';

  @override
  String get mdfHeight => 'Height';

  @override
  String get mdfWidth => 'Width';

  @override
  String get mdfQty => 'Qty';

  @override
  String get mdfNote => 'Note';

  @override
  String get mdfRate => 'Price m²';

  @override
  String get mdfArea => 'm²';

  @override
  String get mdfAmount => 'Amount';

  @override
  String get mdfAddLine => 'Add line';

  @override
  String get mdfNoPrice => 'no price';

  @override
  String get mdfManualRate => 'price by hand';

  @override
  String mdfTotals(String pieces, String area, String total) {
    return '$pieces pcs · $area m² · $total';
  }

  @override
  String mdfPaidDebt(String paid, String debt) {
    return 'Paid $paid · Debt $debt';
  }

  @override
  String get mdfSaveDraft => 'Save';

  @override
  String get mdfAccept => 'Accept the order';

  @override
  String get mdfDeleteDraft => 'Delete draft';

  @override
  String get mdfSaved => 'Order saved';

  @override
  String get mdfAccepted => 'Order accepted — prices fixed';

  @override
  String get mdfNeedCustomer => 'Pick the customer and the due date.';

  @override
  String get mdfNeedLine => 'Add at least one line.';

  @override
  String get mdfStagesSection => 'Stages';

  @override
  String get mdfPaymentsSection => 'Payments';

  @override
  String get mdfAddPayment => 'Add payment';

  @override
  String get mdfPaymentAmount => 'Amount, ₸';

  @override
  String get mdfPaymentMethod => 'Method';

  @override
  String get mdfNoPayments => 'No payments yet';

  @override
  String get mdfHold => 'Put on hold';

  @override
  String get mdfResume => 'Resume';

  @override
  String get mdfHoldReason => 'Why on hold';

  @override
  String get mdfCancelOrder => 'Cancel order';

  @override
  String get mdfCancelReason => 'Reason';

  @override
  String get mdfHandOver => 'Hand over';

  @override
  String get mdfHandOverComment => 'Why hand over with a debt';

  @override
  String get mdfOverdue => 'Overdue';

  @override
  String get mdfDueSoon => 'Due soon';

  @override
  String get mdfConfirm => 'Done';

  @override
  String get mdfCancel => 'Cancel';

  @override
  String get mdfLineDelete => 'Delete line';

  @override
  String get mdfLineDuplicate => 'Duplicate';

  @override
  String get mdfChangeAccepted =>
      'An accepted order changes through «Change order» — coming.';

  @override
  String mdfPrintTitle(String name) {
    return 'Order No. $name';
  }

  @override
  String get mdfPrintAccepted => 'Accepted';

  @override
  String get mdfPrintPhone => 'Phone';

  @override
  String get mdfPrintPaid => 'Paid';

  @override
  String get mdfPrintDebt => 'Balance';

  @override
  String get mdfPrintTotal => 'Total:';

  @override
  String get mdfPrintClient => 'Customer copy';

  @override
  String get mdfPrintShop => 'Shop copy';

  @override
  String get mdfPasteSizes => 'Paste sizes';

  @override
  String get mdfPasteHint =>
      'Copy sizes from WhatsApp, Excel or a form — one part per line: «348 997 2», «348x997-2pcs». Words after the count become the note.';

  @override
  String mdfPasteFound(int count) {
    return 'Lines found: $count';
  }

  @override
  String mdfPasteSkipped(String rows) {
    return 'Skipped (not sizes): $rows';
  }

  @override
  String get mdfPasteAdd => 'Add to the order';

  @override
  String mdfPasted(int count) {
    return 'Lines added: $count';
  }

  @override
  String get mdfNewCustomer => 'New customer';

  @override
  String mdfNewCustomerOption(String name) {
    return '+ New customer «$name»';
  }

  @override
  String get mdfRepeat => 'Repeat order';

  @override
  String get filmShortageTitle => 'Film to buy';

  @override
  String get filmShortageEmpty => 'No film needed for orders';

  @override
  String get filmShortageEmptyHint =>
      'Accepted film orders show here until the vacuum is ticked.';

  @override
  String filmShortageTotals(String needed, String toBuy) {
    return 'Needed $needed m · to buy $toBuy m';
  }

  @override
  String get filmShortageByFilm => 'By film';

  @override
  String get filmShortageByOrder => 'By order';

  @override
  String filmShortageLine(
    String orders,
    String needed,
    String held,
    String free,
    String unit,
  ) {
    return '$orders orders · needed $needed · held $held · free $free $unit';
  }

  @override
  String filmShortageBuy(String qty, String unit) {
    return 'Buy $qty $unit';
  }

  @override
  String get filmShortageEnough => 'Enough';

  @override
  String filmShortageShort(String qty) {
    return '$qty m short';
  }

  @override
  String get filmShortageNotOnBooks =>
      'This film is not in stock — add it under «Stock».';

  @override
  String get mdfFilmHint => 'How many metres of which film to order';

  @override
  String get mdfDebtsTitle => 'Debts';

  @override
  String get mdfDebtsEmpty => 'No debts';

  @override
  String get mdfDebtsEmptyHint => 'Every accepted order is paid up.';

  @override
  String mdfDebtsTotal(String amount) {
    return 'Total owed: $amount';
  }

  @override
  String get mdfDebtsByCustomer => 'By customer';

  @override
  String get mdfDebtsByOrder => 'By order';

  @override
  String mdfDebtsOrders(int count) {
    return 'Orders owing: $count';
  }

  @override
  String get mdfDebtsHandedOver => 'Handed over owing';

  @override
  String get mdfDebtsHint => 'Who owes what, by customer and order';

  @override
  String get mdfBatchTitle => 'Parts by film';

  @override
  String get mdfBatchHint =>
      'Every part of the open orders of one film, as one list';

  @override
  String get mdfBatchShow => 'Show';

  @override
  String mdfBatchTotals(String orders, String pieces, String area) {
    return '$orders orders · $pieces parts · $area m²';
  }

  @override
  String get mdfBatchParts => 'Parts (same sizes summed)';

  @override
  String get mdfBatchLong => 'Long';

  @override
  String get mdfBatchShort => 'Short';

  @override
  String get mdfBatchOrders => 'Orders';

  @override
  String get mdfChangeOrder => 'Change order';

  @override
  String get mdfChangeReason => 'What changes and why';

  @override
  String get mdfSaveChange => 'Save changes';

  @override
  String get mdfChanged => 'Order changed — written into its history';

  @override
  String get mdfHistorySection => 'History';

  @override
  String get mdfPlanTitle => 'Shop plan';

  @override
  String get mdfPlanHint => 'What waits at each stage, in m²';

  @override
  String mdfPlanInWork(String area) {
    return 'In work: $area m²';
  }

  @override
  String get mdfPlanTick => 'Stage done';

  @override
  String mdfPlanTicked(String order, String stage) {
    return '$order: «$stage» ticked';
  }

  @override
  String get mdfPlanIntake => 'Orders taken in, by day';

  @override
  String mdfPlanIntakeDay(String orders, String area) {
    return '$orders orders · $area m²';
  }

  @override
  String get mdfCashTitle => 'Cash book';

  @override
  String get mdfCashHint => 'Payments by method, expenses, balance';

  @override
  String get mdfCashToday => 'Today';

  @override
  String get mdfCashWeek => '7 days';

  @override
  String get mdfCashMonth => '30 days';

  @override
  String get mdfCashIn => 'In';

  @override
  String get mdfCashOut => 'Out';

  @override
  String get mdfCashNet => 'Balance';

  @override
  String get mdfCashByDay => 'By day';

  @override
  String get mdfCashPayments => 'Payments';

  @override
  String get mdfCashNoPayments => 'No payments in this period';

  @override
  String get mdfCashExpenses => 'Expenses';

  @override
  String get mdfReportTitle => 'Order report';

  @override
  String get mdfReportHint => 'Orders, m² and money for a period';

  @override
  String get mdfReportThisMonth => 'This month';

  @override
  String get mdfReportLastMonth => 'Last month';

  @override
  String get mdfReportYear => 'Year';

  @override
  String get mdfReportOrders => 'Orders';

  @override
  String get mdfReportArea => 'Area';

  @override
  String get mdfReportTotal => 'Total';

  @override
  String get mdfReportPaid => 'Paid';

  @override
  String get mdfReportDebt => 'Owed';

  @override
  String get mdfReportCancelled => 'Cancelled';

  @override
  String get mdfReportByDecor => 'By film';

  @override
  String get mdfReportTopCustomers => 'Top customers';

  @override
  String mdfReportLine(String orders, String area, String total) {
    return '$orders orders · $area m² · $total';
  }

  @override
  String mdfReportOwes(String amount) {
    return 'owes $amount';
  }

  @override
  String mdfVolumeVersus(String arrow, int pct) {
    return '$arrow $pct% on the period before';
  }

  @override
  String get mdfVolumeDone => 'Done by stage';

  @override
  String get mdfVolumeQueue => 'Waiting now — where it jams';

  @override
  String get mdfVolumeTitle => 'Shop — work volume';

  @override
  String get mdfVolumeHint => 'm² per worker and stage';

  @override
  String get mdfVolumeByWorker => 'By worker';

  @override
  String get mdfVolumeEmpty => 'No stages ticked in this period';

  @override
  String mdfVolumeUnassigned(String area) {
    return 'With nobody named: $area';
  }

  @override
  String get mdfWhoDidIt => 'Who did this stage?';

  @override
  String get mdfWorkerNobody => 'Nobody named';

  @override
  String get mdfDictTitle => 'Lists';

  @override
  String get mdfDictHint => 'Thickness, finish, colours, patina, milling, edge';

  @override
  String get mdfDictOpen => 'List';

  @override
  String get mdfDictDecor => 'Film colour';

  @override
  String get mdfDictAdd => 'Add';

  @override
  String get mdfDictRename => 'Rename';

  @override
  String get mdfDictDelete => 'Delete';

  @override
  String get mdfDictValue => 'Value';

  @override
  String get mdfDictEmpty => 'The list is empty. Press «+» to add.';

  @override
  String mdfDictDeleteAsk(String value) {
    return 'Delete «$value»? If orders already use it, it only leaves the list; the orders stay as they are.';
  }

  @override
  String get mdfCustomers => 'Customers';

  @override
  String get mdfCustomerSearch => 'Name, phone or organisation';

  @override
  String get mdfNothingFound => 'Nothing found';

  @override
  String get mdfCustomerName => 'Name';

  @override
  String get mdfCustomerPhone => 'Phone';

  @override
  String get mdfCustomerOrg => 'Organisation';

  @override
  String mdfCustomerDeleteAsk(String name) {
    return 'Delete the customer «$name»? If they have orders, they only leave the list; the orders stay.';
  }

  @override
  String get mdfMaterial => 'Material';

  @override
  String get mdfFilm => 'Film';

  @override
  String get mdfFilmNone => 'No film chosen';

  @override
  String get mdfFilmPick => 'The group\'s film';

  @override
  String get mdfFilmRate => 'Price per m²';

  @override
  String get mdfFilmRemove => 'Remove the group';

  @override
  String mdfFilmRemoveAsk(String film) {
    return 'Remove the «$film» group with its positions?';
  }

  @override
  String get mdfFilmSubtotal => 'Group total';

  @override
  String get mdfAddFilm => 'Add a film';

  @override
  String get mdfBackSide => 'Back side';

  @override
  String get mdfBackSideShort => 'back';

  @override
  String get mdfTagUrgent => 'Urgent';

  @override
  String get mdfTagRework => 'Rework';

  @override
  String get mdfTagWarranty => 'Warranty';

  @override
  String get mdfTagVip => 'VIP';

  @override
  String get mdfTagFurnitureMaker => 'Furniture maker';

  @override
  String get mdfTagNew => 'New';

  @override
  String get mdfTagPrepayOnly => 'Prepayment only';

  @override
  String get mdfFilterUrgent => 'Urgent';

  @override
  String get mdfFilterFurnitureMakers => 'Furniture makers';

  @override
  String get mdfFilterRework => 'Reworks';

  @override
  String get mdfColEdge => 'Edge';

  @override
  String get mdfEdgeDefault => 'Default edge';

  @override
  String get mdfExtraAdd => '+ extra';

  @override
  String get mdfDeadlineToday => 'Today';

  @override
  String get mdfDeadlineTomorrow => 'Tomorrow';

  @override
  String get mdfDeadlineLater => 'Later';

  @override
  String get mdfAtRisk => 'Won\'t make it';

  @override
  String get mdfTvTitle => 'Shop screen';

  @override
  String get mdfTvHint => 'Today, tomorrow, later — for the shop\'s TV';

  @override
  String mdfPrepayOnlyAsk(String customer) {
    return '$customer: prepayment only, and nothing is paid. Accept anyway?';
  }

  @override
  String get mdfThicknessShort => 'Thickness';

  @override
  String get mdfCopyOrder => 'Copy order';

  @override
  String get mdfAddStage => 'stage';

  @override
  String get mdfStageReady => 'Ready';

  @override
  String get mdfPayTransfer => 'Transfer';

  @override
  String get mdfPayCash => 'Cash';

  @override
  String get mdfPayCard => 'Card';

  @override
  String get mdfPayBank => 'Bank';

  @override
  String get mdfDictBank => 'Banks';

  @override
  String get mdfDictLocked => 'Always on the list — can\'t be removed';

  @override
  String get mdfCoatingPvc => 'PVC';

  @override
  String get mdfCoatingPaint => 'Paint';

  @override
  String get mdfCoatingRaw => 'Raw';

  @override
  String get mdfCoatingPick => 'Which coating?';

  @override
  String get mdfColor => 'Colour';

  @override
  String get mdfDictPaint => 'Paints';

  @override
  String get mdfPaintNone => 'No paint chosen';

  @override
  String get mdfCoatingNotChosen => 'No coating chosen';

  @override
  String mdfCoatingSwitchAsk(String film, String coating) {
    return '«$film» is not in the «$coating» list. The block\'s colour will be cleared; positions, sizes and prices stay. Change it?';
  }

  @override
  String get mdfColCoating => 'Coating';

  @override
  String get mdfPrintHeightShort => 'H';

  @override
  String get mdfPrintWidthShort => 'W';

  @override
  String get mdfPrintThickShort => 'Thk.';

  @override
  String get mdfPrintMaterialShort => 'Mat.';

  @override
  String get mdfPrintSubtotal => 'Total';

  @override
  String get mdfPrintPieces => 'pcs';

  @override
  String get mdfChangesTitle => 'What changed';

  @override
  String get mdfReasonClient => 'Customer changed it';

  @override
  String get mdfReasonMistake => 'Mistake at intake';

  @override
  String get mdfReasonAdded => 'Positions added';

  @override
  String get mdfReasonPrice => 'Price changed';

  @override
  String get mdfLeaveUnsaved =>
      'Leave without saving? The changes will be lost.';

  @override
  String get mdfLeave => 'Leave';

  @override
  String mdfChangeAdded(int n) {
    return 'Position $n added';
  }

  @override
  String mdfChangeRemoved(int n) {
    return 'Position $n removed';
  }

  @override
  String get mdfTagsTitle => 'Tags';

  @override
  String mdfDueInDays(int n) {
    return '+$n days';
  }

  @override
  String get mdfDueCalendar => 'Pick in the calendar…';

  @override
  String get mdfPaymentFix => 'Fix';

  @override
  String get mdfPaymentDelete => 'Delete payment';

  @override
  String get mdfPaymentFixTitle => 'Fix the payment';

  @override
  String get mdfPaymentReason => 'Reason';

  @override
  String get mdfPayReasonAmount => 'Wrong amount';

  @override
  String get mdfPayReasonMethod => 'Wrong method';

  @override
  String get mdfPayReasonBank => 'Wrong bank';

  @override
  String get mdfPayReasonTwice => 'Entered twice';

  @override
  String get mdfPaymentCancelled => 'cancelled';

  @override
  String get mdfHandOverCheck => 'Check before hand-over';

  @override
  String get mdfHandOverStagesDone => 'All stages done';

  @override
  String mdfHandOverCounted(int n) {
    return 'Counted the pieces: $n';
  }

  @override
  String get mdfTakenByClient => 'The customer';

  @override
  String get mdfTakenByOther => 'Someone else';

  @override
  String get mdfTakenByName => 'Taken by';

  @override
  String get mdfTakenByPhone => 'Phone';

  @override
  String mdfHandedOverOn(String date) {
    return 'Handed over $date';
  }

  @override
  String mdfHandedOverBy(String name) {
    return 'by $name';
  }

  @override
  String mdfTakenBy(String who) {
    return 'taken by $who';
  }

  @override
  String mdfHandedWithDebt(String amount) {
    return 'with a debt of $amount';
  }

  @override
  String get mdfReturnToWork => 'Back to work';

  @override
  String get mdfReturnReason => 'Why back to work';

  @override
  String get mdfHandedOverDone => 'Order handed over';

  @override
  String get mdfPayOrderTotal => 'Order';

  @override
  String get mdfPayPaid => 'Paid';

  @override
  String get mdfPayLeft => 'Left';

  @override
  String get mdfPayAddPart => 'Another method';

  @override
  String mdfPayAfter(String sum, String debt) {
    return 'Total $sum · debt after $debt';
  }

  @override
  String mdfPayOver(String amount) {
    return '$amount more than is left. It may be paid already';
  }

  @override
  String get mdfPayOverOk => 'It is an overpayment / advance';

  @override
  String get mdfNoteShort => 'Note';

  @override
  String get filmCatalogTitle => 'PVC films';

  @override
  String get filmMaker => 'Maker';

  @override
  String get filmType => 'Film surface';

  @override
  String get filmAllTypes => 'Any surface';

  @override
  String filmSearchIn(String maker) {
    return 'Search in $maker';
  }

  @override
  String filmHave(String metres) {
    return 'in stock · $metres m';
  }

  @override
  String get filmToOrder => 'to order';

  @override
  String get filmOff => 'in the archive';

  @override
  String get filmUnassigned => 'no maker';

  @override
  String get filmUnassignedHint =>
      'Colours of the old list, without a maker. If such a film is needed, add it at its maker with “Film” and remove it here. Old orders stay as they are.';

  @override
  String get filmCode => 'Code';

  @override
  String get filmRal => 'Nearest RAL';

  @override
  String get filmSupplier => 'Supplier';

  @override
  String get filmPriceM => 'Purchase, ₸/m';

  @override
  String get filmUrl => 'Web page';

  @override
  String get filmSave => 'Save';

  @override
  String get filmAdd => 'Film';

  @override
  String filmEmpty(String maker) {
    return '$maker has no films yet. Press “Film” to add the first.';
  }

  @override
  String get filmName => 'Film name';

  @override
  String get filmThickness => 'Thickness, mm';

  @override
  String get filmWidth => 'Roll width, mm';

  @override
  String get filmDeptTitle => 'Film department';

  @override
  String get filmCatalogShort => 'Catalogue';

  @override
  String get filmTabStock => 'Stock';

  @override
  String get filmTabSales => 'Sales';

  @override
  String get filmTabCustomers => 'Customers';

  @override
  String get filmCorrectTitle => 'Correct';

  @override
  String get filmCorrectReason => 'Why it is corrected';

  @override
  String get filmCorrectHint =>
      'The old entry stays, struck through — who corrected it and why is seen.';

  @override
  String get filmCorrectSave => 'Correct';

  @override
  String get filmCorrectCancel => 'Cancel the entry';

  @override
  String filmCorrected(String date, String who, String reason) {
    return 'corrected $date · $who · “$reason”';
  }

  @override
  String get filmSaleAddPart => 'another way';

  @override
  String get filmSalePaidFull => 'Paid in full';

  @override
  String filmSaleOverpaid(String amount) {
    return '$amount over the total — not allowed';
  }

  @override
  String get filmThicknessUnknown => 'thickness not given';

  @override
  String get filmThicknessHint =>
      'Not known? Leave it empty and fill it in later';

  @override
  String filmNoThickness(String count) {
    return 'No thickness · $count';
  }

  @override
  String get filmVariants => 'Thicknesses';

  @override
  String get filmVariantAdd => 'Thickness';

  @override
  String filmVariantDeleteAsk(String thickness) {
    return 'Remove the $thickness mm thickness?';
  }

  @override
  String filmReceiveSetPrice(String price) {
    return 'Put the purchase price on the card: $price ₸';
  }

  @override
  String filmReceiveUpdatePrice(String before, String after) {
    return 'Update the card\'s purchase price: $before → $after ₸';
  }

  @override
  String filmSaleRememberRetail(String price) {
    return 'Remember $price ₸ as the retail price';
  }

  @override
  String filmSaleRememberWholesale(String price) {
    return 'Remember $price ₸ as the trade price';
  }

  @override
  String filmPriceSince(String date, String via) {
    return 'since $date · $via';
  }

  @override
  String get filmPriceByHand => 'by hand';

  @override
  String filmMargin(String amount, String percent) {
    return 'Margin: +$amount ₸/m · $percent%';
  }

  @override
  String get filmSaveMore => 'Save and add another';

  @override
  String filmAddedOne(String name) {
    return 'Added: $name';
  }

  @override
  String get filmArchive => 'To the archive';

  @override
  String get filmRestore => 'Bring back from the archive';

  @override
  String filmArchiveChip(String name) {
    return 'Archive · $name';
  }

  @override
  String get filmDelete => 'Delete';

  @override
  String filmDeleteAsk(String name) {
    return 'Delete the film “$name”?';
  }

  @override
  String get filmDeleteHint =>
      'Only a film nothing was done with can be deleted. If it has receipts, sales or orders, send it to the archive.';

  @override
  String get filmChanges => 'History of changes';

  @override
  String get filmChangesEmpty => 'No changes yet.';

  @override
  String get filmCollection => 'Collection';

  @override
  String get filmCollections => 'Collections';

  @override
  String get filmAllCollections => 'All collections';

  @override
  String get filmCollectionAdd => 'New collection';

  @override
  String get filmCollectionRename => 'Rename the collection';

  @override
  String get filmCollectionName => 'Collection name';

  @override
  String filmCollectionRemoveAsk(String name) {
    return 'Remove the collection “$name”?';
  }

  @override
  String get filmCollectionRemoveHint =>
      'Its films stay in the catalogue, without a collection.';

  @override
  String filmCollectionsEmpty(String name) {
    return '$name has no collections yet. Press + to add one.';
  }

  @override
  String filmLooseDropAsk(String name) {
    return 'Remove the colour “$name”?';
  }

  @override
  String get filmLooseDropHint => 'Orders that name it stay as written.';

  @override
  String get filmTabSources => 'Suppliers';

  @override
  String get filmSourceAdd => 'Supplier';

  @override
  String get filmSourcesEmpty =>
      'No suppliers yet. Add where film is bought: a maker\'s branch in a city or a wholesaler.';

  @override
  String get filmSourceName => 'Name (e.g. Adilet · Almaty)';

  @override
  String get filmSrcKind => 'Who it is (branch, wholesaler)';

  @override
  String get filmSrcCity => 'City';

  @override
  String get filmSrcContact => 'Contact person';

  @override
  String get filmSrcPhone => 'Phone';

  @override
  String get filmSrcPhone2 => 'Second phone';

  @override
  String get filmSrcWhatsapp => 'WhatsApp';

  @override
  String get filmSrcAddress => 'Warehouse address';

  @override
  String get filmSrcLead => 'Delivery time';

  @override
  String get filmSrcMinOrder => 'Smallest order';

  @override
  String get filmSrcNote => 'Note';

  @override
  String get filmSrcMakers => 'Whose films it sells';

  @override
  String get filmSourceRemove => 'Remove from the list';

  @override
  String filmSourceRemoveAsk(String name) {
    return 'Remove supplier “$name”?';
  }

  @override
  String get filmSourceRemoveHint => 'Its receipts stay in the history.';

  @override
  String get filmMakerCard => 'Maker\'s card';

  @override
  String get filmMakerSite => 'Site';

  @override
  String get filmMakerSources => 'Where this film is bought';

  @override
  String get filmMakerNoSources =>
      'Nowhere to buy it is named yet. Add a source.';

  @override
  String get filmSourceNew => 'Add a source';

  @override
  String get filmReceiveFrom => 'Where it came from';

  @override
  String get filmSell => 'Sell';

  @override
  String get filmReceive => 'Receipt';

  @override
  String get filmToShop => 'To the shop';

  @override
  String get filmWriteOff => 'Write off';

  @override
  String get filmEditCard => 'Card';

  @override
  String get filmHistory => 'History';

  @override
  String get filmHistoryEmpty => 'Nothing has come or left yet.';

  @override
  String get filmMetresLabel => 'Metres';

  @override
  String get filmNotEnough => 'not that much in stock';

  @override
  String get filmReason => 'Reason';

  @override
  String get filmForOrder => 'For order (optional)';

  @override
  String get filmReasonSample => 'Sample for a customer';

  @override
  String get filmReasonDamaged => 'Damaged roll';

  @override
  String get filmReasonTest => 'Press test';

  @override
  String get filmRetailM => 'Retail, ₸/m';

  @override
  String get filmWholesaleM => 'Wholesale, ₸/m';

  @override
  String get filmRetail => 'retail';

  @override
  String get filmWholesale => 'wholesale';

  @override
  String get filmDiscount => 'Discount, %';

  @override
  String get filmSalePriceM => 'Price, ₸/m';

  @override
  String get filmSaleAddLine => 'Another film';

  @override
  String filmSaleTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String get filmSalePaid => 'Paid now, ₸';

  @override
  String filmSaleDebt(String amount) {
    return 'debt $amount';
  }

  @override
  String get filmSalesEmpty => 'No sales yet.';

  @override
  String get filmCustomersEmpty =>
      'No film customers yet — they appear after the first sale.';

  @override
  String get filmStockEmpty => 'No films yet. Add them in the catalogue.';

  @override
  String filmLow(String metres) {
    return '$metres m · low';
  }

  @override
  String filmLowCount(int n) {
    return 'low in stock · $n';
  }

  @override
  String filmAsleep(int days) {
    return 'asleep · $days d';
  }

  @override
  String filmMonthMetres(String metres) {
    return '$metres m this month';
  }

  @override
  String get filmMoveReceipt => 'receipt';

  @override
  String get filmMoveSale => 'sale';

  @override
  String get filmMoveShop => 'to the shop';

  @override
  String get filmMoveWriteOff => 'write-off';

  @override
  String get filmMoveOther => 'issue';

  @override
  String get filmDeptHint => 'Film stock, sales by the metre, customers';

  @override
  String get filmPayDebt => 'Pay off, ₸';

  @override
  String get filmCancelMove => 'Cancel the sale';

  @override
  String get filmCancelReason => 'Why cancel';

  @override
  String get filmClose => 'Close';

  @override
  String get filmDelivery => 'Delivery';

  @override
  String get filmTransport => 'How it came';

  @override
  String get filmCity => 'From (city)';

  @override
  String get filmDeliveryCost => 'Delivery cost, ₸';

  @override
  String filmDeliveryPerM(String per) {
    return '≈ $per a metre';
  }

  @override
  String get filmReceivedBy => 'Taken in by';

  @override
  String get filmUrgent => 'Urgent';

  @override
  String get filmSeller => 'Seller';

  @override
  String filmTakenBy(String name) {
    return 'taken in by $name';
  }

  @override
  String filmSoldBy(String name) {
    return 'sold by $name';
  }

  @override
  String get filmTabTeam => 'Team';

  @override
  String filmTeamTotals(
    String metres,
    String sales,
    String paid,
    String margin,
  ) {
    return '$metres m · $sales sales · paid $paid · margin $margin';
  }

  @override
  String filmTeamPlan(String done, String plan) {
    return 'Plan: $done% of $plan m';
  }

  @override
  String get filmTeamNoPlan => 'No plan set for the month';

  @override
  String filmTeamPot(String pct, String pot) {
    return 'Pot: $pct% of margin = $pot';
  }

  @override
  String filmTeamShare(String share, String bonus) {
    return 'share $share% · bonus $bonus';
  }

  @override
  String get filmTeamEmpty => 'No sales this month';

  @override
  String get filmTeamHint =>
      'The bonus is counted on margin — only money paid, in the month it was paid.';

  @override
  String get filmTeamSettings => 'Plan and bonus';

  @override
  String get filmTeamPlanM => 'Plan for the month, m';

  @override
  String get filmTeamPct => 'Pot when the plan is met, %';

  @override
  String get filmTeamPctBelow => 'Pot when the plan is missed, %';

  @override
  String get filmTeamSave => 'Save';

  @override
  String get filmArrival => 'When it arrives';

  @override
  String get filmArrivalHere => 'Already in stock';

  @override
  String get filmArrivalTomorrow => 'Tomorrow';

  @override
  String get filmArrivalTwo => 'In 2 days';

  @override
  String get filmArrivalThree => '3 days';

  @override
  String get filmArrivalWeek => 'A week';

  @override
  String get filmArrivalPick => 'Date…';

  @override
  String filmArrivesOn(String day) {
    return 'Arrives: $day';
  }

  @override
  String get filmArrivalOrder => 'Place';

  @override
  String filmComing(String metres, String day) {
    return 'on its way $metres m · arrives $day';
  }

  @override
  String filmComingLate(String metres, String days) {
    return 'on its way $metres m · $days d late';
  }

  @override
  String get filmComingArrived => 'Arrived';

  @override
  String get filmComingMove => 'Another date';

  @override
  String get filmComingDrop => 'Won\'t come';

  @override
  String get filmComingDropReason => 'Why it won\'t come';

  @override
  String get filmComingMetres => 'Metres that came';

  @override
  String get filmOnShelf => 'In stock';

  @override
  String get filmOnWay => 'On its way';

  @override
  String filmOnlyHave(String metres) {
    return 'only $metres m in stock';
  }

  @override
  String filmLeft(String metres) {
    return '$metres m left';
  }

  @override
  String filmLeftLow(String metres) {
    return '$metres m left — low';
  }

  @override
  String filmTakeAll(String metres) {
    return 'Take all $metres m';
  }

  @override
  String filmMoreComing(String metres, String day) {
    return '+$metres m on its way, arrives $day';
  }

  @override
  String get filmDeliveryPayer => 'Who paid';

  @override
  String get filmPayerCash => 'Film cash';

  @override
  String get filmPayerEmployee => 'Employee, own money';

  @override
  String get filmPayerUnpaid => 'Not paid yet';

  @override
  String get filmPaidBy => 'Paid out of pocket by';

  @override
  String get filmPaidCash => 'from the cash';

  @override
  String filmPaidByBack(String who) {
    return 'paid by $who, given back';
  }

  @override
  String filmPaidByOwed(String who) {
    return 'paid by $who — to give back';
  }

  @override
  String get filmCarrierPaid => 'carrier paid';

  @override
  String get filmCarrierOwed => 'carrier not paid';

  @override
  String get filmPaidSupplier => 'on the supplier';

  @override
  String get filmTabCash => 'Cash';

  @override
  String filmSettleBy(String how) {
    return 'Paid: $how';
  }

  @override
  String get filmGaveBack => 'Gave back';

  @override
  String get filmPaidCarrier => 'Paid';

  @override
  String get filmCashToday => 'Today';

  @override
  String get filmCashMonth => 'Month';

  @override
  String get filmCashIn => 'In';

  @override
  String get filmCashOut => 'Out';

  @override
  String get filmCashNothing => '—';

  @override
  String get filmCashTotal => 'Total';

  @override
  String get filmCashBalance => 'Balance';

  @override
  String filmCashLogistics(String sum) {
    return 'Logistics in the period: $sum — not in the bonus';
  }

  @override
  String filmCashLogisticsPerM(String sum, String per) {
    return 'Logistics in the period: $sum (≈ $per a metre) — not in the bonus';
  }

  @override
  String get filmOwedEmployees => 'Owed to employees';

  @override
  String get filmOwedCarriers => 'Owed to carriers';

  @override
  String get filmOwedSuppliers => 'Owed to suppliers';

  @override
  String get filmPaidToSupplier => 'Paid';

  @override
  String get filmSupplierPay => 'Paying the supplier';

  @override
  String get filmSupplierPaidNow => 'Paid';

  @override
  String get filmSupplierOnCredit => 'On credit';

  @override
  String get filmSupplierOwedNote => 'owed to the supplier';

  @override
  String filmCashChartA11y(String incoming, String outgoing) {
    return 'In $incoming, out $outgoing';
  }

  @override
  String filmCashVersus(String arrow, String pct) {
    return '$arrow $pct% on the period before';
  }

  @override
  String filmPayFromCash(String how) {
    return 'From the film cash: $how';
  }

  @override
  String get filmPayElsewhere => 'Not from the film cash';

  @override
  String get filmToday => 'Today';

  @override
  String get filmYesterday => 'Yesterday';

  @override
  String get filmHistoryAll => 'All';

  @override
  String get filmHistoryReceipts => 'Receipts';

  @override
  String get filmHistorySales => 'Sales';

  @override
  String get filmHistoryShop => 'To the shop';

  @override
  String get filmHistoryWriteOffs => 'Write-offs';

  @override
  String filmAfter(String metres) {
    return 'then $metres m';
  }

  @override
  String filmReorderBanner(int count) {
    return 'Time to order — films running low: $count';
  }

  @override
  String get filmReorderOpen => 'Order';

  @override
  String get filmReorderTitle => 'Order film';

  @override
  String filmReorderLeft(String metres) {
    return '$metres m left';
  }

  @override
  String filmReorderTotal(String sum, String day) {
    return 'Total $sum · arrives $day';
  }

  @override
  String filmReorderSave(int count) {
    return 'Place ($count)';
  }

  @override
  String filmDebtors(int count, String sum) {
    return 'Owing: $count · $sum';
  }

  @override
  String get filmRemind => 'Remind in WhatsApp';

  @override
  String filmRemindText(String name, String sum) {
    return 'Hello, $name! A reminder about the film payment: $sum left. Thank you!';
  }

  @override
  String filmDebtDays(int days) {
    return 'owing $days d';
  }

  @override
  String get filmReportTop => 'What sold this month';

  @override
  String filmReportTotals(String metres, String amount, String margin) {
    return '$metres m · takings $amount · margin $margin';
  }

  @override
  String filmReportMarginM(String sum) {
    return 'margin $sum/m';
  }

  @override
  String filmReportIdle(int days) {
    return 'Unmoved for over $days d';
  }

  @override
  String filmReportIdleDays(int days) {
    return '$days d unmoved';
  }

  @override
  String filmReportFrozen(String sum) {
    return '$sum tied up';
  }

  @override
  String get filmReceipt => 'Receipt';

  @override
  String get filmReceiptDate => 'Date';

  @override
  String get filmReceiptCustomer => 'Customer';

  @override
  String get filmReceiptFilm => 'Film';

  @override
  String get filmReceiptMetres => 'Metres';

  @override
  String get filmReceiptPrice => 'Price a metre';

  @override
  String get filmReceiptAmount => 'Amount';

  @override
  String get filmReceiptTotal => 'Total';

  @override
  String get filmReceiptPaid => 'Paid';

  @override
  String get filmReceiptDebt => 'Owing';

  @override
  String get filmHold => 'Put by';

  @override
  String get filmHoldRelease => 'Release';

  @override
  String get filmHoldUntil => 'Until';

  @override
  String filmHeldFor(String metres, String customer, String day) {
    return '$metres m put by for $customer until $day';
  }

  @override
  String facadePricesUnsoldMillings(int count) {
    return 'Millings with no price: $count';
  }

  @override
  String facadePricesShowUnsold(int count) {
    return 'Not sold: $count — show';
  }

  @override
  String get facadePricesHideUnsold => 'Hide the unsold';

  @override
  String get mdfGroupSales => 'Sales';

  @override
  String get mdfGroupShop => 'Shop floor';

  @override
  String get mdfGroupStock => 'Stock and buying';

  @override
  String get mdfGroupSettings => 'Lists and prices';

  @override
  String get filmDriver => 'Driver';

  @override
  String get filmDriverPhone => 'Driver\'s phone';

  @override
  String get filmFree => 'Free';

  @override
  String get filmHeld => 'Put by';

  @override
  String get filmReceiptPayment => 'Payment';

  @override
  String filmReceiptServedBy(String name) {
    return 'Seller (responsible): $name';
  }

  @override
  String get filmReceiptThanks => 'Thank you for choosing us!';

  @override
  String get filmReceiptWish =>
      'A fine choice — may your facades bring you joy for years. We look forward to seeing you again!';

  @override
  String filmReceiptCode(String code) {
    return 'code $code';
  }

  @override
  String filmReceiptThickness(String mm) {
    return '$mm mm';
  }

  @override
  String filmReceiptPhone(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get filmReceiptSignSold => 'Sold by';

  @override
  String get filmReceiptSignGot => 'Received by';

  @override
  String get facadePricesAddVariant => 'Variant';

  @override
  String get facadePricesVariant => 'Milling variant';

  @override
  String get facadePricesVariantHint =>
      'Priced as its kind. In an order it shows as «kind variant».';

  @override
  String get filmIssuedBy => 'Handed out by';

  @override
  String filmReceiptIssuedBy(String name) {
    return 'Handed out by: $name';
  }

  @override
  String get filmReceiptSignIssued => 'Handed out';

  @override
  String filmHeldShort(String metres) {
    return '$metres m put by';
  }

  @override
  String filmOnWayShort(String metres) {
    return '$metres m on its way';
  }

  @override
  String get filmReceivePick => 'Receipt — which film?';

  @override
  String searchSectionFilms(int count) {
    return 'Film ($count)';
  }

  @override
  String searchSectionFilmCustomers(int count) {
    return 'Film customers ($count)';
  }

  @override
  String filmDebtLine(String sum) {
    return 'owes $sum ₸';
  }

  @override
  String get filmTeamSold => 'Sold';

  @override
  String get filmTeamPaid => 'Paid';

  @override
  String get filmTeamMargin => 'Margin';

  @override
  String get filmTeamPotLabel => 'Pot';

  @override
  String filmTeamPotNote(String pct) {
    return '$pct% of margin';
  }

  @override
  String get filmTeamVsLastMonth => 'vs last month';

  @override
  String filmTeamMarginShare(String pct) {
    return '$pct% of what was paid';
  }

  @override
  String get filmTeamSellers => 'Sellers';

  @override
  String filmTeamSellerLine(String name, String sales, String metres) {
    return '$name · $sales sales · $metres m';
  }

  @override
  String filmTeamBonus(String sum) {
    return 'bonus $sum';
  }

  @override
  String filmTeamShareLine(String share, String margin, String paid) {
    return 'share $share% · margin $margin · paid $paid';
  }

  @override
  String get filmReportMarginLegend =>
      'Green — a good margin, amber — under 300 ₸ a metre, red — sold under cost.';

  @override
  String get filmCashWeek => 'Week';

  @override
  String filmCashSales(int count) {
    return '$count sales';
  }

  @override
  String filmCashSpent(int count) {
    return '$count paid out';
  }

  @override
  String get filmCashWhere => 'Where the money is';

  @override
  String get filmCashMoves => 'Movements';

  @override
  String filmCustomersAll(int count) {
    return 'All $count';
  }

  @override
  String filmCustomersRegular(int count) {
    return '⭐ Regular $count';
  }

  @override
  String filmCustomersAsleep(int count) {
    return '😴 Gone quiet $count';
  }

  @override
  String get filmCustomersByMonth => 'This month';

  @override
  String get filmCustomersByAll => 'All time';

  @override
  String get filmCustomersLegend =>
      'Top — who buys most. Stripe: green — paid up, red — owes, grey — gone quiet.';

  @override
  String get filmRegularBadge => '⭐ regular';

  @override
  String get filmNoDebt => 'nothing owed';

  @override
  String get filmCall => 'Call';

  @override
  String get filmWrite => 'Write in WhatsApp';

  @override
  String filmCustomerLast(String day) {
    return 'last bought $day';
  }

  @override
  String get filmCustomerBought => 'Bought in all';

  @override
  String get filmCustomerSum => 'For';

  @override
  String get filmCustomerDebt => 'Owes';

  @override
  String get filmCustomerMonth => 'This month';

  @override
  String get filmCustomerFavourite => 'Takes most';

  @override
  String get filmCustomerTerms => 'Terms: retail / trade, discount';

  @override
  String get filmCustomerHistory => 'Purchases';

  @override
  String filmCashShould(String sum) {
    return 'Cash in the drawer should be: $sum';
  }

  @override
  String filmCashClosed(String sum, String who) {
    return 'Day closed: counted $sum · $who';
  }

  @override
  String filmCashGap(String sum, String why) {
    return 'off by $sum: $why';
  }

  @override
  String get filmCashCloseDay => 'Close the day';

  @override
  String get filmCashRecount => 'Count again';

  @override
  String get filmCashCounted => 'Cash counted';

  @override
  String filmCashShort(String sum) {
    return 'Short by $sum';
  }

  @override
  String filmCashOver(String sum) {
    return 'Over by $sum';
  }

  @override
  String get filmCashMatches => 'It matches';

  @override
  String get filmCashWhy => 'Why it is off';

  @override
  String get filmSupSoldMonth => 'Sold this month';

  @override
  String get filmSupSoldAll => 'Sold in all';

  @override
  String get filmSupOnHand => 'On the shelf';

  @override
  String get filmSupComing => 'On its way';

  @override
  String get filmSupReorder => 'To order';

  @override
  String filmSupM(String metres) {
    return '$metres m';
  }

  @override
  String filmSupComingRolls(int count) {
    return 'rolls: $count';
  }

  @override
  String filmSupReorderFilms(int count) {
    return 'films: $count';
  }

  @override
  String filmSupShare(String share) {
    return '$share% of sales';
  }

  @override
  String filmSupRevenue(String sum) {
    return 'revenue $sum';
  }

  @override
  String filmSupShelf(String metres) {
    return '$metres m on the shelf';
  }

  @override
  String filmSupLead(int days, int promised) {
    return 'brings in $days d (promised $promised)';
  }

  @override
  String filmSupChipReorder(int count) {
    return 'To order: $count';
  }

  @override
  String filmSupChipComing(String metres, String day) {
    return '$metres m on its way · $day';
  }

  @override
  String filmSupChipComingLate(String metres, int days) {
    return '$metres m on its way · $days d late';
  }

  @override
  String filmSupChipLate(int days) {
    return 'Late by $days d on average';
  }

  @override
  String filmSupChipIdle(int count, String metres) {
    return 'Lying idle: $count · $metres m';
  }

  @override
  String get filmSupChipOk => 'All is well';

  @override
  String get filmSupOrder => 'Order by WhatsApp';

  @override
  String filmSupOrderText(String list) {
    return 'Hello! We need film:\n$list\nWhen can you bring it?';
  }

  @override
  String filmSupOrderLine(String title, String metres) {
    return '— $title — $metres m';
  }

  @override
  String get filmSupLegend =>
      'Top — whose film sells best. A film of two sources is shared by what each brought.';

  @override
  String get filmSrcOrderUntil => 'Takes orders until (e.g. 16:00)';

  @override
  String get filmReceiveAddFilm => 'Another film';

  @override
  String filmReceiveAddLow(int count) {
    return 'Add all that ran low ($count)';
  }

  @override
  String get filmReceiveForWhom => 'For whom';

  @override
  String get filmReceiveForShelf => 'For the shelf';

  @override
  String filmReceiveForCustomer(String name) {
    return 'For: $name';
  }

  @override
  String get filmReceiveRemove => 'Remove';

  @override
  String filmReceiveSum(String sum) {
    return 'comes to $sum';
  }

  @override
  String filmReceiveSumWithDelivery(String sum, String perM) {
    return 'comes to $sum · $perM a metre delivered';
  }

  @override
  String filmReceiveMany(int count) {
    return 'Delivery · films: $count';
  }

  @override
  String filmReceiveTotal(int count, String metres, String sum) {
    return 'In all: $count films · $metres m · $sum delivered';
  }

  @override
  String get filmPickSearch => 'Maker, colour or code';

  @override
  String get filmPickNone => 'Nothing found';

  @override
  String filmPickFree(String metres) {
    return '$metres m';
  }

  @override
  String get filmPickReorder => 'to order';

  @override
  String get filmOrdersTitle => 'To order';

  @override
  String filmOrdersSendAll(int count) {
    return 'Send to all ($count)';
  }

  @override
  String filmOrdersSummary(int count, String metres, int suppliers) {
    return 'Films: $count · $metres m · suppliers: $suppliers';
  }

  @override
  String get filmOrdersAdd => 'Add a film';

  @override
  String get filmOrdersAddSave => 'Add to the order';

  @override
  String get filmOrdersEmpty =>
      'Nothing to order yet. Add a film when a customer wants more than there is — films that run low show up here by themselves.';

  @override
  String get filmOrdersLegend =>
      'Red — ran out, blue — for a customer, grey — for the shelf. Tap to change the metres; × — remove.';

  @override
  String filmOrderLine(int n, String title, String metres) {
    return '$n. $title — $metres m';
  }

  @override
  String filmOrderText(String date, String lines, int count, String metres) {
    return 'Hello! Order for $date:\n$lines\nIn all: $count items, $metres m.\nPlease confirm what you have and when you will bring it.';
  }

  @override
  String filmOrderCopied(String name) {
    return 'The order for «$name» is copied — paste it into a message.';
  }

  @override
  String get filmOrdersNoSupplier => 'No supplier named';

  @override
  String filmOrdersGroupTotal(int count, String metres) {
    return '$count films · $metres m';
  }

  @override
  String filmOrdersUntil(String time) {
    return 'takes orders until $time';
  }

  @override
  String get filmOrdersSend => 'Send by WhatsApp';

  @override
  String get filmOrdersCopy => 'Copy the order';

  @override
  String filmOrdersSentAt(String time) {
    return 'Sent at $time · waiting for an answer';
  }

  @override
  String get filmOrdersConfirmed => 'Confirmed — enter the delivery';

  @override
  String filmOrdersForShelf(String metres) {
    return 'shelf $metres m';
  }

  @override
  String filmOrdersForCustomer(String name, String metres) {
    return '$name $metres m';
  }

  @override
  String filmOrdersRanOut(String metres) {
    return 'ran out · $metres m';
  }

  @override
  String filmOrdersButton(int count) {
    return 'To order · $count';
  }

  @override
  String filmOrdersButtonWaiting(int count, int waiting) {
    return 'To order · $count · waiting: $waiting';
  }

  @override
  String get mdfSumTitle => 'MDF summary';

  @override
  String get mdfSumWeek => 'Week';

  @override
  String get mdfSumShare => 'Copy the summary';

  @override
  String get mdfSumCopied => 'The summary is copied — paste it into WhatsApp.';

  @override
  String mdfSumUp(int percent) {
    return '▲ $percent% on the last';
  }

  @override
  String mdfSumDown(int percent) {
    return '▼ $percent% on the last';
  }

  @override
  String get mdfSumAvg => 'Average order';

  @override
  String mdfSumAvgNote(String area, String rate) {
    return '$area m² · $rate/m²';
  }

  @override
  String get mdfSumCustomers => 'Customers';

  @override
  String mdfSumNewCustomers(int count) {
    return 'new: $count';
  }

  @override
  String get mdfSumPlan => 'The month: plan and forecast';

  @override
  String get mdfSumPlanDone => 'Done this month';

  @override
  String get mdfSumGoal => 'Goal';

  @override
  String mdfSumGoalOf(String goal, int percent) {
    return '$goal m² · $percent%';
  }

  @override
  String get mdfSumGoalNone => 'No goal for the month — tap ✎ to set one.';

  @override
  String get mdfSumGoalSet => 'The month’s goal';

  @override
  String get mdfSumGoalM2 => 'm² this month';

  @override
  String mdfSumForecast(int days) {
    return 'At this pace by the month’s end ($days d left)';
  }

  @override
  String get mdfSumShop => 'The shop’s load';

  @override
  String get mdfSumInWork => 'In work';

  @override
  String mdfSumInWorkValue(String area, int count) {
    return '$area m² · $count orders';
  }

  @override
  String get mdfSumPace => 'The shop finishes';

  @override
  String mdfSumPaceValue(String area) {
    return '$area m² a day';
  }

  @override
  String get mdfSumPaceUnknown =>
      'The shop’s pace is not known yet: a few finished orders are needed.';

  @override
  String get mdfSumNewReady => 'A new order would be ready';

  @override
  String mdfSumNewReadyValue(int days, String day) {
    return 'in $days d · $day';
  }

  @override
  String get mdfSumOverdueNow => 'Overdue now';

  @override
  String get mdfSumTop => 'Who orders most';

  @override
  String mdfSumTopValue(int count, String area) {
    return '$count orders · $area m²';
  }

  @override
  String get mdfSumMaker => 'furniture maker';

  @override
  String get mdfSumNew => 'new';

  @override
  String get mdfSumNothing => 'Nothing in this period.';

  @override
  String get mdfSumAsleep => 'Gone quiet — time to get in touch';

  @override
  String get mdfSumAsleepNone => 'Every customer orders in his usual rhythm.';

  @override
  String mdfSumAsleepRhythm(int rhythm, int days) {
    return 'usually every $rhythm d · none for $days d';
  }

  @override
  String mdfSumAsleepOnce(int days) {
    return 'one order · none for $days d';
  }

  @override
  String get mdfSumGone => 'gone';

  @override
  String get mdfSumDozing => 'dozing';

  @override
  String mdfSumWakeText(String name) {
    return 'Hello, $name! It has been a while — how are your orders? We can take facades in now, the lead times are good.';
  }

  @override
  String mdfSumMore(int count) {
    return 'and $count more';
  }

  @override
  String get mdfSumFilms => 'What is ordered · is there film enough';

  @override
  String mdfSumFilmShort(String metres) {
    return '$metres m short';
  }

  @override
  String get mdfSumFilmEnough => 'enough';

  @override
  String get mdfSumToOrder => 'To order';

  @override
  String mdfSumOrdered(String decor) {
    return '«$decor» is on the order list.';
  }

  @override
  String get mdfSumDeadlines => 'Deadlines and quality';

  @override
  String mdfSumOnTime(int count) {
    return 'Handed over on time (of $count)';
  }

  @override
  String get mdfSumNoHandedOver => 'Nothing handed over in the period.';

  @override
  String get mdfSumLateAvg => 'Late on average';

  @override
  String mdfSumDays(String days) {
    return '$days d';
  }

  @override
  String get mdfSumRework => 'Reworks and warranty';

  @override
  String mdfSumReworkValue(int count, String area, int percent) {
    return '$count · $area m² · $percent%';
  }

  @override
  String mdfSumReasons(String list) {
    return 'Why they came back: $list';
  }

  @override
  String get mdfSumDebts => 'Debts by age';

  @override
  String get mdfSumDebtWeek => 'up to 7 days';

  @override
  String get mdfSumDebtMonth => '8–30 days';

  @override
  String get mdfSumDebtOlder => 'over 30 days';

  @override
  String mdfSumDebtor(String name, int days) {
    return '$name · $days d';
  }

  @override
  String get mdfSumManagers => 'Who took the orders';

  @override
  String mdfSumAlertOverdue(int count) {
    return '$count overdue';
  }

  @override
  String mdfSumAlertAtRisk(int count) {
    return '$count will miss their date';
  }

  @override
  String mdfSumAlertDebt(String sum) {
    return 'Owed over a month: $sum';
  }

  @override
  String mdfSumAlertFilm(int count) {
    return 'Film short: $count';
  }

  @override
  String get mdfSumStages => 'Where the orders are now';

  @override
  String get mdfSumIntake => 'Taken in by day';

  @override
  String get mdfSumIntakeMonthly => 'Taken in by month';

  @override
  String get mdfSumIntakeHint => 'Tap a bar for that day\'s orders.';

  @override
  String mdfSumIntakeDay(String day, int count, String area, String sum) {
    return '$day: $count orders · $area m² · $sum';
  }

  @override
  String mdfSumManagerValue(int count, String area, String sum) {
    return '$count · $area m² · $sum';
  }

  @override
  String mdfSumTextHead(String since, String until) {
    return 'MDF summary $since — $until';
  }

  @override
  String mdfSumTextOrders(int count, String area, String sum) {
    return 'Orders: $count · $area m² · $sum';
  }

  @override
  String mdfSumTextMoney(String paid, String debt) {
    return 'Received: $paid · owed: $debt';
  }

  @override
  String mdfSumTextChange(String percent) {
    return 'Volume on the last period: $percent%';
  }

  @override
  String mdfSumTextForecast(String area) {
    return 'Month forecast: $area m²';
  }

  @override
  String mdfSumTextAsleep(int count) {
    return 'Customers gone quiet: $count';
  }

  @override
  String get mdfOrdersSummary => 'Summary';

  @override
  String get mdfPressOpen => 'Press layout';

  @override
  String mdfPressFilm(String metres, int loads) {
    return 'Film $metres m · $loads loads';
  }

  @override
  String get mdfPressCorrected => 'corrected by hand';

  @override
  String mdfPressSaved(String metres) {
    return 'smart layout −$metres m';
  }

  @override
  String mdfPressTooBig(int count) {
    return 'too big for the press: $count';
  }

  @override
  String pressSmartSaved(String plain, String saved) {
    return 'Smart layout: the plain one would take $plain m — $saved m saved.';
  }

  @override
  String get pressEdit => 'Edit the layout';

  @override
  String get pressEditReset => 'Lay out again';

  @override
  String get pressEditSave => 'Keep my layout';

  @override
  String pressEditTotal(String metres, String auto) {
    return 'Total $metres m · the system laid out $auto m';
  }

  @override
  String get pressEditClash =>
      'Red parts lie too close to each other or off the table — move them.';

  @override
  String get pressEditHint =>
      'Press a part and drag it. Let go and it lines up by itself.';

  @override
  String pressEditPart(int pos, String size) {
    return 'Position $pos · $size';
  }

  @override
  String get pressEditRotate => 'Turn';

  @override
  String pressEditMoveTo(int count) {
    return 'To load $count';
  }

  @override
  String get pressEditMoveNew => 'To a new load';

  @override
  String get pressEditSectionAuto => 'Section: auto';

  @override
  String pressEditSection(String metres) {
    return 'Section $metres m';
  }

  @override
  String get pressManual => 'Own layout — the parts were placed by hand.';

  @override
  String get pressApprove => 'Layout checked — start';

  @override
  String pressApproved(String by, String at) {
    return 'Layout checked: $by, $at';
  }

  @override
  String get pressUnapprove => 'Take the mark off';

  @override
  String pressShortAdded(String films) {
    return 'Film is short, added to the order list: $films m';
  }

  @override
  String pressPrintApproved(String by, String at) {
    return 'Layout approved: $by, $at';
  }

  @override
  String get pressPrintSigns => 'Operator ____________   Foreman ____________';

  @override
  String get mdfPressManual => 'own layout';

  @override
  String get mdfPressApproved => 'layout checked';

  @override
  String filmFilterAll(int n) {
    return 'All · $n';
  }

  @override
  String filmFilterHave(int n) {
    return 'In stock · $n';
  }

  @override
  String filmFilterOnWay(int n) {
    return 'On the way · $n';
  }

  @override
  String filmFilterNone(int n) {
    return 'Out of stock · $n';
  }

  @override
  String get filmStockSearch => 'Find a film';

  @override
  String filmComingRolls(int count, String metres, String day) {
    return '$count rolls on the way · $metres m · due $day';
  }

  @override
  String filmDaysLeft(int days) {
    return 'lasts ≈ $days d';
  }

  @override
  String get filmWantShort => 'Order';

  @override
  String get filmM => 'm';

  @override
  String get filmReceiveLineSum => 'Sum';

  @override
  String filmReceivePerMWithDelivery(String perM) {
    return 'a metre with delivery $perM';
  }

  @override
  String filmPriceUp(String old, String since, String change) {
    return 'Dearer than last time: it was $old/m$since · $change';
  }

  @override
  String filmPriceDown(String old, String since, String change) {
    return 'Cheaper than last time: it was $old/m$since · $change';
  }

  @override
  String get filmReceiveWhere => 'Where it goes';

  @override
  String filmReceiveIntoProduction(String order, String name, String due) {
    return 'Into production · №$order · $name $due';
  }

  @override
  String filmReceiveToCustomer(String name) {
    return 'Sale · $name';
  }

  @override
  String get filmReceiveToShelf => 'To the shelf · free to sell';

  @override
  String filmReceiveShort(String metres) {
    return '$metres m short — they stay under «Waiting for».';
  }

  @override
  String get filmReceiveShortToList => 'To the order list';

  @override
  String get filmReceiveShortListed => 'on the order list';

  @override
  String get filmReceiveToProduction => 'Into production';

  @override
  String get filmReceiveToSale => 'Sale to a customer';

  @override
  String get filmReceiveNoOrders =>
      'No facade orders lack this film right now.';

  @override
  String filmReceiveOrderLine(
    String order,
    String name,
    String metres,
    String due,
  ) {
    return '№$order · $name · needs $metres m · due $due';
  }

  @override
  String filmReceiveOrdersWait(int count) {
    return 'facade orders waiting: $count';
  }

  @override
  String filmReceiveFilmTotal(int count, String metres) {
    return 'Film · $count rolls · $metres m';
  }

  @override
  String get filmReceiveGrand => 'Total bought';

  @override
  String filmReceivePerM(String films) {
    return 'A metre with delivery: $films';
  }

  @override
  String filmReceiveSumProduction(String metres) {
    return 'into production $metres m';
  }

  @override
  String filmReceiveSumSale(String metres) {
    return 'sale $metres m';
  }

  @override
  String filmReceiveSumShelf(String metres) {
    return 'shelf $metres m';
  }

  @override
  String pressFill(int percent, String waste) {
    return '$percent% full · $waste m² waste';
  }

  @override
  String get pressPositionsHint =>
      'Point at a part or tap a position — it lights up on every load.';

  @override
  String pressPositionInfo(int pos, String size, int count, String loads) {
    return 'Position $pos · $size · $count in all · on loads $loads';
  }

  @override
  String pressPositionCount(int count) {
    return '$count pcs';
  }

  @override
  String mdfPressCheckedBy(String by) {
    return '✓ layout checked by $by';
  }

  @override
  String get mdfPressNotChecked => 'layout not checked';

  @override
  String get pressPanelTitle => 'Press';

  @override
  String get pressSectionRemove => 'Remove the section';

  @override
  String get pressLevel => 'How hard to look';

  @override
  String get pressLevelFast => 'Fast';

  @override
  String get pressLevelSmart => 'Smart';

  @override
  String get pressLevelMax => 'Maximum';

  @override
  String get pressDirection => 'Laying';

  @override
  String get pressDirectionAny => 'As is best';

  @override
  String get pressDirectionAlong => 'Along';

  @override
  String get pressDirectionAcross => 'Across';

  @override
  String get pressRotate => 'Turn parts';

  @override
  String get pressRotateYes => 'Allowed';

  @override
  String get pressRotateNo => 'Not allowed';

  @override
  String get pressRotateTextured => 'A textured film — never turned.';

  @override
  String get pressKeepForOrder => 'For this order only';

  @override
  String get pressKeepForPress => 'Keep for the press';

  @override
  String get pressKeepForPressHint =>
      '«For the press» changes every new layout.';

  @override
  String get pressTuneReset => 'Back to the press\'s own';

  @override
  String get pressTuneKept => 'Layout kept for this order';

  @override
  String get pressTuneSaved => 'Press settings saved';

  @override
  String pressWas(String metres) {
    return 'Was $metres m';
  }

  @override
  String pressWillBe(String metres) {
    return 'Will be $metres m';
  }

  @override
  String pressSaves(String metres) {
    return 'saves $metres m';
  }

  @override
  String pressCostsMore(String metres) {
    return '$metres m more';
  }

  @override
  String get pressSame => 'the same';

  @override
  String get pressUnitM => 'm';

  @override
  String get pressUnitMm => 'mm';

  @override
  String pressMm(int value) {
    return '$value mm';
  }

  @override
  String get filmSalesToday => 'Today';

  @override
  String get filmSalesWeek => 'Week';

  @override
  String get filmSalesMonth => 'Month';

  @override
  String get filmSalesPeriod => 'Period';

  @override
  String filmSalesAll(int count) {
    return 'All · $count';
  }

  @override
  String filmSalesPaid(int count) {
    return 'Paid · $count';
  }

  @override
  String filmSalesDebt(int count) {
    return 'Owing · $count';
  }

  @override
  String filmSalesWholesale(int count) {
    return 'Trade · $count';
  }

  @override
  String get filmSalesSearch => 'customer, film';

  @override
  String get filmSalesSold => 'Sold';

  @override
  String filmSalesCount(int count) {
    return '$count sales';
  }

  @override
  String get filmSalesMetres => 'Metres';

  @override
  String get filmSalesAmount => 'Revenue';

  @override
  String filmSalesChange(String change) {
    return '$change% on the last';
  }

  @override
  String get filmSalesProfit => 'Profit';

  @override
  String get filmSalesUnpaid => 'Unpaid';

  @override
  String filmSalesDebtors(int count) {
    return 'customers: $count';
  }

  @override
  String filmSalesTodayOn(String day) {
    return 'Today, $day';
  }

  @override
  String filmSalesYesterdayOn(String day) {
    return 'Yesterday, $day';
  }

  @override
  String get filmSalesWholesaleMark => 'trade';

  @override
  String get filmSalesPaidMark => '✓ paid';

  @override
  String filmSalesPartly(String sum) {
    return 'part · owing $sum';
  }

  @override
  String filmSalesPerM(String price) {
    return '$price/m';
  }

  @override
  String filmDebtorsTitle(String sum) {
    return 'Owing · $sum';
  }

  @override
  String get filmDebtorsShowSales => 'Show their sales';

  @override
  String filmDebtorLine(String sum, int days) {
    return '$sum · $days d';
  }

  @override
  String get filmSaleRepeat => 'Again';

  @override
  String filmSaleBelow(String cost, String loss) {
    return 'Below cost: bought at $cost/m — a loss of ≈ $loss';
  }

  @override
  String get filmSaleBelowWhy => 'Why below cost?';

  @override
  String get filmSaleBelowRest => 'end of a roll';

  @override
  String get filmSaleBelowDefect => 'defect';

  @override
  String get filmSaleBelowAgreed => 'agreed';

  @override
  String get filmSaleToOrders => 'To the order list';

  @override
  String filmSaleUsually(String film) {
    return 'usually takes $film';
  }

  @override
  String filmSaleEvery(int days) {
    return 'every $days d';
  }

  @override
  String get filmSaleNoDebt => 'no debt';

  @override
  String filmSaleLikeLast(String films) {
    return 'Like last time: $films';
  }

  @override
  String get filmDebtLimit => 'Debt limit, ₸';

  @override
  String get filmDebtLimitDays => 'Owing no longer, days';

  @override
  String filmLimitDays(int days) {
    return 'up to $days d';
  }

  @override
  String filmSaleOverLimit(String sum, String limit) {
    return 'The debt becomes $sum — over the limit $limit';
  }

  @override
  String filmSaleOverDays(int days, int limit) {
    return 'owing $days d — longer than $limit d';
  }

  @override
  String filmCallTitle(int count) {
    return 'Time to call · $count';
  }

  @override
  String filmCallDebt(String name, String sum, int days) {
    return '$name — owes $sum, $days d';
  }

  @override
  String filmCallRhythm(String name, int every, int idle) {
    return '$name — buys every $every d, none for $idle d';
  }

  @override
  String get filmCustomerAverage => 'Average sale';

  @override
  String get filmCustomerRhythm => 'Buys';

  @override
  String get filmCustomerLimit => 'Debt limit';

  @override
  String get filmStatement => 'Statement';

  @override
  String filmStatementCustomer(String name) {
    return 'Customer: $name';
  }

  @override
  String filmStatementOn(String day) {
    return 'as of $day';
  }

  @override
  String get filmStatementDate => 'Date';

  @override
  String get filmStatementWhat => 'Entry';

  @override
  String get filmStatementSold => 'Sold';

  @override
  String get filmStatementPaid => 'Paid';

  @override
  String get filmStatementBalance => 'Owing';

  @override
  String filmStatementSale(String films) {
    return 'Film: $films';
  }

  @override
  String get filmStatementPayment => 'Payment';

  @override
  String filmStatementOwes(String sum) {
    return 'The customer owes $sum';
  }

  @override
  String get filmStatementSettled => 'Settled, nothing owed.';

  @override
  String get filmStatementSigns =>
      'Seller ____________     Customer ____________';

  @override
  String get mdfMarginTitle => 'Margin';

  @override
  String get mdfMarginRevenue => 'Order total';

  @override
  String get mdfMarginMaterial => 'Material';

  @override
  String get mdfMarginWork => 'Work';

  @override
  String get mdfMarginEstimate =>
      'An estimate at today\'s prices: nothing written off yet';

  @override
  String mdfMarginMissing(String names) {
    return 'No price: $names';
  }

  @override
  String get mdfMarginNotCounted => 'Not counted: power, delivery';

  @override
  String get mdfSumMargin => 'Margin of orders handed over';

  @override
  String mdfSumMarginOrders(String count) {
    return 'Handed over: $count';
  }

  @override
  String mdfSumMarginEstimated(String count) {
    return 'By estimate, nothing written off: $count';
  }

  @override
  String get mdfSumMarginLowest => 'Earned least';

  @override
  String get mdfPaintTitle => 'Paint shop';

  @override
  String get mdfPaintHint => 'What to paint by colour, what is drying';

  @override
  String get mdfPaintDryHours => 'Drying time, hours';

  @override
  String get mdfPaintEmpty => 'Nothing to paint';

  @override
  String mdfPaintSummary(String waiting, String drying, String coming) {
    return 'To paint $waiting · drying $drying · on the way $coming';
  }

  @override
  String mdfPaintDrying(int hours) {
    return 'Drying ($hours h)';
  }

  @override
  String get mdfPaintDry => 'Dry';

  @override
  String mdfPaintLeft(String hours, String minutes, String day, String time) {
    return '$hours h $minutes min left · dry $day at $time';
  }

  @override
  String get mdfPaintMarkPainted => 'Mark painted';

  @override
  String get mdfPaintUndo => 'Not drying';

  @override
  String get mdfPaintByColour => 'To paint, by colour';

  @override
  String get mdfPaintByColourHint =>
      'The biggest colour first: mixed once, the gun cleaned once.';

  @override
  String mdfPaintColourNote(String area, String orders) {
    return '$area · orders: $orders';
  }

  @override
  String get mdfPaintStartDrying => 'Painted — dry';

  @override
  String get mdfPaintPopular => 'Most painted colours, 90 days';

  @override
  String get mdfPaintSave => 'Save';

  @override
  String get mdfTagClientPaint => 'Customer\'s paint';

  @override
  String get mdfTagClientParts => 'Customer\'s LMDF';

  @override
  String get mdfClientPaintBrought => 'Paint brought';

  @override
  String get mdfClientPaintWhat => 'What was brought (e.g. 2 cans × 3 l)';

  @override
  String get mdfClientPaintHere => 'here';

  @override
  String get mdfClientPaintWaiting => 'Waiting for paint';

  @override
  String get mdfPaintSettings => 'Paint settings';

  @override
  String get mdfPaintDiscount => 'Discount for own paint, ₸/m²';

  @override
  String get mdfPaintDiscountHint =>
      'Taken off the m² price when «Customer\'s paint» is on';

  @override
  String get mdfPaintComing => 'On their way to you';

  @override
  String mdfPaintNowAt(String stage) {
    return 'now: $stage';
  }

  @override
  String get mdfPaintTwoSided => '2 sides';

  @override
  String get mdfTagClientFilm => 'Customer\'s film';

  @override
  String get mdfClientShort => 'customer\'s';

  @override
  String get mdfKpiOverdue => 'Overdue';

  @override
  String get mdfKpiDueSoon => 'Due today or tomorrow';

  @override
  String get mdfKpiReady => 'Ready to hand over';

  @override
  String get mdfKpiDebt => 'Customers owe';

  @override
  String mdfKpiDebtors(String count) {
    return 'customers: $count';
  }

  @override
  String get mdfSectionOverdue => 'Overdue';

  @override
  String get mdfSectionSoon => 'Due soon';

  @override
  String get mdfSectionShop => 'In the shop';

  @override
  String get mdfSectionReady => 'Ready — waiting for the customer';

  @override
  String get mdfSectionDraft => 'Drafts';

  @override
  String get mdfSectionClosed => 'Handed over';

  @override
  String mdfRowNowAt(String stage) {
    return 'now: $stage';
  }

  @override
  String mdfRowLate(String days) {
    return '$days d late';
  }

  @override
  String mdfRowDaysLeft(String days) {
    return 'in $days d';
  }

  @override
  String get mdfRowToday => 'due today';

  @override
  String mdfRowReadyFor(String days) {
    return 'ready $days d';
  }

  @override
  String get mdfRowPaid => 'paid';

  @override
  String get mdfFilterDueSoon => 'Due soon';

  @override
  String get filmCashOpening => 'Cash at the start';

  @override
  String filmCashOpeningNote(String day) {
    return 'counted $day';
  }

  @override
  String get filmCashQuiet => 'No money moved in this period.';

  @override
  String get filmFigOnHand => 'On the shelf';

  @override
  String get filmFigOnWay => 'On its way';

  @override
  String filmFigRolls(int count) {
    return 'deliveries: $count';
  }

  @override
  String get filmFigRunsOut => 'Running out';

  @override
  String filmFigRunsOutNote(int days) {
    return 'under $days days left';
  }

  @override
  String get filmFigToOrder => 'To order';

  @override
  String filmFigToOrderNote(String metres) {
    return '≈ $metres m';
  }

  @override
  String filmStockBought(String price) {
    return 'bought at $price/m';
  }

  @override
  String filmStockOrder(String metres) {
    return 'order $metres m';
  }

  @override
  String get filmSalesAverage => 'Average sale';

  @override
  String get filmSalesQuietToday => 'No sales yet today';

  @override
  String filmSalesYesterdayWas(String count, String metres) {
    return 'yesterday: $count, $metres m';
  }

  @override
  String get filmSalesByDay => 'Sold by day, m';

  @override
  String filmSalesChartA11y(String metres) {
    return 'Metres sold by day; $metres m in all';
  }

  @override
  String get filmSalesTopFilms => 'Films that sold most';

  @override
  String get filmSalesTopCustomers => 'Who bought most';

  @override
  String get filmSupOwed => 'We owe';

  @override
  String filmSupOwedTo(int count) {
    return 'suppliers: $count';
  }

  @override
  String filmSupChipOwed(String amount) {
    return 'we owe $amount';
  }

  @override
  String filmSupChipOnTime(int onTime, int rolls) {
    return 'on time $onTime of $rolls';
  }

  @override
  String filmSupChipPrice(String change) {
    return 'price $change%';
  }

  @override
  String filmTeamPlanNeed(int days, String metres) {
    return '$days days left — $metres m a day';
  }

  @override
  String get filmTeamNoPlanHint =>
      'Set the month\'s plan: the bonus share depends on it.';

  @override
  String get filmTeamSetPlan => 'Set the plan';

  @override
  String filmTeamMarginM(String margin) {
    return '$margin/m';
  }

  @override
  String filmTeamOwed(String amount) {
    return 'his customers owe $amount';
  }

  @override
  String filmSaleMargin(
    String cost,
    String price,
    String perM,
    String total,
    String pct,
  ) {
    return 'bought $cost → sold $price: +$perM/m · $total ($pct%)';
  }

  @override
  String get filmSaleLikeLastShort => 'As last time';

  @override
  String get mdfDictAddGroup => 'Add a group';

  @override
  String mdfDictAddVariant(String group) {
    return 'A variant of $group';
  }

  @override
  String get filmSupplierByInvoice => 'By invoice';

  @override
  String get filmInvoiceNo => 'Invoice no.';

  @override
  String filmInvoiceOn(String day) {
    return 'dated $day';
  }

  @override
  String filmInvoiceDue(String day) {
    return 'pay by $day';
  }

  @override
  String get filmInvoiceNoDue => 'No due date';

  @override
  String get filmInvoiceHint => 'Owed until «Оплатили»; overdue past its day.';

  @override
  String filmByInvoiceNo(String no) {
    return 'invoice № $no';
  }

  @override
  String get filmFromDeptCash => 'from the cash';

  @override
  String get filmSupplierFromDept => 'Out of the film department\'s cash';

  @override
  String get filmInvoice => 'Invoice';

  @override
  String filmInvoiceTitle(String no, String day) {
    return 'Invoice No. $no of $day';
  }

  @override
  String get filmInvoiceBeneficiary => 'Beneficiary';

  @override
  String get filmInvoiceSupplier => 'Supplier:';

  @override
  String get filmInvoiceBuyer => 'Buyer:';

  @override
  String get filmInvoiceNumber => 'No.';

  @override
  String get filmInvoiceItem => 'Item';

  @override
  String get filmInvoiceQty => 'Qty';

  @override
  String get filmInvoiceUnit => 'Unit';

  @override
  String get filmInvoiceMetre => 'm';

  @override
  String filmInvoiceSummary(int count, String sum) {
    return 'Items in total: $count, for $sum';
  }

  @override
  String filmInvoicePayBy(String day) {
    return 'Pay by $day';
  }

  @override
  String get filmInvoiceDueHelp => 'Pay by';

  @override
  String get filmInvoiceSigned => 'Issued by';

  @override
  String get filmInvoiceMake => 'Invoice PDF';

  @override
  String get filmInvoiceNoRequisites =>
      'The invoice needs your company\'s requisites — fill them in once, and every invoice after carries them.';

  @override
  String get filmReqTitle => 'Company requisites';

  @override
  String get filmReqFill => 'Fill in requisites';

  @override
  String get filmReqEdit => 'Change requisites';

  @override
  String get filmReqSave => 'Save';

  @override
  String get filmReqName => 'Company name (as in documents)';

  @override
  String get filmReqBin => 'BIN/IIN';

  @override
  String get filmReqAddress => 'Address';

  @override
  String get filmReqPhone => 'Phone';

  @override
  String get filmReqBank => 'Bank';

  @override
  String get filmReqIik => 'IIK (account)';

  @override
  String get filmReqBik => 'BIK';

  @override
  String get filmReqKbe => 'Kbe';

  @override
  String get filmReqDirector => 'Signs (director)';

  @override
  String get mdfPaintSystem => 'Colour system';

  @override
  String get mdfPaintAddSystem => 'Add a colour system';

  @override
  String mdfPaintAddColour(String group) {
    return 'Add a colour to $group';
  }

  @override
  String get mdfPaintNoSystem => 'No system';

  @override
  String get mdfPaintSearch => 'Find a colour: 9016, white…';

  @override
  String get paintStock => 'Paint store';

  @override
  String get paintReceive => 'Paint received';

  @override
  String get paintReceiveSave => 'Take in';

  @override
  String get paintReceiveShort => 'Buy';

  @override
  String get paintColour => 'Colour';

  @override
  String get paintBase => 'What it is (enamel, primer, lacquer…)';

  @override
  String get paintBaseEnamelMatt => 'PU enamel, matt';

  @override
  String get paintBaseEnamelGloss => 'PU enamel, gloss';

  @override
  String get paintBasePrimer => 'Primer';

  @override
  String get paintBaseLacquer => 'Lacquer';

  @override
  String get paintKg => 'Kg';

  @override
  String paintKgShort(String kg) {
    return '$kg kg';
  }

  @override
  String get paintCans => 'In cans';

  @override
  String get paintCanCount => 'Cans';

  @override
  String get paintCanKg => 'Kg a can';

  @override
  String get paintPriceKg => 'Price a kg';

  @override
  String paintPerKg(String price) {
    return '$price/kg';
  }

  @override
  String paintPriceUp(String pct, String was, String who) {
    return '$pct% dearer than last time ($was from $who)';
  }

  @override
  String paintPriceDown(String pct, String was, String who) {
    return '$pct% cheaper than last time ($was from $who)';
  }

  @override
  String paintPriceSame(String was, String who) {
    return 'As last time: $was from $who';
  }

  @override
  String get paintSupplier => 'Supplier';

  @override
  String get paintNewSupplier => 'New supplier';

  @override
  String paintToSupplier(String kg) {
    return 'Paint $kg kg';
  }

  @override
  String paintLanded(String price) {
    return 'A kg with the delivery: $price';
  }

  @override
  String paintDeliveryPerKg(String price) {
    return '+$price a kg';
  }

  @override
  String paintKgPerM2(String kg) {
    return 'Use: $kg kg/m²';
  }

  @override
  String get paintKgPerM2Title => 'Paint used, kg a m²';

  @override
  String get paintKgPerM2Hint =>
      'Primer and every coat together. It says whether the paint is enough for the queue.';

  @override
  String paintNeed(String m2, String need, String have) {
    return 'queue $m2 m² · needs $need kg · $have kg here';
  }

  @override
  String paintShort(String kg) {
    return '$kg kg short';
  }

  @override
  String get paintEnough => 'enough';

  @override
  String paintOnHand(String kg) {
    return '$kg kg';
  }

  @override
  String get paintNone => 'No paint in the store yet — press «Paint received».';

  @override
  String get paintOwed => 'Owed for paint';

  @override
  String get paintPaid => 'Paid';

  @override
  String paintHistory(String title) {
    return 'Received: $title';
  }

  @override
  String paintTakenBy(String who) {
    return 'taken in by $who';
  }

  @override
  String paintUsage(String days, String m2, String kg) {
    return '$days days: $m2 m² painted, $kg kg used';
  }

  @override
  String paintUsageFact(String fact, String norm) {
    return 'really $fact kg/m² (figure $norm)';
  }

  @override
  String paintRecipe(String kg) {
    return 'Recipe: $kg kg/m²';
  }

  @override
  String get paintRecipeTitle => 'Paint recipe';

  @override
  String get paintRecipeHint =>
      'Each layer: grams a m² a coat and how many coats (0 — not painted); what goes into each kilo of it. The enamel is the order\'s colour. A price here counts only until the material is bought.';

  @override
  String get paintLayerName => 'Layer';

  @override
  String get paintLayerColour => 'In the order\'s colour';

  @override
  String get paintLayerGM2 => 'g/m² a coat';

  @override
  String get paintLayerCoats => 'Coats';

  @override
  String paintLayerKg(String kg) {
    return '$kg kg/m² with what goes in';
  }

  @override
  String get paintPartName => 'Goes in';

  @override
  String get paintPartPerKg => 'kg per 1 kg';

  @override
  String get paintPartAdd => 'Hardener, thinner…';

  @override
  String get paintLayerAdd => 'Add a layer';

  @override
  String get paintRemove => 'Remove';

  @override
  String get paintCalc => 'How much paint';

  @override
  String get paintCalcM2 => 'm²';

  @override
  String get paintCalcNoColour => 'Any colour';

  @override
  String paintCalcTotal(String kg, String cost) {
    return 'All together $kg kg · $cost';
  }

  @override
  String paintCalcPerM2(String cost) {
    return 'the paint of a m² costs $cost';
  }

  @override
  String get paintCalcUnpriced =>
      'Not every material has a price, so the cost is short — put it in the recipe.';

  @override
  String get paintSendWhatsApp => 'Send in WhatsApp';

  @override
  String get paintCopy => 'Copy';

  @override
  String get paintCopied => 'Copied';

  @override
  String get paintForQueue => 'For the whole queue';

  @override
  String paintMaterialNeed(String need, String have) {
    return 'needs $need kg · $have kg here';
  }

  @override
  String mdfPaintPlan(String colour, String kg) {
    return 'Paint $colour: $kg kg';
  }

  @override
  String get mdfPaintAskSupplier => 'Ask the supplier to tint';

  @override
  String get mdfPaintAskClient => 'Tell the customer what to bring';

  @override
  String get paintSupplierCard => 'Paint supplier';

  @override
  String get paintSupplierEdit => 'The supplier’s card';

  @override
  String get paintSupplierName => 'Company or person';

  @override
  String get paintSupplierCity => 'City';

  @override
  String get paintSupplierContact => 'Contact person';

  @override
  String get paintSupplierPhone => 'Phone';

  @override
  String get paintSupplierWhatsApp => 'WhatsApp';

  @override
  String get paintSupplierMinOrder => 'Smallest batch';

  @override
  String get paintSupplierMinHint => 'e.g. 3 kg';

  @override
  String get paintSupplierNote => 'Note';

  @override
  String paintSupplierMin(String min) {
    return 'smallest batch $min';
  }

  @override
  String paintBatchLeft(String need, String left) {
    return 'The queue needs $need kg — $left kg will stay on the shelf';
  }

  @override
  String get paintPriceM2 => 'Your price a m²';

  @override
  String get paintMarkup => 'Markup, %';

  @override
  String paintLeftM2(String left) {
    return '$left left of a m²';
  }

  @override
  String paintLeftOrder(String left, String m2) {
    return '$left left of $m2 m²';
  }

  @override
  String paintByMarkup(String price, String total) {
    return 'by the markup: $price a m², $total in all';
  }

  @override
  String get paintRemember => 'Remember the price and markup';

  @override
  String get paintRecipeEdit => 'Recipe and prices';

  @override
  String get paintSendTo => 'To';

  @override
  String get paintSendToAnyone => 'Choose in WhatsApp';

  @override
  String get paintPartPct => '% of its weight';

  @override
  String mdfPaintNorm(String list) {
    return 'Use by the norm: $list';
  }

  @override
  String mdfPaintBatch(String have, String batch, String use, String left) {
    return '$have kg on the shelf (the last batch $batch kg) — use $use kg; $left kg stays on the shelf';
  }

  @override
  String get paintCount => 'Count what is left';

  @override
  String paintCountTitle(String title) {
    return 'How many kg of $title are really here?';
  }

  @override
  String get paintCountHint =>
      'Weigh what is left. The difference from the program counts as used.';

  @override
  String get mdfGloss => 'Sheen';

  @override
  String get mdfGlossNone => '—';

  @override
  String get mdfGlossMatt => 'matt';

  @override
  String get mdfGlossSemi => 'semi-matt';

  @override
  String get mdfGlossGloss => 'gloss';

  @override
  String get mdfGlossMetallic => 'metallic';

  @override
  String get mdfGlossPearl => 'pearl';

  @override
  String get paintDeliveryOwed => 'Owed for bringing paint';

  @override
  String get paintDeliveryBack => 'Given back';

  @override
  String get paintDeliveryPaid => 'Paid';

  @override
  String paintDeliveryToEmployee(String name) {
    return '$name paid';
  }

  @override
  String get paintDeliveryToCarrier => 'carrier not paid';

  @override
  String get cncAccept => 'Accept';

  @override
  String get cncAddCustom => 'Work of its own';

  @override
  String get cncAddMaterial => 'Our material';

  @override
  String get cncAddService => 'Work from the price list';

  @override
  String cncAhead(String time) {
    return '$time before it';
  }

  @override
  String get cncAmount => 'Amount';

  @override
  String get cncByAgreement => 'by agreement';

  @override
  String get cncCancel => 'Cancel the order';

  @override
  String get cncCancelTitle => 'Why is it cancelled?';

  @override
  String cncCost(String price) {
    return 'cost $price';
  }

  @override
  String get cncCustomWork => 'What work';

  @override
  String cncDayMinutes(String minutes) {
    return 'machine $minutes min a day';
  }

  @override
  String get cncDayMinutesLabel => 'Machine working minutes a day';

  @override
  String cncDebtComment(String amount) {
    return 'Owes $amount — why hand it over?';
  }

  @override
  String get cncDebtLabel => 'Owed';

  @override
  String cncDefects(String text) {
    return 'defects: $text';
  }

  @override
  String cncDue(String day) {
    return 'due $day';
  }

  @override
  String get cncEmpty => 'No CNC orders yet — press «New order».';

  @override
  String cncEta(String day) {
    return 'ready $day';
  }

  @override
  String get cncHandOver => 'Hand over';

  @override
  String cncHandedOverOn(String day, String who) {
    return 'Handed over $day: $who';
  }

  @override
  String get cncHint => 'The machine for hire: worktops, sheets, lattices';

  @override
  String get cncHistory => 'History';

  @override
  String get cncHold => 'Waiting…';

  @override
  String get cncHoldTitle => 'What are we waiting for?';

  @override
  String cncHolding(String reason) {
    return 'waiting: $reason';
  }

  @override
  String get cncHours => 'h';

  @override
  String get cncIntake => 'The customer\'s material';

  @override
  String get cncIntakeAdd => 'Add what he brought';

  @override
  String get cncIntakeDefects => 'Defects (chip, scratch)';

  @override
  String get cncIntakeWhat => 'What (worktop 3000×600, LDSP sheet)';

  @override
  String get cncLineNote => 'Note';

  @override
  String cncMachineTime(String time) {
    return 'Machine time: $time';
  }

  @override
  String get cncMakerPrices => 'Furniture maker\'s prices';

  @override
  String cncMinOrder(String amount) {
    return 'minimum $amount';
  }

  @override
  String get cncMinOrderLabel => 'Minimum order, ₸';

  @override
  String get cncMinutesShort => 'min';

  @override
  String get cncNewOrder => 'New order';

  @override
  String get cncNoGroup => 'Other';

  @override
  String get cncNoMaterials => 'The warehouse has no sheets yet.';

  @override
  String get cncNoPhone => 'The customer has no phone on his card.';

  @override
  String get cncNoPrice => 'no price';

  @override
  String get cncNotReady => 'Not ready after all';

  @override
  String get cncNotes => 'Notes';

  @override
  String get cncOk => 'OK';

  @override
  String cncOwes(String amount) {
    return 'owes $amount';
  }

  @override
  String cncPaid(String amount) {
    return 'paid $amount';
  }

  @override
  String get cncPay => 'Payment';

  @override
  String get cncPayments => 'Payments';

  @override
  String cncPerUnitMinutes(String minutes) {
    return '$minutes min a unit';
  }

  @override
  String get cncPickCustomer => 'Choose the customer';

  @override
  String get cncPricesTitle => 'CNC price list';

  @override
  String get cncQty => 'Qty';

  @override
  String get cncQueueLabel => 'Machine queue';

  @override
  String cncQueueOrders(int count) {
    return '$count orders';
  }

  @override
  String get cncRate => 'Price';

  @override
  String get cncReadyAction => 'Ready';

  @override
  String get cncReadyLabel => 'Ready to hand over';

  @override
  String cncReadyMessage(String name) {
    return 'Hello! Your order $name is ready, you can collect it.';
  }

  @override
  String cncReadyMessageDebt(String name, String amount) {
    return 'Hello! Your order $name is ready. To pay: $amount.';
  }

  @override
  String get cncRemove => 'Remove';

  @override
  String get cncSaveDraft => 'Save';

  @override
  String get cncSaved => 'Saved';

  @override
  String get cncSearchHint => 'Number or customer';

  @override
  String get cncServiceAdd => 'Add a service';

  @override
  String get cncServiceEdit => 'Service';

  @override
  String get cncServiceGroup => 'Group (Cutting, Worktops…)';

  @override
  String get cncServiceMinutes => 'Machine minutes a unit';

  @override
  String get cncServiceOff => 'switched off';

  @override
  String get cncServiceOn => 'In the price list';

  @override
  String get cncServicePrice => 'Price a unit, ₸';

  @override
  String get cncServiceTitle => 'Name';

  @override
  String get cncServiceTrade => 'Price for furniture makers, ₸';

  @override
  String get cncSettingsTitle => 'Urgency, minimum, machine day';

  @override
  String get cncStart => 'On the machine';

  @override
  String get cncStatusAll => 'All';

  @override
  String get cncStatusCancelled => 'Cancelled';

  @override
  String get cncStatusDraft => 'Draft';

  @override
  String get cncStatusHandedOver => 'Handed over';

  @override
  String get cncStatusOnMachine => 'On the machine';

  @override
  String get cncStatusQueued => 'In the queue';

  @override
  String get cncStatusReady => 'Ready';

  @override
  String get cncTakenBy => 'Taken by (if not the customer)';

  @override
  String get cncTakenPhone => 'His phone';

  @override
  String get cncTell => 'Tell the customer';

  @override
  String get cncTerms =>
      'The customer agrees: hidden defects of his material are his';

  @override
  String get cncTermsAgreed => 'The customer agreed: hidden defects are his.';

  @override
  String get cncTitle => 'CNC services';

  @override
  String get cncTotal => 'Total';

  @override
  String cncTradePrice(String price) {
    return 'makers $price';
  }

  @override
  String get cncUnhold => 'No longer waiting';

  @override
  String get cncUrgent => 'Urgent';

  @override
  String cncUrgentPct(String pct) {
    return 'urgent +$pct%';
  }

  @override
  String get cncUrgentPctLabel => 'Urgency surcharge, %';

  @override
  String get cncWork => 'Work';

  @override
  String get mdfGiveStageTo => 'Who gets this stage?';

  @override
  String get mdfStageTakeBack => 'Take it back — nobody';

  @override
  String get mdfStagePostPeople => 'On this post';

  @override
  String get mdfAllWorkers => 'Everyone';

  @override
  String mdfStageGiven(String stage, String name) {
    return '$stage: $name';
  }

  @override
  String get mdfStageNobody => 'not given';

  @override
  String get teamDeptIntake => 'Order intake';

  @override
  String get teamDeptCut => 'Cutting';

  @override
  String get teamDeptCnc => 'CNC';

  @override
  String get teamDeptPvc => 'PVC film';

  @override
  String get teamDeptPaint => 'Painting';

  @override
  String get teamDeptPack => 'Packing and hand-over';

  @override
  String get teamDeptFilmSales => 'Film sales';

  @override
  String get teamDeptWarehouse => 'Warehouse and delivery';

  @override
  String get teamPostManager => 'Intake manager';

  @override
  String get teamPostCutter => 'Cutter';

  @override
  String get teamPostCncOperator => 'CNC operator';

  @override
  String get teamPostSander => 'Sander';

  @override
  String get teamPostVacuum => 'Vacuum press operator';

  @override
  String get teamPostPainter => 'Painter';

  @override
  String get teamPostPacker => 'Packer';

  @override
  String get teamPostSeller => 'Seller';

  @override
  String get teamPostLoader => 'Loader';

  @override
  String get teamPostStorekeeper => 'Storekeeper';

  @override
  String get teamPostDriver => 'Driver';

  @override
  String get teamDepartmentsSection => 'Departments and people';

  @override
  String get teamDepartmentsHint =>
      'An order\'s stage goes to the people of its post. A phone icon: they tick it themselves; without one, the manager does.';

  @override
  String get teamAddPerson => 'Person';

  @override
  String get teamAddPersonShort => 'More';

  @override
  String get teamLeft => 'Left the company';

  @override
  String get teamPersonBack => 'Bring back';

  @override
  String get teamUnplaced => 'No post yet';

  @override
  String get teamPostEmpty => 'nobody';

  @override
  String get teamPostEmptyAdd => 'Add';

  @override
  String teamPersonSaved(String name) {
    return '$name saved';
  }

  @override
  String teamPersonLeftTitle(String name) {
    return 'Has $name left?';
  }

  @override
  String get teamPersonLeftMessage =>
      'They leave the lists; the work they did stays theirs.';

  @override
  String get teamPersonLeft => 'Left';

  @override
  String get teamPersonName => 'Name';

  @override
  String get teamPersonPhone => 'Phone';

  @override
  String get teamPersonPosts => 'Posts — any number';

  @override
  String get teamPersonLogin => 'App login';

  @override
  String get teamPersonLoginHint =>
      'With a login they see «My orders» on their phone and tick themselves; without one the manager ticks for them.';

  @override
  String get teamPersonNoLogin => 'No login';

  @override
  String get teamPersonSave => 'Save';

  @override
  String get teamLoginsSection => 'App logins';

  @override
  String get myWorkTitle => 'My orders';

  @override
  String myWorkDone(String order, String stage) {
    return '$order: «$stage» done';
  }

  @override
  String get myWorkUndo => 'Undo';

  @override
  String get myWorkNotLinkedTitle => 'You are not on the team yet';

  @override
  String get myWorkNotLinked =>
      'Ask the manager to tie your login to a person in «Team» and give you a post.';

  @override
  String get myWorkReady => 'Ready for you';

  @override
  String get myWorkNothingReady => 'Nothing is waiting for you now.';

  @override
  String get myWorkComing => 'Coming to you';

  @override
  String get myWorkMonth => 'My volume this month';

  @override
  String myWorkMonthTotal(String area, int orders) {
    return '$area m² · orders: $orders';
  }

  @override
  String myWorkDue(String date) {
    return 'due $date';
  }

  @override
  String myWorkWaiting(String stages) {
    return 'waiting for: $stages';
  }

  @override
  String get myWorkDoneButton => 'Done';

  @override
  String myWorkStageM2(String stage, String area) {
    return '$stage $area m²';
  }

  @override
  String get glueTitle => 'PVC glue';

  @override
  String get glueRowHint => 'Glues, suppliers, norm per m², millings';

  @override
  String get glueHint =>
      'A glue is the product: what it is and how much a m² takes. A supplier is where it is bought. «Vacuum» takes off the glue in work.';

  @override
  String get glueReceive => 'Glue received';

  @override
  String get glueAdd => 'New glue';

  @override
  String get glueEdit => 'Glue card';

  @override
  String get glueName => 'Name';

  @override
  String get glueOrigin => 'Made in';

  @override
  String get glueOriginHint => 'e.g. China';

  @override
  String get glueBucketKg => 'Bucket, kg';

  @override
  String get glueKgPerLitre => 'Kg per litre';

  @override
  String get glueKgPerLitreHint => 'from the glue sheet, usually about 1';

  @override
  String get glueNorm => 'Norm, g/m²';

  @override
  String get glueReserve => 'Keep for the shop, kg';

  @override
  String get glueMarkupBucket => 'Bucket mark-up, %';

  @override
  String get glueMarkupLitre => 'Litre mark-up, %';

  @override
  String get glueInWork => 'In work';

  @override
  String get glueTakeInWork => 'Take into work';

  @override
  String get glueCount => 'Count';

  @override
  String glueCountTitle(String title) {
    return '$title: how many kg really';
  }

  @override
  String glueOnHand(String kg) {
    return 'On hand $kg kg';
  }

  @override
  String glueNormLine(String g) {
    return 'Norm $g g/m²';
  }

  @override
  String glueCostKg(String money) {
    return '$money/kg landed';
  }

  @override
  String glueCostM2(String money) {
    return '$money a m²';
  }

  @override
  String glueSell(String bucket, String litre) {
    return 'Sells: bucket $bucket · litre $litre';
  }

  @override
  String glueFact(String g) {
    return 'This month really: $g g/m²';
  }

  @override
  String glueQueue(String orders, String m2, String kg) {
    return 'Vacuum queue: $orders orders, $m2 m² — needs $kg kg of glue';
  }

  @override
  String glueQueueShort(String kg) {
    return 'The glue in work is short by $kg kg';
  }

  @override
  String get glueNoInWork => 'No glue is in work — pick the open barrel';

  @override
  String get glueGlues => 'Glues';

  @override
  String get glueEmpty => 'No glues yet — add the first';

  @override
  String get glueSuppliers => 'Where we buy';

  @override
  String get glueSupplierAdd => 'Glue supplier';

  @override
  String glueBought(
    String title,
    String price,
    String delivery,
    String landed,
  ) {
    return '$title: $price + delivery $delivery = $landed a kg';
  }

  @override
  String get glueCheapest => 'cheaper';

  @override
  String get glueMilling => 'Milling factor';

  @override
  String glueMillingHint(String coats) {
    return 'How many times the glue of a smooth face; 1.00 is the same. Edges take $coats coats.';
  }

  @override
  String glueMillingTitle(String name) {
    return '$name: factor';
  }

  @override
  String get glueOwed => 'Owed for glue';

  @override
  String get glueGlue => 'Glue';

  @override
  String get glueSupplier => 'Supplier';

  @override
  String get glueQty => 'How much';

  @override
  String get gluePrice => 'Price';

  @override
  String get gluePer => 'per';

  @override
  String get glueUnitKg => 'kg';

  @override
  String get glueUnitLitre => 'litre';

  @override
  String get glueUnitBucket => 'bucket';

  @override
  String glueReceiveSum(String kg, String price) {
    return '$kg kg at $price a kg';
  }

  @override
  String glueLanded(String money) {
    return 'Landed: $money a kg';
  }

  @override
  String get glueSave => 'Save';

  @override
  String glueOrderPlan(String kg, String title, String norm) {
    return 'PVC glue: $kg kg · $title · $norm g/m²';
  }

  @override
  String glueLineKg(String kg) {
    return 'glue $kg kg';
  }

  @override
  String get filmSaleAddGlue => 'Glue';

  @override
  String get filmGlueNone => 'No glues — add them in «PVC glue»';

  @override
  String filmGlueBuckets(String n) {
    return '$n bucket(s)';
  }

  @override
  String filmGlueLitres(String n) {
    return '$n l';
  }

  @override
  String filmGlueReserve(String title, String left, String keep) {
    return '«$title»: $left kg will be left — the shop needs $keep kg';
  }

  @override
  String get filmGlueReserveOk => 'Sell from the shop\'s stock';

  @override
  String filmGlueOver(String have) {
    return 'Only $have kg on hand';
  }

  @override
  String filmGlueLeft(String kg, String left) {
    return '≈ $kg kg off the store · $left kg left';
  }

  @override
  String filmGlueBelow(String cost) {
    return 'Below cost: $cost a kg landed';
  }

  @override
  String get glueMonthTitle => 'Glue reconciliation';

  @override
  String get glueMonthHint =>
      'How many m² went through the vacuum, how much glue the norm took for them, and what weighing the rest found. The fact shows only once the store was weighed in the month.';

  @override
  String get glueMonthEmpty => 'No glue went into orders this month.';

  @override
  String glueMonthLine(String m2, String kg) {
    return '$m2 m² through the vacuum · $kg kg by the norm';
  }

  @override
  String glueMonthShort(String kg, String money) {
    return 'Short by $kg kg — $money';
  }

  @override
  String glueMonthOver(String kg, String money) {
    return 'Over by $kg kg — $money';
  }

  @override
  String get glueMonthEven => 'The weighing matched the norm';

  @override
  String get glueMonthNotCounted =>
      'Not weighed this month — no fact yet. Weigh the rest («Recount») at the month\'s end.';

  @override
  String glueMonthWeighed(String count, String date) {
    return 'Weighed $count times, last on $date';
  }

  @override
  String glueMonthFact(String fact, String norm, String pct) {
    return 'Fact $fact g/m² against a norm of $norm ($pct%)';
  }

  @override
  String glueMonthCostM2(String norm, String fact) {
    return 'A m² costs $norm by the norm, $fact by the fact';
  }

  @override
  String glueMonthFixNorm(String g) {
    return 'Set the norm to $g g/m²';
  }

  @override
  String glueMonthNormSet(String g) {
    return 'The norm is now $g g/m²';
  }

  @override
  String get filmGlueOpen => 'PVC glue';

  @override
  String get glueAddFirst => 'Add the first glue';

  @override
  String get filmReceiveFilm => 'Film';

  @override
  String get filmReceiveGlue => 'PVC glue';

  @override
  String get filmFigGlue => 'PVC glue';

  @override
  String get filmFigGlueNone => 'not set up — tap';

  @override
  String filmFigGlueKg(String kg) {
    return '$kg kg';
  }

  @override
  String filmFigGlueBuckets(String buckets) {
    return '≈ $buckets buckets';
  }

  @override
  String filmFigGlueDays(String days) {
    return 'lasts $days d.';
  }

  @override
  String get cncpTitle => 'CNC patterns (β)';

  @override
  String get cncpRowHint => 'A trial: a facade pattern to a G-code program';

  @override
  String get cncpOffTitle => 'CNC patterns — a trial (β)';

  @override
  String get cncpOffBody =>
      'A pattern library (frames, arches, grooves) and the cutters; for any facade size it draws the cut and writes the G-code program for your router.\n\nWhile it is off it takes no part in the work. When on, it only reads an order\'s sizes: it changes no order, stock, money or stage, and sends nothing to the machine by itself — it saves a file for the operator to check on an offcut.';

  @override
  String get cncpEnable => 'Turn on in this base';

  @override
  String get cncpEnabledDone => 'CNC patterns are on in this base';

  @override
  String get cncpOwnerTurnsOn => 'The company owner turns it on.';

  @override
  String get cncpNotYours => 'It is on, but not opened for you. Ask the owner.';

  @override
  String get cncpBetaBanner =>
      'A trial: cut every new program on an MDF offcut first. Nothing goes to the machine by itself.';

  @override
  String get cncpTabPatterns => 'Patterns';

  @override
  String get cncpTabTools => 'Cutters';

  @override
  String get cncpTabMachine => 'Machine';

  @override
  String get cncpTabAccess => 'Access';

  @override
  String get cncpPatternsHint =>
      'A pattern is drawn once, measured from the facade\'s edges, and fits any size. Link it to a milling and an order\'s positions get their programs.';

  @override
  String get cncpPatternsEmpty => 'No patterns yet.';

  @override
  String get cncpPatternNew => 'New pattern';

  @override
  String get cncpExample => 'example';

  @override
  String get cncpExampleWarning =>
      'An example pattern: check the sizes and cut it on an offcut before a facade.';

  @override
  String get cncpNoMilling => 'Not linked to a milling';

  @override
  String cncpForMilling(String milling) {
    return 'Milling: $milling';
  }

  @override
  String cncpMinSize(String w, String h) {
    return 'From $w×$h mm';
  }

  @override
  String cncpMinSizeFallback(String w, String h, String fallback) {
    return 'From $w×$h mm; smaller — «$fallback»';
  }

  @override
  String cncpLineFrame(String offset) {
    return 'Frame $offset mm in';
  }

  @override
  String cncpLineFrameRound(String offset, String radius) {
    return 'Frame $offset mm in, round corners R$radius';
  }

  @override
  String cncpLineFrameCove(String offset, String radius) {
    return 'Frame $offset mm in, cove corners R$radius';
  }

  @override
  String cncpLineArch(String offset, String rise) {
    return 'Arch $offset mm in, rising $rise mm';
  }

  @override
  String cncpLineGroovesV(String step) {
    return 'Vertical grooves every $step mm';
  }

  @override
  String cncpLineGroovesH(String step) {
    return 'Horizontal grooves every $step mm';
  }

  @override
  String cncpLineTool(String shape, String tool, String depth) {
    return '$shape · $tool · $depth mm deep';
  }

  @override
  String get cncpPatternName => 'Pattern name';

  @override
  String get cncpPatternMilling => 'Milling';

  @override
  String get cncpPatternMillingHint =>
      'Positions with this milling are cut by this pattern';

  @override
  String get cncpPatternMinW => 'Smallest side, mm';

  @override
  String get cncpPatternMinH => 'Larger side, mm';

  @override
  String get cncpPatternFallback => 'For smaller facades';

  @override
  String get cncpPatternFallbackHint =>
      'This pattern is cut when the facade is smaller than the sizes above';

  @override
  String get cncpNone => '—';

  @override
  String get cncpElements => 'Elements';

  @override
  String get cncpElementAdd => 'Add an element';

  @override
  String get cncpKindFrame => 'Frame';

  @override
  String get cncpKindArch => 'Arch';

  @override
  String get cncpKindGrooves => 'Grooves';

  @override
  String get cncpTool => 'Cutter';

  @override
  String get cncpDepth => 'Depth, mm';

  @override
  String get cncpOffset => 'In from the edge, mm';

  @override
  String get cncpOffsetHint => 'To the cutter\'s centre line';

  @override
  String get cncpCornerSquare => 'Square';

  @override
  String get cncpCornerRound => 'Round';

  @override
  String get cncpCornerCove => 'Cove';

  @override
  String get cncpRadius => 'Corner radius, mm';

  @override
  String get cncpRise => 'Arch rise, mm';

  @override
  String get cncpVertical => 'Vertical';

  @override
  String get cncpHorizontal => 'Horizontal';

  @override
  String get cncpStep => 'Step, mm';

  @override
  String get cncpSide => 'Keep off the sides, mm';

  @override
  String get cncpSideHint => '0 — across the whole facade';

  @override
  String get cncpEnds => 'Stop short of the ends, mm';

  @override
  String get cncpEndsHint => '0 — through, edge to edge';

  @override
  String get cncpTryWidth => 'and width, mm';

  @override
  String get cncpTryHeight => 'Try on height, mm';

  @override
  String get cncpPreviewFailed => 'No connection to draw the pattern.';

  @override
  String cncpPreviewStats(String minutes, String files) {
    return '≈ $minutes min on the machine · programs: $files';
  }

  @override
  String cncpFileLine(
    String tool,
    String metres,
    String passes,
    String minutes,
  ) {
    return '$tool: $metres m of cut, passes $passes, ≈ $minutes min';
  }

  @override
  String get cncpDownload => 'Save G-code';

  @override
  String get cncpCheckOnOffcut =>
      'Cut it on an offcut first; the zero is the facade\'s bottom-left corner, Z0 its face.';

  @override
  String get cncpTrialsFolder => 'Trials';

  @override
  String cncpSavedTo(String dir) {
    return 'Saved: $dir';
  }

  @override
  String cncpSavedFiles(String count, String dir) {
    return 'Programs saved: $count — $dir';
  }

  @override
  String get cncpOpenFolder => 'Open folder';

  @override
  String get cncpSave => 'Save';

  @override
  String get cncpDelete => 'Delete';

  @override
  String cncpPatternSaved(String name) {
    return 'Pattern «$name» saved';
  }

  @override
  String cncpPatternDeleteAsk(String name) {
    return 'Delete the pattern «$name»?';
  }

  @override
  String get cncpToolsHint =>
      'The cutters and the speeds they cut MDF at. A pattern names its cutter; two cutters are two programs, run one after the other.';

  @override
  String get cncpToolNew => 'New cutter';

  @override
  String get cncpToolName => 'Name';

  @override
  String get cncpToolV => 'V-shaped';

  @override
  String get cncpToolBall => 'Round-nosed';

  @override
  String get cncpToolFlat => 'Straight';

  @override
  String cncpToolLine(
    String kind,
    String diameter,
    String feed,
    String rpm,
    String pass,
  ) {
    return '$kind · ⌀$diameter mm · feed $feed mm/min · $rpm rpm · $pass mm a pass';
  }

  @override
  String get cncpDiameter => 'Diameter, mm';

  @override
  String get cncpAngle => 'Angle, °';

  @override
  String get cncpFeed => 'Feed, mm/min';

  @override
  String get cncpPlunge => 'Plunge feed, mm/min';

  @override
  String get cncpRpm => 'Spindle, rpm';

  @override
  String get cncpPassDepth => 'Depth a pass, mm';

  @override
  String get cncpMachineHint =>
      'How your router reads a program. NcStudio, DSP and Mach3 read plain G-code; if the controller refuses arcs or Cyrillic, turn arcs off — comments are always written in Latin.';

  @override
  String get cncpExt => 'File extension';

  @override
  String get cncpArcs => 'Arcs as G2/G3 (off — short lines)';

  @override
  String get cncpComments => 'Comments in the program';

  @override
  String get cncpLineNumbers => 'Line numbers N10, N20…';

  @override
  String get cncpSwapXy => 'Facade height along X';

  @override
  String get cncpSafeZ => 'Safe height, mm';

  @override
  String get cncpClearZ => 'Approach height, mm';

  @override
  String get cncpRapid => 'Rapid speed, mm/min (for the time)';

  @override
  String get cncpDwell => 'Spindle spin-up pause, s (0 — none)';

  @override
  String get cncpOriginNote =>
      'The program\'s zero is the facade\'s bottom-left corner; Z0 is its face, cuts go below.';

  @override
  String get cncpMachineSaved => 'Machine settings saved';

  @override
  String get cncpAccessHint =>
      'Besides you, who sees CNC patterns in this base.';

  @override
  String get cncpAccessSaved => 'Access saved';

  @override
  String get cncpDisable => 'Turn off';

  @override
  String get cncpDisabledDone => 'Turned off. The library is kept.';

  @override
  String get cncpOrderButton => 'CNC (β)';

  @override
  String get cncpOrderTitle => 'Router programs (β)';

  @override
  String cncpOrderMinutes(String minutes) {
    return '≈ $minutes min of router time for the order';
  }

  @override
  String cncpOrderLine(
    String no,
    String height,
    String width,
    String qty,
    String milling,
  ) {
    return '№$no · $height×$width · $qty pcs · $milling';
  }

  @override
  String get cncpOrderNoPattern => 'No pattern for this milling';

  @override
  String cncpOrderPattern(String pattern, String minutes) {
    return '$pattern · ≈ $minutes min each';
  }

  @override
  String cncpOrderSaveAll(String count) {
    return 'Save programs ($count)';
  }

  @override
  String get fdcTitle => 'Supplier catalogues';

  @override
  String get fdcPictures => 'Pictures by code or name (several files)';

  @override
  String get fdcImport => 'Load a catalogue (zip)';

  @override
  String fdcImported(String added, String updated) {
    return 'Catalogue loaded: $added new, $updated updated';
  }

  @override
  String fdcPicturesDone(String count) {
    return 'Pictures put on films: $count';
  }

  @override
  String fdcPicturesMissed(String count, String names) {
    return 'Put on: $count. No film for: $names';
  }

  @override
  String get fdcEmpty =>
      'No catalogues yet. Load a zip prepared from a supplier\'s catalogue, or send the supplier\'s PDF to have one made.';

  @override
  String get fdcSearch => 'Name or code';

  @override
  String get fdcHint =>
      'A reference of the maker\'s decors, not the store. Tap a decor to take it in as a film; your films of the same name show its picture by themselves.';

  @override
  String fdcYouHave(String metres) {
    return 'You have it · $metres m';
  }

  @override
  String fdcThicknesses(String value) {
    return 'Thicknesses: $value';
  }

  @override
  String get fdcYourFilms => 'Your films of this decor';

  @override
  String fdcFilmLine(String label, String metres) {
    return '$label · $metres m';
  }

  @override
  String get fdcMakeHint =>
      'Not in your catalogue yet. The name, collection, code and colour come from the supplier\'s catalogue; the prices go on the film\'s card.';

  @override
  String get fdcMake => 'Take in as a film';

  @override
  String fdcMade(String label) {
    return 'Film added: $label';
  }

  @override
  String get fdcPhoto => 'Sample photo';

  @override
  String get fdcPhotoClear => 'Back to the catalogue picture';

  @override
  String get fdcNoPicture => 'No picture yet';

  @override
  String get gsrFind => 'Search…';

  @override
  String get gsrHotkey => 'Ctrl+K';

  @override
  String get gsrHint => 'Customer, phone, order no., film, section…';

  @override
  String get gsrTabAll => 'All';

  @override
  String get gsrTabCustomers => 'Customers';

  @override
  String get gsrTabOrders => 'Orders';

  @override
  String get gsrTabMoney => 'Money';

  @override
  String get gsrTabFilm => 'Film';

  @override
  String get gsrTabStock => 'Stock';

  @override
  String get gsrTabGo => 'Sections';

  @override
  String get gsrGroupRecent => 'Recent';

  @override
  String get gsrGroupActions => 'Actions';

  @override
  String get gsrGroupSections => 'Sections';

  @override
  String get gsrGroupCustomers => 'Customers';

  @override
  String get gsrGroupFacadeOrders => 'Facade orders';

  @override
  String get gsrGroupCncOrders => 'CNC orders';

  @override
  String get gsrGroupPayments => 'Payments';

  @override
  String get gsrGroupFilms => 'Films in stock';

  @override
  String get gsrGroupDecors => 'Supplier catalogues';

  @override
  String get gsrGroupOrders => 'Other orders';

  @override
  String get gsrGroupWorkOrders => 'Production';

  @override
  String get gsrGroupStock => 'Stock';

  @override
  String gsrOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '$count order',
    );
    return '$_temp0';
  }

  @override
  String gsrDebt(String amount) {
    return 'owes $amount';
  }

  @override
  String get gsrFilmCustomer => 'buys film';

  @override
  String get gsrActOrders => 'Orders';

  @override
  String get gsrActNewOrder => 'New order';

  @override
  String get gsrActSell => 'Sell';

  @override
  String get gsrActCopyPhone => 'Copy phone';

  @override
  String get gsrPhoneCopied => 'Phone copied';

  @override
  String get gsrDoNewFacadeOrder => 'New facade order';

  @override
  String get gsrDoNewCncOrder => 'New CNC order';

  @override
  String get gsrDoSellFilm => 'Sell film';

  @override
  String get gsrDoSellGlue => 'Sell glue';

  @override
  String get gsrDoReceiveFilm => 'Receive film';

  @override
  String get gsrDoReceiveGlue => 'Receive glue';

  @override
  String get gsrStart =>
      'Start typing to find a customer, an order, a film or a section. A wrong keyboard layout or a typo is fine.';

  @override
  String gsrNothing(String query) {
    return 'Nothing found for “$query”';
  }

  @override
  String get gsrByPhone => 'Searching by phone';

  @override
  String gsrByNumber(String number) {
    return 'Looking for order no. $number';
  }

  @override
  String get gsrKeys => '↑↓ choose · Enter open · Esc close';

  @override
  String gsrPaid(String amount) {
    return 'paid $amount';
  }

  @override
  String get navToWrite => 'Who to write to';

  @override
  String get clcTitle => 'Customer card';

  @override
  String get clcOrders => 'Orders';

  @override
  String get clcTotal => 'Ordered for';

  @override
  String get clcPaid => 'Paid';

  @override
  String get clcDebt => 'Owes';

  @override
  String get clcAverage => 'Average order';

  @override
  String get clcLast => 'Last order';

  @override
  String clcSince(String date) {
    return 'customer since $date';
  }

  @override
  String get clcNewOrder => 'New order';

  @override
  String get clcSellFilm => 'Sell film';

  @override
  String get clcAllOrders => 'All orders';

  @override
  String get clcOrdersSection => 'Orders';

  @override
  String get clcPaymentsSection => 'Payments';

  @override
  String get clcFilmSection => 'Film';

  @override
  String clcFilmLine(String metres, String sum, String debt) {
    return 'bought $metres m for $sum · owes $debt';
  }

  @override
  String get clcFilmOpen => 'Film purchases';

  @override
  String get clcNoOrders => 'No orders yet';

  @override
  String get clcCnc => 'CNC';

  @override
  String get clcWhatsApp => 'Write on WhatsApp';

  @override
  String twReady(int count) {
    return 'Ready — tell the customer ($count)';
  }

  @override
  String twDebts(int count) {
    return 'Remind of a debt ($count)';
  }

  @override
  String twFilm(int count) {
    return 'Film — debts ($count)';
  }

  @override
  String get twEmpty => 'Nobody to write to today';

  @override
  String get twEmptyHint =>
      'Ready orders the customer has not been told about, and debts due a reminder, appear here.';

  @override
  String twReadyLine(String date) {
    return 'ready $date';
  }

  @override
  String twDebtLine(String sum) {
    return 'to pay $sum';
  }

  @override
  String twHandedLine(String date) {
    return 'handed over $date';
  }

  @override
  String twRemindedLine(int count, String date) {
    return 'reminded: $count, last $date';
  }

  @override
  String twFilmDays(int days) {
    return 'owed for $days days';
  }

  @override
  String get twSend => 'Write on WhatsApp';

  @override
  String get twMark => 'Sent';

  @override
  String get twMarked => 'Marked — won\'t ask again';

  @override
  String get twSentQ => 'Did you send it?';

  @override
  String get twNoPhone => 'The customer has no phone';

  @override
  String get twTemplates => 'Message texts';

  @override
  String get twTemplateReady => 'Order ready';

  @override
  String get twTemplateDebt => 'Order debt';

  @override
  String get twTemplateFilm => 'Film debt';

  @override
  String get twTemplateHint => 'You can insert:';

  @override
  String get twTemplateReset => 'Back to the default';

  @override
  String get twTemplateSave => 'Save';

  @override
  String get dsmTitle => 'Day summary';

  @override
  String dsmSwitch(String hour) {
    return 'Send to me every day at $hour:00';
  }

  @override
  String get dsmHint =>
      'Arrives in Telegram or WhatsApp if connected in Settings → Channels.';

  @override
  String get dsmCopy => 'Copy';

  @override
  String get dsmCopied => 'Summary copied';

  @override
  String get dsmSendMe => 'Send to my WhatsApp';

  @override
  String get dsmHour => 'Hour';

  @override
  String get orderTell => 'Tell the customer';

  @override
  String orderTold(String date) {
    return 'Customer told $date';
  }

  @override
  String get fdcMatchPhoto => 'Match a sample photo';

  @override
  String get fdcMatchTitle => 'Like the sample';

  @override
  String get fdcMatchHint =>
      'Daylight, no shadow; the middle of the photo is read. A hint — check it against the sample by eye.';

  @override
  String get fdcAnalogues => 'Look-alikes';

  @override
  String fdcAnaloguesTitle(String name) {
    return 'Look-alikes: $name';
  }

  @override
  String get fdcLikeClose => 'very close';

  @override
  String get fdcLikeNear => 'close';

  @override
  String get fdcLikeFar => 'distant';

  @override
  String fdcOnShelf(String metres) {
    return '$metres m in stock';
  }

  @override
  String get fdcNotOnShelf => 'not in stock';

  @override
  String get fdcNoMatches => 'Nothing alike found';

  @override
  String get dsmMorning => 'At 9:00 — what to order';

  @override
  String get dsmMorningTitle => 'Time to order';

  @override
  String get scanEntryTitle => 'Order number';

  @override
  String get scanEntryHint => '245 or a sticker\'s code';

  @override
  String get scanEntryOpen => 'Open';

  @override
  String scanTitle(String number, String customer) {
    return 'No. $number · $customer';
  }

  @override
  String get scanHandedOver => 'Already handed over';

  @override
  String get scanOnHold => 'On hold';

  @override
  String scanDoneOn(String date) {
    return 'done $date';
  }

  @override
  String get scanYours => 'yours — can be done now';

  @override
  String get scanNotYours => 'not yours';

  @override
  String get scanOpenOrder => 'Open the order';

  @override
  String get mdfPrintSticker => 'Sticker';

  @override
  String get navOffcuts => 'Offcuts';

  @override
  String get offcutsTitle => 'MDF offcuts';

  @override
  String offcutsSummary(int count, String area) {
    return '$count pcs · $area m²';
  }

  @override
  String get offcutsAdd => 'Put on the shelf';

  @override
  String get offcutsAll => 'All';

  @override
  String offcutsMm(int mm) {
    return '$mm mm';
  }

  @override
  String get offcutsEmptyTitle => 'No offcuts';

  @override
  String get offcutsEmpty =>
      'A piece left from a sheet goes on the shelf with its size — a new order\'s small parts are cut from it first.';

  @override
  String offcutsCell(String cell) {
    return 'place $cell';
  }

  @override
  String offcutsFrom(String number) {
    return 'from No. $number';
  }

  @override
  String offcutsFor(String number) {
    return 'for No. $number';
  }

  @override
  String get offcutsUse => 'Taken into work';

  @override
  String get offcutsScrap => 'Throw away';

  @override
  String get offcutsAddTitle => 'An offcut on the shelf';

  @override
  String get offcutsThickness => 'Thickness';

  @override
  String get offcutsLength => 'Length, mm';

  @override
  String get offcutsWidth => 'Width, mm';

  @override
  String get offcutsCellLabel => 'Where it lies';

  @override
  String get offcutsCellHint => 'A-3';

  @override
  String get offcutsNote => 'Note';

  @override
  String get offcutsPut => 'Put';

  @override
  String offcutsSuggestTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts',
      one: '1 part',
    );
    return 'From offcuts: $_temp0';
  }

  @override
  String offcutsSuggestLine(
    int position,
    String part,
    String offcut,
    String cell,
  ) {
    return 'Item $position: $part — from $offcut, $cell';
  }

  @override
  String get offcutsTake => 'Take';

  @override
  String mdfFilmToBuy(String metres) {
    return 'not in stock · $metres m to order';
  }

  @override
  String mdfFilmToBuyFrom(String metres, String from) {
    return 'not in stock · $metres m from $from';
  }

  @override
  String filmOrdersForOrders(int count, String metres) {
    return 'for orders ($count) · $metres m';
  }

  @override
  String mdfClientPartsSome(int marked, int total) {
    return 'Customer\'s LMDF: $marked of $total';
  }

  @override
  String get fpkTitle => 'PVC film';

  @override
  String get fpkSearch => 'Name, code or maker';

  @override
  String get fpkByPhoto => 'By a sample\'s photo';

  @override
  String get fpkAll => 'All';

  @override
  String get fpkOnShelf => 'In stock';

  @override
  String get fpkRecent => 'This customer\'s of late';

  @override
  String fpkFound(int count) {
    return 'Found $count · in stock first';
  }

  @override
  String get fpkCatalogOnly => 'catalogue only';

  @override
  String get fpkNothing => 'Nothing found';

  @override
  String get fpkNone => 'No film';

  @override
  String get cncpArtcam => 'From ArtCAM';

  @override
  String get cncpArtcamTitle => 'Cutters from ArtCAM';

  @override
  String cncpArtcamHint(int all, int ready) {
    return '$all in the file, $ready can be added. The wood and MDF ones are ticked.';
  }

  @override
  String cncpArtcamAdd(int count) {
    return 'Add $count';
  }

  @override
  String cncpArtcamAdded(int count) {
    return 'Cutters added: $count';
  }

  @override
  String get cncpToolsSearch => 'Find a cutter: name, diameter, angle';

  @override
  String get fpkCard => 'Film card';

  @override
  String get fpkSideFilm => 'Film';

  @override
  String get fpkSideEdit => 'Edit';

  @override
  String get fpkSidePick => 'Pick';

  @override
  String get fpkSideNone => 'none on the shelf';

  @override
  String fpkSideHeld(String metres) {
    return 'held for orders: $metres m';
  }

  @override
  String fpkSideComing(String metres, String day) {
    return 'on its way $metres m · $day';
  }

  @override
  String fpkSideDaily(String metres, String days) {
    return '~$metres m a day · lasts $days days';
  }

  @override
  String fpkSideBuy(String price) {
    return 'purchase $price/m';
  }

  @override
  String fpkSideRetail(String price) {
    return 'retail $price/m';
  }

  @override
  String fpkSideWholesale(String price) {
    return 'wholesale $price/m';
  }

  @override
  String get fwTitle => 'No film — where to get it';

  @override
  String get fwWhere => 'where to get';

  @override
  String get fwNothingShort => 'There is enough of this film now.';

  @override
  String fwNeedBy(String day) {
    return 'needed in the shop by $day';
  }

  @override
  String get fwUrgent => 'urgent';

  @override
  String fwShort(String metres) {
    return '$metres m short';
  }

  @override
  String fwOrdered(String metres, String supplier) {
    return 'Ordered $metres m · $supplier';
  }

  @override
  String fwNowhere(String day) {
    return 'Nowhere — rang everyone $day';
  }

  @override
  String fwNoSources(String maker) {
    return 'No sources for «$maker» — add them in «Where to buy».';
  }

  @override
  String get fwAdvised => 'advised';

  @override
  String fwPrice(String price, String delivery, String landed) {
    return '$price + delivery $delivery = $landed a metre';
  }

  @override
  String fwPriceOnly(String price) {
    return '$price a metre';
  }

  @override
  String get fwCardPrice => 'card price';

  @override
  String fwTimes(String count) {
    return 'bought $count times';
  }

  @override
  String fwComes(String days, String day) {
    return '$days days → comes $day';
  }

  @override
  String get fwInTime => 'in time';

  @override
  String get fwLate => 'too late';

  @override
  String get fwLeadUnknown => 'lead time unknown';

  @override
  String get fwOrderButton => 'In stock — order';

  @override
  String get fwAcceptFirst => 'You can order once the order is accepted.';

  @override
  String get fwNowhereButton => 'Nowhere';

  @override
  String get fwLookalikes => 'Look-alikes from other makers';

  @override
  String fwOnShelf(String metres) {
    return '$metres m on our shelf';
  }

  @override
  String get fwOffer => 'Offer to the customer on WhatsApp';

  @override
  String fwOfferText(String film, String other) {
    return 'Hello! «$film» is not available from the suppliers right now. There is a very similar one — «$other». Would it suit you?';
  }

  @override
  String get fwReplace => 'Replace';

  @override
  String fwReplaceTitle(String film, String other) {
    return 'Replace «$film» with «$other»?';
  }

  @override
  String get fwReplaceReason => 'Why — e.g. «the customer agreed on WhatsApp»';

  @override
  String fwOrderTitle(String film, String supplier) {
    return '$film — from $supplier';
  }

  @override
  String get fwMetres => 'Metres';

  @override
  String get fwPriceField => 'Price a metre they named';

  @override
  String get fwSaidBy => 'Who confirmed (the supplier\'s manager)';

  @override
  String get fwComesOn => 'Arrives';

  @override
  String get fwOrderConfirm => 'To «To order»';

  @override
  String get fwOrderedDone => 'Added to «To order».';

  @override
  String get filmReceiveTitle => 'Film arrival';

  @override
  String get filmReceiveWaiting => 'Waiting for — what was ordered';

  @override
  String get filmReceiveNothingWaited =>
      'Nothing is on its way — find the film below.';

  @override
  String filmReceiveOrderedFrom(String supplier) {
    return 'Ordered from $supplier';
  }

  @override
  String get filmReceiveAllCame => 'All of it came';

  @override
  String filmReceiveMetres(String metres) {
    return '$metres m';
  }

  @override
  String get filmReceiveOther => 'Or another film — from the catalogues too';

  @override
  String get filmReceiveSearch => 'Maker, colour or code';

  @override
  String get filmReceiveDone => 'The film is on the shelf.';

  @override
  String filmReceiveRestComing(String metres) {
    return 'The remaining $metres m stay on their way.';
  }

  @override
  String get filmCatalogueTools => 'Load catalogues and pictures';

  @override
  String filmOurs(String count) {
    return 'Ours · $count';
  }

  @override
  String filmCatalogueOf(String maker, String count) {
    return '$maker catalogue · $count more';
  }

  @override
  String get filmCatalogueHint => 'Tap a decor to take it in or look at it.';

  @override
  String get filmReceiveCatalogues => 'Makers\' catalogues — tap to open';

  @override
  String filmReceiveCatalogOf(String maker, int count) {
    return '$maker\'s catalogue · not taken in yet: $count';
  }

  @override
  String filmReceiveCatalogFound(int count) {
    return 'From the catalogues · $count';
  }

  @override
  String filmReceiveCatalogMore(int count) {
    return '$count more — narrow the search or the collection';
  }

  @override
  String get pcTitle => 'Paint catalogue';

  @override
  String get pcByPhoto => 'By a sample\'s photo';

  @override
  String get pcAdd => 'Colour';

  @override
  String get pcNoSystem => 'No system';

  @override
  String get pcSearch => 'Code or name: 7016, graphite, ivory';

  @override
  String get pcShowAll => 'All';

  @override
  String get pcShowPopular => 'Ours, in use';

  @override
  String get pcShowTop => 'Furniture top 20';

  @override
  String get pcShowTrend => 'Trends';

  @override
  String get pcShowStock => 'On the shelf';

  @override
  String get pcShowStarred => 'Starred';

  @override
  String get pcShowHidden => 'Hidden';

  @override
  String pcOurs(int days) {
    return 'Ours, in use · $days days';
  }

  @override
  String get pcTrends => 'Trends · kitchens and wardrobes';

  @override
  String pcAllOf(String system, int count) {
    return 'All $system · $count';
  }

  @override
  String get pcNothing => 'Nothing found.';

  @override
  String get pcByPhotoTitle => 'Nearest the sample';

  @override
  String pcKg(String kg) {
    return '$kg kg';
  }

  @override
  String get pcNone => 'none';

  @override
  String pcM2(String m2) {
    return '$m2 m²';
  }

  @override
  String get pcTrend => 'trend';

  @override
  String get pcLookSame => 'hardly told apart';

  @override
  String get pcLookClose => 'seen up close';

  @override
  String get pcLookOther => 'another shade';

  @override
  String get pcNoneShelf => 'none on the shelf';

  @override
  String pcShelfEnough(String kg, String m2) {
    return '$kg kg on the shelf — enough for ≈ $m2 m²';
  }

  @override
  String pcPainted(int orders, String m2, int days) {
    return 'Orders: $orders · $m2 m² over $days days';
  }

  @override
  String get pcOnList => 'In use: on the paints list for orders';

  @override
  String get pcNotOnList => 'Not in use yet — «Into use» to take it in orders';

  @override
  String get pcSimilar => 'Similar';

  @override
  String get pcStar => 'Star';

  @override
  String get pcEdit => 'Edit';

  @override
  String get pcTake => 'Into use';

  @override
  String get pcEditTitle => 'The colour\'s card';

  @override
  String get pcAddTitle => 'A new colour';

  @override
  String get pcSystem => 'Colour system';

  @override
  String get pcCode => 'Code';

  @override
  String get pcCodeHint =>
      'RAL 210 50 15, NCS S 2005-Y40R — or empty for one of our own';

  @override
  String get pcName => 'Name';

  @override
  String get pcHex => 'Shade on screen';

  @override
  String get pcHexHint => '#8A9977 — roughly, to find and compare';

  @override
  String get pcHide => 'Hide from the catalogue';

  @override
  String get pcSave => 'Save';

  @override
  String get pcAddSave => 'Add';

  @override
  String get pswWhich => 'Which colour to swap?';

  @override
  String get pswStart => 'No supplier has it — swap the colour';

  @override
  String get pswWayTint => 'tinting';

  @override
  String get pswWayWait => 'waiting for it';

  @override
  String pswWaitUntil(String day) {
    return 'waiting for it until $day';
  }

  @override
  String get pswAsked => 'waiting for the customer\'s yes';

  @override
  String get pswViaWhatsApp => 'on WhatsApp';

  @override
  String get pswViaInPerson => 'in person';

  @override
  String get pswViaPhone => 'on the phone';

  @override
  String pswAgreed(String who, String day, String via) {
    return 'agreed by $who $day $via';
  }

  @override
  String pswTitle(String order) {
    return 'Swapping a colour · order №$order';
  }

  @override
  String pswAskedLine(String target) {
    return 'Offered: $target — waiting for the customer';
  }

  @override
  String get pswHow => 'What we do';

  @override
  String get pswReplace => 'Replace';

  @override
  String get pswTint => 'Tint';

  @override
  String get pswWait => 'Wait for it';

  @override
  String get pswNearest => 'Similar ones there are · nearest first';

  @override
  String get pswTintHint =>
      'Mixed exactly from a base and pigments — at a supplier who tints, or ourselves.';

  @override
  String get pswWaitPick => 'Expected when?';

  @override
  String get pswRule =>
      'Until the customer agrees, the order is not painted. The order keeps both colours and who agreed.';

  @override
  String get pswCancel => 'Drop it';

  @override
  String get pswAgreeWhatsApp => 'Agreed on WhatsApp';

  @override
  String get pswAgreePhone => 'Agreed on the phone';

  @override
  String get pswAsk => 'Ask the customer';

  @override
  String get pswChosen => 'The customer chose';

  @override
  String get pswOffered => 'We offer';

  @override
  String get filmMakerAddButton => 'Maker';

  @override
  String get filmMakerAddTitle => 'A new maker';

  @override
  String get filmMakerAddName => 'The maker\'s name';

  @override
  String get filmMakerAddNameHint => 'As on the roll: Kira Group, Adilet…';

  @override
  String get filmMakerAddWhere => 'Where it is bought';

  @override
  String get filmMakerAddNewSource => 'A new supplier';

  @override
  String get filmMakerAddSourceName => 'Supplier (e.g. Kira · Kostanay)';

  @override
  String get filmMakerAddCatalogueHint =>
      'The catalogue with pictures can be loaded later — the 📎 icon above.';

  @override
  String get filmMakerAddSave => 'Add';

  @override
  String get mdfAddWorker => 'Add a person';

  @override
  String get mdfAddWorkerHint =>
      'Into «Команда», on this post — then pick him here';

  @override
  String get mdfNoWorkers => 'Nobody in «Команда» yet';

  @override
  String mdfMarginUnsure(int count) {
    return 'not exact: unpriced — $count';
  }

  @override
  String mdfMarginShares(String material, String work, String margin) {
    return 'material $material · work $work · margin $margin';
  }

  @override
  String get mdfMarginMaterials => 'Materials';

  @override
  String get mdfMarginQty => 'how much';

  @override
  String get mdfMarginPrice => 'price';

  @override
  String get mdfMarginSum => 'sum';

  @override
  String get mdfMarginNoPrice => 'none';

  @override
  String get mdfMarginSetPrice => 'Set';

  @override
  String get mdfMarginRates => 'Rates';

  @override
  String get mdfMarginNoWork => 'No work booked: stages not ticked or no rates';

  @override
  String get mdfMarginCost => 'Cost';

  @override
  String get mdfMarginEstimateShort =>
      'at today\'s prices, nothing written off yet';

  @override
  String get mdfMarginNotCountedShort => 'power and delivery not counted';

  @override
  String mdfMarginPriceTitle(String title) {
    return 'Price: $title';
  }

  @override
  String get mdfMarginPriceLabel => 'Price a unit, ₸';

  @override
  String get mdfMarginPriceHint =>
      'Film — a metre. Written on the material\'s card.';

  @override
  String get ppOwn => 'A colour of our own';

  @override
  String get ppTheirs => 'This customer painted before';

  @override
  String ppEnough(String enough, String need) {
    return 'enough for ≈ $enough m² · the order needs $need m²';
  }

  @override
  String ppShort(String enough, String need) {
    return 'not enough: the shelf paints ≈ $enough m², the order needs $need m² — order paint or «Замена цвета»';
  }

  @override
  String get ppPickHint => 'Tap a colour — it is chosen at once';

  @override
  String get ppChoose => 'Choose';

  @override
  String get cncpTryThickness => 'thickness, mm';

  @override
  String get cncpViewTop => 'From above';

  @override
  String get cncpView3d => '3D';

  @override
  String get cncp3dFront => 'Front';

  @override
  String get cncp3dSide => 'Side';

  @override
  String get cncp3dTilt => 'Tilted';

  @override
  String get cncp3dHint => 'Turn it with the mouse or a finger';

  @override
  String get cncpSection => 'Section, edge to middle · 1:1';

  @override
  String cncpSectionStats(String from, String to, String deepest, String left) {
    return 'pattern $from–$to mm from the edge · deepest $deepest mm · $left mm left';
  }

  @override
  String get cncpSectionNone => 'No cut at mid-height';

  @override
  String cncpThrough(String deepest, String thickness) {
    return 'Through: the cutter goes $deepest mm into $thickness mm';
  }

  @override
  String cncpThin(String left) {
    return 'Little material left: $left mm';
  }

  @override
  String get cncpTryOn => 'Try on a film or a paint';

  @override
  String get ctoTitle => 'Try-on';

  @override
  String get ctoFilms => 'PVC films';

  @override
  String get ctoPaints => 'Paints';

  @override
  String get ctoSearch => 'Search: oak, soft, 9010';

  @override
  String get ctoAllMakers => 'All';

  @override
  String get ctoAcross => 'Grain across';

  @override
  String get ctoCompare => 'Compare';

  @override
  String get ctoCompareClear => 'Clear comparison';

  @override
  String get ctoCompareFull => 'Up to four looks side by side';

  @override
  String get ctoSave => 'Picture for the customer';

  @override
  String ctoSavedTo(String dir) {
    return 'Picture saved: $dir — drag it into WhatsApp';
  }

  @override
  String get ctoFolder => 'For the customer';

  @override
  String get ctoNote =>
      'On screen the colour may differ a little from the sample';

  @override
  String get ctoBare => 'Bare MDF';

  @override
  String ctoMore(int count) {
    return 'and $count more — narrow the search';
  }

  @override
  String get ctoNoCatalogue => 'The catalogue did not load';

  @override
  String get pcOpenCard => 'The colour\'s card — to look at and change';

  @override
  String get cncpKindPocket => 'Pocket';

  @override
  String cncpLinePocket(String offset) {
    return 'Pocket, $offset mm in';
  }

  @override
  String get cncpPocketHint =>
      'Everything inside is cut to one depth — with a straight or ball-nose cutter';

  @override
  String cncpRidge(String height, String at) {
    return 'A $height mm ridge $at mm from the edge — the passes do not meet: move one or take a wider cutter';
  }

  @override
  String cncpWall(String width, String at) {
    return 'A $width mm wall $at mm from the edge — it may break off';
  }

  @override
  String get cncpSimulate => 'Simulation: the cutter\'s run';

  @override
  String get mdfAddCoating => 'Add a coating:';

  @override
  String get mdfQuickColours => 'or a colour at once:';

  @override
  String get mdfGroupCopy => 'Copy in another colour';

  @override
  String mdfGroupCopyTo(String coating) {
    return 'Copy → $coating';
  }
}
