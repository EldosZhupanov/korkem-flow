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
}
