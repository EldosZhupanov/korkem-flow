// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get appTitle => 'KORKEM Flow';

  @override
  String get filterNoResults => 'Бұл сүзгі бойынша ештеңе жоқ.';

  @override
  String get actionClearHistory => 'Тарихты тазалау';

  @override
  String get actionClearSearch => 'Іздеуді тазалау';

  @override
  String get actionRefresh => 'Жаңарту';

  @override
  String get actionRetry => 'Қайталау';

  @override
  String get actionCancel => 'Болдырмау';

  @override
  String get actionClose => 'Жабу';

  @override
  String get actionClearFilter => 'Сүзгіні тазалау';

  @override
  String get actionFilter => 'Сүзгі';

  @override
  String get actionSelectAll => 'Барлығы';

  @override
  String get errorGeneric => 'Бір нәрсе дұрыс болмады.';

  @override
  String get errorOffline => 'Сервермен байланыс жоқ.';

  @override
  String get outboxQueued => 'Байланыс жоқ. Команда жіберу кезегінде тұр.';

  @override
  String outboxPending(int count) {
    return '$count команда жіберуді күтіп тұр';
  }

  @override
  String get outboxRetry => 'Қазір жіберу';

  @override
  String outboxRejected(String reason) {
    return 'Кезектегі команда қабылданбады: $reason';
  }

  @override
  String get errorNoAccess => 'Бұл бөлімге қолжетімділік жоқ.';

  @override
  String get errorNotFound => 'Табылмады.';

  @override
  String get emptyTitle => 'Мұнда әзірге бос';

  @override
  String get emptyGeneric => 'Жаңа жазбалар осы жерде пайда болады.';

  @override
  String get searchHint => 'Іздеу';

  @override
  String searchNoResults(String query) {
    return '«$query» бойынша ештеңе табылмады';
  }

  @override
  String semanticStatus(String status) {
    return 'Күйі: $status';
  }

  @override
  String get navDeals => 'Мәмілелер';

  @override
  String get navTasks => 'Тапсырмалар';

  @override
  String get navProfile => 'Профиль';

  @override
  String get tasksOverdue => 'Мерзімі өткен';

  @override
  String get tasksToday => 'Бүгін';

  @override
  String get tasksUpcoming => 'Алдағы';

  @override
  String get tasksEmpty => 'Ашық тапсырма жоқ';

  @override
  String get tasksEmptyBody => 'Тағайындалған жұмыс осында көрінеді.';

  @override
  String get taskComplete => 'Аяқтау';

  @override
  String get taskCompleted => 'Тапсырма аяқталды';

  @override
  String taskCompleteFailed(String reason) {
    return 'Тапсырманы аяқтау мүмкін болмады. $reason';
  }

  @override
  String get actionUndo => 'Болдырмау';

  @override
  String get taskProduction => 'Өндіріс';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileAppearance => 'Безендіру';

  @override
  String get profileLanguage => 'Тіл';

  @override
  String get profileVersion => 'Нұсқа';

  @override
  String get themeSystem => 'Жүйелік';

  @override
  String get languageSystem => 'Құрылғы тілі';

  @override
  String get themeLight => 'Жарық';

  @override
  String get themeDark => 'Қараңғы';

  @override
  String get profileServer => 'Сервер';

  @override
  String get taskPriorityHigh => 'Жоғары басымдық';

  @override
  String get authSubtitle => 'KORKEM жұмыс кеңістігіне қосылыңыз';

  @override
  String get authServer => 'Сервер мекенжайы';

  @override
  String get authServerHint => 'korkem.example.kz';

  @override
  String get authEmail => 'Электрондық пошта';

  @override
  String get authPassword => 'Құпия сөз';

  @override
  String get authShowPassword => 'Құпия сөзді көрсету';

  @override
  String get authHidePassword => 'Құпия сөзді жасыру';

  @override
  String get authSignIn => 'Кіру';

  @override
  String get authSignOut => 'Шығу';

  @override
  String get authSignOutConfirm => 'Осы құрылғыдан шығу керек пе?';

  @override
  String get authSignOutBody =>
      'Қайта кіру үшін сервер мекенжайы мен құпия сөз қажет болады.';

  @override
  String get authFieldRequired => 'Міндетті өріс';

  @override
  String get authInvalidServer => 'Мекенжай жарамсыз.';

  @override
  String get claimTitle => 'Алғашқы іске қосу';

  @override
  String get claimSubtitle => 'Компания мен иесінің есептік жазбасын құру';

  @override
  String get claimCode => 'Алғашқы іске қосу коды';

  @override
  String get claimCodeHint => 'Түйін журналындағы 16 таңба';

  @override
  String get claimCodeHelper =>
      'Код түйінді алғаш қосқанда терминалда көрсетіледі';

  @override
  String get claimCompany => 'Компания атауы';

  @override
  String get claimOwnerName => 'Иесінің аты-жөні';

  @override
  String get claimOwnerEmail => 'Иесінің электрондық поштасы';

  @override
  String get claimOwnerPassword => 'Иесінің құпия сөзі';

  @override
  String get claimConfirmPassword => 'Құпия сөзді растау';

  @override
  String get claimPasswordMismatch => 'Құпия сөздер сәйкес келмейді';

  @override
  String get claimLanguage => 'Жүйе тілі';

  @override
  String get claimSubmit => 'Компанияны құру';

  @override
  String get claimAlreadyClaimed =>
      'Бұл түйін бос емес. Иесінен шақыру сұраңыз';

  @override
  String get claimCodeRefused =>
      'Қате код. Ол іске қосу кезінде түйін журналында көрсетілген';

  @override
  String get claimNodeUnconfiguredBanner =>
      'Бұл түйін баптауды күтуде. Компания құрып, оның иесі болыңыз.';

  @override
  String get claimSetupCompanyAction => 'Компанияны баптау';

  @override
  String get claimLangRu => 'Русский';

  @override
  String get claimLangKk => 'Қазақша';

  @override
  String get claimLangEn => 'English';

  @override
  String get adminStatsTitle => 'Сандық әкімші';

  @override
  String get adminStatsSubtitle =>
      'Құндылық дәлелі: адам жалдамай-ақ жұмыс нәтижесі';

  @override
  String get adminStatsPeriodWeek => 'Апта';

  @override
  String get adminStatsPeriodMonth => 'Ай';

  @override
  String get adminStatsPeriodQuarter => '3 ай';

  @override
  String get adminStatsStaleHeroLabel => 'НАЗАР АУДАРЫҢЫЗ: ЕСКІРДІ';

  @override
  String adminStatsStaleHeroText(int count) {
    return '$count өтініш 24 сағаттан астам уақыт бойы жұмысқа берілмеді';
  }

  @override
  String get adminStatsZeroStaleHeroLabel => 'ӨТЕ ЖАҚСЫ НӘТИЖЕ';

  @override
  String adminStatsZeroStaleHeroText(int days) {
    return '$days күн ішінде бірде-бір өтініш жоғалмады';
  }

  @override
  String get adminStatsZeroStaleHeroSub =>
      'Барлық жазылған өтініштер адамға уақытында тапсырылды немесе жабылды';

  @override
  String get adminStatsEmptyTitle => 'Әзірге ештеңе жазылмаған';

  @override
  String get adminStatsEmptyMessage =>
      'Таңдалған кезеңде өтініштер тіркелмеген. Мессенджерлер мен арналардан түскен жаңа хабарламалар осында пайда болады.';

  @override
  String get adminStatsCaught => 'Қабылданған өтініштер';

  @override
  String get adminStatsCaughtHelper => 'Жүйе тіркеген барлық өтініштер';

  @override
  String get adminStatsHandedOver => 'Адамға берілді';

  @override
  String get adminStatsHandedOverHelper => 'Қызметкерлерге тапсырмалар құрылды';

  @override
  String get adminStatsConverted => 'Тапсырысқа айналды';

  @override
  String get adminStatsConvertedHelper => 'Шартқа және төлемге жеткізілді';

  @override
  String get adminStatsDismissed => 'Бас тартылды';

  @override
  String get adminStatsDismissedHelper => 'Спам немесе клиент бас тартуы';

  @override
  String get adminStatsStaleMetric => 'Ескірді (тапсырмасыз)';

  @override
  String get adminStatsStaleMetricHelper =>
      '24 сағаттан астам орындаушысыз тұр';

  @override
  String get adminStatsSummaryTitle => 'Жалдау шешімі үшін қорытынды';

  @override
  String adminStatsSummaryText(int caught, int converted, int stale) {
    return 'Жүйе $caught өтінішті өңдеді. $converted тапсырыс әкелді, $stale назар аударуды талап етеді.';
  }

  @override
  String get adminStatsRetry => 'Қайталау';

  @override
  String get teamTitle => 'Команда';

  @override
  String get teamSubtitle => 'Компания қызметкерлері және олардың лауазымдары';

  @override
  String get teamInviteButton => 'Қызметкерді шақыру';

  @override
  String get teamInviteTitle => 'Қызметкерді шақыру';

  @override
  String get teamInviteSubtitle =>
      'Қолжетімділік үшін лауазымды таңдап, поштаны көрсетіңіз';

  @override
  String get teamEmailLabel => 'Электрондық пошта';

  @override
  String get teamEmailHint => 'worker@company.kz';

  @override
  String get teamEmailError => 'Дұрыс пошта мекенжайын енгізіңіз';

  @override
  String get teamFirstNameLabel => 'Қызметкердің аты';

  @override
  String get teamFirstNameHint => 'Айдос';

  @override
  String get teamPositionLabel => 'Лауазымы';

  @override
  String get teamPositionManager => 'Менеджер';

  @override
  String get teamPositionManagerDesc => 'Сату бөлімі, клиенттер, мәмілелер';

  @override
  String get teamPositionWarehouse => 'Қоймашы';

  @override
  String get teamPositionWarehouseDesc =>
      'Қойма, қалдықтар, материалдарды қабылдау';

  @override
  String get teamPositionAccountant => 'Есепші';

  @override
  String get teamPositionAccountantDesc => 'Шоттар, төлемдер, қаржылық есептер';

  @override
  String get teamPositionShopFloor => 'Цех жұмысшысы';

  @override
  String get teamPositionShopFloorDesc =>
      'Станоктар, ауысымдық тапсырмалар, жұмыс есептері';

  @override
  String get teamPositionMeasurer => 'Өлшеуші';

  @override
  String get teamPositionMeasurerDesc => 'Клиентке барып өлшем мен фото алады';

  @override
  String get teamPositionDesigner => 'Конструктор-дизайнер';

  @override
  String get teamPositionDesignerDesc =>
      'Сызба, спецификация, БАЗИС-тен жүктеу';

  @override
  String get teamPositionShopManager => 'Цех бастығы';

  @override
  String get teamPositionShopManagerDesc =>
      'Жұмысты бөледі және мерзімді қадағалайды';

  @override
  String get teamPositionCutter => 'Кесуші';

  @override
  String get teamPositionCutterDesc => 'ЛДСП және плиталарды кесу';

  @override
  String get teamPositionEdgeBanding => 'Жиектеуші';

  @override
  String get teamPositionEdgeBandingDesc => 'Жиек жабыстыру станогы';

  @override
  String get teamPositionCnc => 'ЧПУ операторы';

  @override
  String get teamPositionCncDesc => 'Бұрғылау және фрезерлеу';

  @override
  String get teamPositionPainter => 'Бояушы';

  @override
  String get teamPositionPainterDesc => 'Бояу және жабын';

  @override
  String get teamPositionAssembler => 'Жинақтаушы';

  @override
  String get teamPositionAssemblerDesc => 'Бұйымды жинау және орау';

  @override
  String get teamPositionInstaller => 'Монтаждаушы';

  @override
  String get teamPositionInstallerDesc => 'Жеткізу және клиентте орнату';

  @override
  String get teamPositionOwner => 'Иесі';

  @override
  String get teamPositionOwnerDesc =>
      'Кәсіпорынды басқаруға толық қолжетімділік';

  @override
  String get teamEmptyTitle => 'Әзірге сіз жалғызсыз';

  @override
  String get teamEmptyMessage =>
      'Тапсырмаларды бөліп, өндірісті бақылау үшін цех, қойма немесе сату бөлімінің қызметкерлерін шақырыңыз.';

  @override
  String get teamInviteSuccess => 'Шақыру жіберілді';

  @override
  String get teamInviteSuccessTitle => 'Қызметкер шақырылды';

  @override
  String teamInviteSuccessDetail(String name, String position) {
    return '$name қызметкері «$position» лауазымымен қосылды';
  }

  @override
  String get teamNextStepTitle => 'Келесі қадам';

  @override
  String get teamPasswordNotSet => 'Құпия сөз орнатылмаған';

  @override
  String get teamPositionsLoading => 'Лауазымдар жүктелуде...';

  @override
  String get teamPositionsLoadError =>
      'Лауазымдар тізімін жүктеу мүмкін болмады';

  @override
  String get teamForbiddenTitle => 'Тек иесі үшін';

  @override
  String get teamForbiddenMessage =>
      'Жаңа қызметкерлерді шақыру және лауазымдарды тағайындау тек компания иесіне ғана қолжетімді.';

  @override
  String get teamSendInvite => 'Шақыруды жіберу';

  @override
  String get teamSectionMembers => 'Қызметкерлер';

  @override
  String get teamChangePositionTitle => 'Қызметін өзгерту';

  @override
  String get teamChangePositionAction => 'Қызметін өзгерту';

  @override
  String get teamSavePosition => 'Лауазымды сақтау';

  @override
  String teamChangePositionSuccess(String name, String position) {
    return '$name қызметкерінің лауазымы «$position» болып өзгертілді';
  }

  @override
  String get teamDeactivateAction => 'Кіруді жабу';

  @override
  String get teamDeactivateDialogTitle => 'Кіруді жабу керек пе?';

  @override
  String teamDeactivateConfirmMessage(String name) {
    return '$name қызметкерінің кіруін жабу керек пе? Қызметкер жүйеге кіру мүмкіндігінен айырылады және барлық ашық сеанстар жабылады.';
  }

  @override
  String get teamDeactivateConfirmButton => 'Кіруді жабу';

  @override
  String teamDeactivateSuccess(int count) {
    return 'Кіру жабылды, аяқталған сеанстар: $count';
  }

  @override
  String get teamReactivateAction => 'Кіруді қайтару';

  @override
  String get teamReactivateDialogTitle => 'Кіруді қайтару керек пе?';

  @override
  String teamReactivateConfirmMessage(String name) {
    return '$name қызметкеріне кіру рұқсатын қайтару керек пе?';
  }

  @override
  String get teamReactivateConfirmButton => 'Кіруді қайтару';

  @override
  String get teamReactivateSuccess => 'Кіру рұқсаты қайтарылды';

  @override
  String get teamStatusDisabled => 'Кіру жабылған';

  @override
  String get teamStatusActive => 'Белсенді';

  @override
  String get teamSectionDisabled => 'Кіруі жабылған қызметкерлер';

  @override
  String get teamCannotModifySelf =>
      'Өз лауазымыңызды өзгертуге немесе өзіңізді өшіруге болмайды';

  @override
  String get settingsTeamTitle => 'Команда және қызметкерлер';

  @override
  String get settingsTeamSubtitle =>
      'Қызметкерлерді шақыру және лауазымдарды таңдау';

  @override
  String get companyDetailsTitle => 'Компания деректемелері';

  @override
  String get companyDetailsSubtitle => 'Мекенжай, БСН және банк деректемелері';

  @override
  String get warehousesSettingsTitle => 'Қоймалар';

  @override
  String get warehousesSettingsSubtitle =>
      'Сақтау орындары және жөнелту қоймасы';

  @override
  String get warehousesTitle => 'Қоймалар';

  @override
  String get warehousesSubtitle =>
      'Сақтау орындары және дайын өнімді жөнелту қоймасы';

  @override
  String get warehousesTipTitle =>
      'Құжаттардағы қойма атауын қалай өзгертуге болады';

  @override
  String get warehousesTipBody =>
      'ERPNext жүйесінде қойма атауын тікелей өзгертуге болмайды. Жөнелтпе құжаттарда түсінікті атау болуы үшін: қажетті атаумен жаңа қойма ашыңыз → оны жөнелту қоймасы етіп белгілеңіз → ағылшынша Finished Goods қоймасын өшіріңіз.';

  @override
  String get warehousesSectionActive => 'Қоймалар';

  @override
  String get warehousesSectionDisabled => 'Өшірілген қоймалар';

  @override
  String get warehousesShippingDefaultBadge => 'Жөнелту қоймасы';

  @override
  String get warehousesStatusDisabled => 'Өшірілген';

  @override
  String warehousesPositionsCount(int count) {
    return '$count позиция';
  }

  @override
  String get warehousesActionSetShippingDefault => 'Жөнелту қоймасы ету';

  @override
  String get warehousesActionDisable => 'Қойманы өшіру';

  @override
  String get warehousesActionEnable => 'Қойманы қосу';

  @override
  String get warehousesCreateButton => 'Жаңа қойма';

  @override
  String get warehousesCreateDialogTitle => 'Жаңа қойма';

  @override
  String get warehousesCreateDialogSubtitle =>
      'Екінші цех, жалға алынған орын, көлік';

  @override
  String get warehousesNameLabel => 'Қойма атауы';

  @override
  String get warehousesNameHint => 'мыс. Материалдар қоймасы';

  @override
  String get warehousesNameError => 'Қойма атауын енгізіңіз';

  @override
  String warehousesCreateSuccess(String name) {
    return '«$name» қоймасы құрылды';
  }

  @override
  String warehousesSetShippingDefaultSuccess(String name) {
    return '«$name» қоймасы жөнелту қоймасы болып тағайындалды';
  }

  @override
  String get warehousesDisableDialogTitle => 'Қойманы өшіру керек пе?';

  @override
  String warehousesDisableDialogMessage(String name) {
    return '«$name» қоймасын өшіру керек пе? Қойма жаңа құжаттарда ұсынылмайды, қалдықтар тарихы сақталады.';
  }

  @override
  String warehousesDisableSuccess(String name) {
    return '«$name» қоймасы өшірілді';
  }

  @override
  String get warehousesEnableDialogTitle => 'Қойманы қосу керек пе?';

  @override
  String warehousesEnableDialogMessage(String name) {
    return '«$name» қоймасын қосу керек пе? Ол қойма құжаттарында қайтадан қолжетімді болады.';
  }

  @override
  String warehousesEnableSuccess(String name) {
    return '«$name» қоймасы қосылды';
  }

  @override
  String get warehousesEmptyTitle => 'Қоймалар табылмады';

  @override
  String get warehousesEmptyMessage => 'Компанияның қоймалар тізімі бос.';

  @override
  String get bazisImportTitle => 'БАЗИС спецификациясы';

  @override
  String get bazisImportSubtitle =>
      'Жүктелімді тексеру және бұйым спецификациясын жасау';

  @override
  String get bazisPickFileAction => 'БАЗИС файлын таңдау';

  @override
  String get bazisChangeFileAction => 'Басқа файл таңдау';

  @override
  String get bazisPickFileHint =>
      'БАЗИС-Мебельщик бағдарламасынан XML-жүктелім (.xml)';

  @override
  String bazisTotalsSummary(
    int products,
    int parts,
    int materials,
    int operations,
  ) {
    return 'Бұйымдар: $products · Бөлшектер: $parts · Материалдар: $materials · Операциялар: $operations';
  }

  @override
  String get bazisCreateSpecificationAction => 'Спецификацияны құру';

  @override
  String get bazisCreatingSpecification => 'Спецификация құрылуда…';

  @override
  String get bazisInspectingFile => 'Жүктелім оқылуда…';

  @override
  String get bazisProductLabel => 'Бұйым';

  @override
  String bazisArticleLabel(String article) {
    return 'Артикул: $article';
  }

  @override
  String bazisOrderLabel(String order) {
    return 'Тапсырыс: $order';
  }

  @override
  String bazisPriceLabel(String price) {
    return 'Бағасы: $price';
  }

  @override
  String bazisQtyLabel(String qty) {
    return '$qty дана';
  }

  @override
  String bazisPartsTab(int count) {
    return 'Бөлшектер ($count)';
  }

  @override
  String bazisMaterialsTab(int count) {
    return 'Материалдар ($count)';
  }

  @override
  String bazisOperationsTab(int count) {
    return 'Операциялар ($count)';
  }

  @override
  String bazisPartBlockLabel(String block) {
    return 'Блок: $block';
  }

  @override
  String bazisPartDimensions(String length, String width, String thickness) {
    return '$length × $width × $thickness мм';
  }

  @override
  String bazisPartEdges(String edges) {
    return 'Жиек: $edges';
  }

  @override
  String bazisMaterialUnitQty(String qty, String unit) {
    return '$qty $unit';
  }

  @override
  String bazisOperationMinutes(String minutes) {
    return '$minutes мин.';
  }

  @override
  String get bazisBomStatusCreated => 'Спецификация құрылды';

  @override
  String get bazisBomStatusUpdated => 'Спецификация нобайы жаңартылды';

  @override
  String get bazisMaterialsWithoutQtyAlert =>
      'Мөлшері есептелмеген материалдар (спецификацияға кірмеді):';

  @override
  String get bazisOperationsAwaitingWorkstationAlert =>
      'Жұмыс орны тағайындалмаған операциялар (анықтамалыққа енгізілді, бірақ бағытқа қосылмады):';

  @override
  String get bazisImportSuccessTitle => 'Спецификация дайын';

  @override
  String get bazisImportAnotherAction => 'Басқа жүктелімді жүктеу';

  @override
  String bazisBomDocLabel(String bom) {
    return 'BOM спецификациясы: $bom';
  }

  @override
  String bazisItemDocLabel(String item) {
    return 'Номенклатура: $item';
  }

  @override
  String get bazisEmptyParts => 'Бұйымда бөлшектер жоқ';

  @override
  String get bazisEmptyMaterials => 'Бұйымда материалдар жоқ';

  @override
  String get bazisEmptyOperations => 'Бұйымда технологиялық операциялар жоқ';

  @override
  String get integrationsTitle => 'Интеграциялар';

  @override
  String get integrationsSubtitle => 'TrustMe және Kaspi Pay кілттері';

  @override
  String get integrationsSecurityNote =>
      'Бұл сіздің компанияңыздың кілттері. Олар серверіңізде шифрланған түрде сақталады және сыртқа берілмейді.';

  @override
  String get trustmeTitle => 'TrustMe';

  @override
  String get trustmeSubtitle => 'Шарттарға электронды қол қою';

  @override
  String get trustmeBinLabel => 'Ұйымның БСН';

  @override
  String get trustmeBinHint => '12 сан';

  @override
  String get trustmeApiTokenLabel => 'API-токен';

  @override
  String get trustmeApiTokenHint => 'Өзгерту үшін жаңа токен енгізіңіз';

  @override
  String get trustmeWebhookSecretLabel => 'Вебхук құпиясы (Webhook Secret)';

  @override
  String get trustmeWebhookSecretHint =>
      'Өзгерту үшін жаңа құпия сөз енгізіңіз';

  @override
  String get kaspiTitle => 'Kaspi Pay';

  @override
  String get kaspiSubtitle => 'Төлем қабылдау және шот ұсыну';

  @override
  String get kaspiMerchantIdLabel => 'Мерчант / Нүкте ID';

  @override
  String get kaspiMerchantIdHint => 'Kaspi Pay-дегі сәйкестендіргіш';

  @override
  String get kaspiApiKeyLabel => 'API-кілт';

  @override
  String get kaspiApiKeyHint => 'Өзгерту үшін жаңа кілт енгізіңіз';

  @override
  String get kaspiWebhookSecretLabel => 'Вебхук құпиясы (Webhook Secret)';

  @override
  String get kaspiWebhookSecretHint => 'Өзгерту үшін жаңа құпия сөз енгізіңіз';

  @override
  String get integrationSecretConfigured => 'Кілт орнатылған';

  @override
  String get integrationSecretNotConfigured => 'Кілт жоқ';

  @override
  String get integrationClearSecretAction => 'Жою';

  @override
  String get integrationSaveAction => 'Сақтау';

  @override
  String get integrationSavedSuccess => 'Баптаулар сақталды';

  @override
  String get integrationClearDialogTitle => 'Кілтті жою керек пе?';

  @override
  String integrationClearDialogMessage(String secretName, String providerName) {
    return '$secretName жойылсын ба? Жаңа кілт енгізілгенше $providerName интеграциясы жұмыс істемейді.';
  }

  @override
  String get integrationClearSuccess => 'Кілт жойылды';

  @override
  String integrationLastStatusLabel(String status) {
    return 'Күйі: $status';
  }

  @override
  String integrationLastErrorLabel(String error) {
    return 'Қате: $error';
  }

  @override
  String integrationLastCheckedLabel(String date) {
    return 'Тексерілді: $date';
  }

  @override
  String get integrationEnableToggle => 'Интеграцияны қосу';

  @override
  String get companyDetailsDocNote =>
      'Деректемелер шарттарды, шоттар мен жүкқұжаттарды жасау үшін қолданылады.';

  @override
  String get companyDetailsSectionGeneral => 'Негізгі деректер';

  @override
  String get companyDetailsNameLabel => 'Компания атауы';

  @override
  String get companyDetailsNameHint => '«Көркем Жиһаз» ЖШС';

  @override
  String get companyDetailsBinLabel => 'БСН';

  @override
  String get companyDetailsBinHint => '12 сан';

  @override
  String get companyDetailsBinError => 'БСН дәл 12 саннан тұруы керек';

  @override
  String get companyDetailsSectionContacts => 'Байланыс және мекенжай';

  @override
  String get companyDetailsCityLabel => 'Қала';

  @override
  String get companyDetailsCityHint => 'Алматы';

  @override
  String get companyDetailsAddressLabel => 'Заңды мекенжайы';

  @override
  String get companyDetailsAddressHint => 'Абай к-сі, 150, 401 кеңсе';

  @override
  String get companyDetailsPhoneLabel => 'Телефон';

  @override
  String get companyDetailsPhoneHint => '+7 777 123 45 67';

  @override
  String get companyDetailsEmailLabel => 'Электрондық пошта';

  @override
  String get companyDetailsEmailHint => 'info@korkem.kz';

  @override
  String get companyDetailsEmailError => 'Дұрыс электрондық поштаны енгізіңіз';

  @override
  String get companyDetailsWebsiteLabel => 'Веб-сайт';

  @override
  String get companyDetailsWebsiteHint => 'korkem.kz';

  @override
  String get companyDetailsReadOnlyNameNotice =>
      'Компания атауы компанияны құру кезінде орнатылады және компания бейінінде өзгереді';

  @override
  String get companyDetailsSectionBank => 'Банк деректемелері';

  @override
  String get companyDetailsBankNameLabel => 'Банк атауы';

  @override
  String get companyDetailsBankNameHint => '«Kaspi Bank» АҚ';

  @override
  String get companyDetailsIbanLabel => 'Есеп айырысу шоты (IBAN)';

  @override
  String get companyDetailsIbanHint => 'KZ...';

  @override
  String get companyDetailsIbanHelper =>
      'Пішімі: KZ және 18 таңба (мысалы, KZ69...)';

  @override
  String get companyDetailsIbanError =>
      'Қазақстанның IBAN-ы KZ-тен басталып, 20 таңбадан тұруы керек';

  @override
  String get companyDetailsBikLabel => 'Банктің БСК (БИК)';

  @override
  String get companyDetailsBikHint => 'CASPKZ2A';

  @override
  String get companyDetailsBikError =>
      'БСК 8-ден 11-ге дейін таңбадан тұруы керек';

  @override
  String get companyDetailsSaveButton => 'Деректемелерді сақтау';

  @override
  String get companyDetailsSaveSuccess => 'Деректемелер сәтті сақталды';

  @override
  String get companyDetailsLoadError =>
      'Компания деректемелерін жүктеу мүмкін болмады';

  @override
  String get itemsTitle => 'Номенклатура және бағалар';

  @override
  String get itemsSubtitle =>
      'Бұйымдар каталогы, өлшем бірліктері және бағалар';

  @override
  String get itemsSearchHint => 'Атауы немесе коды бойынша іздеу';

  @override
  String get itemsEmptyTitle => 'Каталогта әзірше позициялар жоқ';

  @override
  String get itemsEmptyMessage => 'Алғашқы номенклатуралық позицияны қосыңыз';

  @override
  String get itemsAddItem => 'Позиция қосу';

  @override
  String get itemsCreateTitle => 'Жаңа позиция';

  @override
  String get itemsNameLabel => 'Позиция атауы';

  @override
  String get itemsNameHint => 'Екі есікті ашылмалы шкаф';

  @override
  String get itemsNameRequired => 'Позиция атауын енгізіңіз';

  @override
  String get itemsCodeLabel => 'Код / артикул (міндетті емес)';

  @override
  String get itemsCodeHint => 'CAB-01';

  @override
  String get itemsUnitLabel => 'Өлшем бірлігі';

  @override
  String get itemsUnitHint => 'Бірлікті таңдаңыз';

  @override
  String get itemsUnitRequired => 'Өлшем бірлігі міндетті';

  @override
  String get itemsDescriptionLabel => 'Сипаттамасы';

  @override
  String get itemsDescriptionHint => 'Материалдар, фурнитура, ерекшеліктер';

  @override
  String get itemsPriceLabel => 'Сату бағасы (міндетті емес)';

  @override
  String get itemsPriceHint => '0 ₸';

  @override
  String get itemsPriceOnRequest => 'Есептеу бойынша баға';

  @override
  String get itemsPriceLabelShort => 'Бағасы';

  @override
  String get itemsSetPriceTitle => 'Бағаны өзгерту';

  @override
  String get itemsSetPriceAction => 'Бағаны белгілеу';

  @override
  String get itemsPriceRequired => 'Бағаны көрсетіңіз';

  @override
  String get itemsPriceInvalid => 'Қате сома';

  @override
  String get itemsPriceUpdated => 'Баға жаңартылды';

  @override
  String get itemsCreateSuccess => 'Позиция қосылды';

  @override
  String get itemsUnitsLoading => 'Бірліктер жүктелуде...';

  @override
  String get itemsUnitsLoadError => 'Өлшем бірліктерін жүктеу мүмкін болмады';

  @override
  String get itemsCatalogAction => 'Позициялар каталогы';

  @override
  String get navItems => 'Номенклатура';

  @override
  String get settingsEnquiryFlowTitle => 'Өтінімді жүргізу';

  @override
  String get settingsEnquiryFlowSubtitle =>
      'Өтініштен цех тапсырысына дейінгі тізбек';

  @override
  String get enquiryFlowTitle => 'Өтінімді жүргізу';

  @override
  String get enquiryFlowSubtitle => 'Өтініштен цех тапсырысына дейінгі тізбек';

  @override
  String get enquiryFlowStep1 => 'Өтінім';

  @override
  String get enquiryFlowStep2 => 'Өлшеу';

  @override
  String get enquiryFlowStep3 => 'КП';

  @override
  String get enquiryFlowStep4 => 'Тапсырыс';

  @override
  String get enquiryFlowSelectCapture => 'Жүргізу үшін өтінішті таңдаңыз';

  @override
  String get enquiryFlowSpokenText => 'Клиент сөзі бойынша';

  @override
  String get enquiryFlowCustomerName => 'Клиенттің аты';

  @override
  String get enquiryFlowAssignMeasurer => 'Өлшеушіні тағайындау';

  @override
  String get enquiryFlowMeasureDate => 'Өлшеу күні';

  @override
  String get enquiryFlowConvertAction => 'Өтінімді құру';

  @override
  String get enquiryFlowAmbiguousTitle => 'Бірнеше ұқсас клиент табылды';

  @override
  String get enquiryFlowAmbiguousSubtitle =>
      'Бар клиентті таңдаңыз немесе жаңасын құрыңыз:';

  @override
  String get enquiryFlowCreateNewCustomer => 'Жаңа клиент ретінде құру';

  @override
  String get enquiryFlowDimensions => 'Бөлме / бұйым өлшемдері';

  @override
  String get enquiryFlowDimensionsHint => '3200×600, h=2100, сол жақ бұрыш';

  @override
  String get enquiryFlowNotes => 'Ескертпелер мен материалдар';

  @override
  String get enquiryFlowNotesHint => 'МДФ ақ жылтыр, Blum фурнитурасы';

  @override
  String get enquiryFlowAddress => 'Жеткізу және өлшеу мекенжайы';

  @override
  String get enquiryFlowAddressHint => 'Абай к-сі 45, 12 пәт.';

  @override
  String get enquiryFlowCity => 'Қала';

  @override
  String get enquiryFlowCityHint => 'Алматы';

  @override
  String get enquiryFlowRecordMeasurementAction => 'Өлшеу нәтижесін жазу';

  @override
  String get enquiryFlowAttachPhotos => 'Фотосуреттер мен сілтемелер';

  @override
  String get enquiryFlowTakePhoto => 'Суретке түсіру';

  @override
  String get enquiryFlowPickGallery => 'Галереядан';

  @override
  String enquiryFlowPhotosCount(int count) {
    return '$count фото тіркелді';
  }

  @override
  String get enquiryFlowRemovePhoto => 'Фотоны өшіру';

  @override
  String get enquiryFlowPermissionDenied =>
      'Камераға немесе галереяға рұқсат берілмеген. Өлшеу фотосуретін тіркеу үшін құрылғы баптауларында рұқсат беріңіз.';

  @override
  String get enquiryFlowItemCode => 'Позиция атауы';

  @override
  String get enquiryFlowItemCodeHint => 'Ас үй жиһазы';

  @override
  String get enquiryFlowItemDesc => 'Позиция сипаттамасы';

  @override
  String get enquiryFlowItemDescHint => 'МДФ қасбеттері, тас үстел үсті';

  @override
  String get enquiryFlowItemQty => 'Саны';

  @override
  String get enquiryFlowItemRate => 'Бірлік бағасы (₸)';

  @override
  String get enquiryFlowAddItem => '+ Позиция қосу';

  @override
  String get enquiryFlowValidDays => 'Срок действия КП (күн)';

  @override
  String get enquiryFlowDraftProposalAction => 'Ұсыныс жобасын құру';

  @override
  String get enquiryFlowDeliveryDate => 'Дайын болу / жеткізу мерзімі';

  @override
  String get enquiryFlowDeliveryDateRequired =>
      'Тапсырыс құру үшін тапсыру мерзімін көрсетіңіз';

  @override
  String get enquiryFlowPickDeliveryDate => 'Күнді таңдау';

  @override
  String get enquiryFlowAcceptOrderAction => 'Қабылдап, тапсырыс құру';

  @override
  String get enquiryFlowOrderCompleted => 'Тапсырыс өндіріске берілді';

  @override
  String get enquiryFlowViewOrder => 'Тапсырысқа өту';

  @override
  String get enquiryFlowEmptyCaptures => 'Қолжетімді өтініштер жоқ';

  @override
  String get enquiryFlowEmptyCapturesDesc =>
      'Тізбек бойынша жүргізу үшін дауыспен немесе мәтінмен жаңа өтініш құрыңыз.';

  @override
  String get orderDesignSection => 'Дизайн және сызбалар';

  @override
  String get orderDesignStatusNotAssigned => 'Тапсырылмаған';

  @override
  String get orderDesignStatusAssigned => 'Жұмыста';

  @override
  String get orderDesignStatusDelivered => 'Қабылданды';

  @override
  String get orderDesignStatusOverdue => 'Мерзімі өтті';

  @override
  String get orderDesignNoTaskTitle => 'Дизайн әлі тапсырылмаған';

  @override
  String get orderDesignNoTaskBody =>
      'Сызба мен сипаттама цехқа тапсырысты жібермес бұрын қажет.';

  @override
  String get orderDesignAssignAction => 'Дизайнды тапсыру';

  @override
  String get orderDesignDesignerLabel => 'Дизайнер';

  @override
  String get orderDesignDueDateLabel => 'Сызбаны өткізу мерзімі';

  @override
  String get orderDesignDueDateRequired =>
      'Сызбаны тапсыру мерзімін көрсетіңіз';

  @override
  String get orderDesignFilesHeader => 'Қоса берілген файлдар';

  @override
  String get orderDesignNoFilesNotice =>
      'Сызба күтілуде. Қоса берілген файлсыз дизайн қабылданбайды.';

  @override
  String get orderDesignAttachFileAction => 'Сызбаны қосу';

  @override
  String get orderDesignAttachDialogTitle => 'Тапсырысқа сызбаны қосу';

  @override
  String get orderDesignFileNameLabel => 'Сызба файлының атауы';

  @override
  String get orderDesignFileNameHint => 'асүй_сызбасы.dxf';

  @override
  String get orderDesignAttachButton => 'Файлды қосу';

  @override
  String get orderDesignDeliverAction => 'Дизайнды қабылдау';

  @override
  String get orderDesignCompletedNotice =>
      'Дизайн қабылданды, сызбалар тексерілді';

  @override
  String get orderInstallationSection => 'Орнату';

  @override
  String get orderInstallationStatusNotScheduled => 'Тағайындалмаған';

  @override
  String get orderInstallationStatusScheduled => 'Тағайындалды';

  @override
  String get orderInstallationStatusCompleted => 'Орындалды';

  @override
  String get orderInstallationStatusOverdue => 'Мерзімі өтті';

  @override
  String get orderInstallationNoDeliveryNotice =>
      'Алдымен жеткізу, содан кейін орнату. Жиһазсыз келген бригада бір күнді жоғалтады, ал клиент сенімді жоғалтады.';

  @override
  String get orderInstallationReadyToSchedule =>
      'Жиһаз жөнелтілді. Орнату бригадасының баратын күнін белгілеңіз.';

  @override
  String get orderInstallationScheduleAction => 'Орнатуды тағайындау';

  @override
  String get orderInstallationInstallerLabel => 'Орнатушы / Бригада';

  @override
  String get orderInstallationDateLabel => 'Орнату күні';

  @override
  String get orderInstallationDateRequired => 'Орнату күнін көрсетіңіз';

  @override
  String get orderInstallationCompleteAction => 'Орнату орындалды';

  @override
  String get orderInstallationCompleteDialogTitle => 'Орнатуды аяқтау';

  @override
  String get orderInstallationNotesLabel => 'Бригаданың жазбалары';

  @override
  String get orderInstallationNotesHint =>
      'Мысалы: қабырға қисық болып шықты, қосымша элементпен орнаттық';

  @override
  String get orderInstallationCompletedNotice => 'Орнату сәтті аяқталды';

  @override
  String get orderWarrantySection => 'Кепілдік';

  @override
  String get orderWarrantyNotStartedNotice =>
      'Кепілдік жөнелтілгеннен кейін басталады.';

  @override
  String orderWarrantyShippedOn(String date) {
    return 'Жөнелтілді: $date';
  }

  @override
  String get orderWarrantyStatusActive => 'Жарамды';

  @override
  String get orderWarrantyStatusExpired => 'Аяқталды';

  @override
  String get orderWarrantyStatusNoWarranty => 'Кепілдіксіз';

  @override
  String orderWarrantyUntil(String date) {
    return '$date дейін';
  }

  @override
  String orderWarrantyPeriodDays(int days) {
    return '$days күн';
  }

  @override
  String get orderWarrantyClaimAction => 'Рекламация ресімдеу';

  @override
  String get orderWarrantyClaimDialogTitle => 'Рекламация ресімдеу';

  @override
  String get orderWarrantyItemLabel => 'Позиция';

  @override
  String get orderWarrantyComplaintLabel => 'Не болды';

  @override
  String get orderWarrantyComplaintHint =>
      'Ақауды егжей-тегжейлі сипаттаңыз: не бұзылды, қандай жағдайда';

  @override
  String get orderWarrantyComplaintRequired => 'Рекламация себебін сипаттаңыз';

  @override
  String orderWarrantyClaimSuccessNotice(String claim) {
    return 'Рекламация $claim сәтті тіркелді';
  }

  @override
  String get orderInvoicingSection => 'Шот';

  @override
  String get orderInvoicingStatusNotDrafted => 'Шығарылмаған';

  @override
  String get orderInvoicingStatusDrafted => 'Шығарылды';

  @override
  String get orderInvoicingStatusPaid => 'Төленді';

  @override
  String get orderInvoicingOrderNotSubmittedNotice =>
      'Тапсырыс әлі расталмаған. Жоба бойынша шот — бұл ешкім түпкілікті келіспеген нәрсеге арналған шот.';

  @override
  String get orderInvoicingNoDeliveryNotice =>
      'Тапсырыс бойынша ештеңе жөнелтілмеген. Жеткізілмеген жиһазға шот ұсыну — риза клиентпен қарым-қатынасты бұзудың ең жылдам жолы.';

  @override
  String get orderInvoicingCreateAction => 'Шот шығару';

  @override
  String get orderInvoicingNumberLabel => 'Шот нөмірі';

  @override
  String get orderInvoicingTotalLabel => 'Шот сомасы';

  @override
  String orderInvoicingSuccessNotice(String invoice) {
    return '$invoice шоты сәтті жасалды';
  }

  @override
  String get settingsTitle => 'Параметрлер';

  @override
  String get settingsAccount => 'Есептік жазба';

  @override
  String get settingsSignedInAs => 'Сіз кірдіңіз';

  @override
  String get settingsConnection => 'Қосылым';

  @override
  String get settingsLookAndLanguage => 'Безендіру және тіл';

  @override
  String get navDashboard => 'Басты бет';

  @override
  String get dashboardGreeting => 'Бүгін';

  @override
  String get dashboardMyWork => 'Менің жұмысым';

  @override
  String dashboardWorkload(int overdue, int total) {
    return '$total ішінен $overdue мерзімі өткен';
  }

  @override
  String get dashboardAttention => 'Назар аударыңыз';

  @override
  String get dashboardAllClear => 'Қазір сізден ештеңе талап етілмейді';

  @override
  String get dashboardAllClearBody =>
      'Мұнда мерзімі өткен тапсырмалар мен сізді күтіп тұрған шешімдер көрінеді.';

  @override
  String get metricOpenDeals => 'Ашық мәмілелер';

  @override
  String get metricOpenLeads => 'Лидтер';

  @override
  String get metricMyOpenTasks => 'Менің тапсырмаларым';

  @override
  String get metricOverdueTasks => 'Мерзімі өткен';

  @override
  String get metricPendingActions => 'Шешім күтуде';

  @override
  String get metricWorkOrders => 'Өндірісте';

  @override
  String get attentionPendingAction => 'Шешім қажет';

  @override
  String get attentionOverdueTask => 'Мерзімі өткен тапсырма';

  @override
  String get navSales => 'Сатылым';

  @override
  String get navLeads => 'Лидтер';

  @override
  String get navCustomers => 'Клиенттер';

  @override
  String get dealsEmptyAssigned => 'Сізге әзірше ештеңе тағайындалмаған';

  @override
  String get dealsEmptyAssignedBody =>
      'Сіз тек өз мәмілелеріңізді және тағайындалған мәмілелерді көресіз. Басшыдан мәміле тағайындауды сұраңыз.';

  @override
  String get leadsEmpty => 'Лидтер жоқ';

  @override
  String get leadsEmptyBody => 'Жаңа өтініштер осында пайда болады.';

  @override
  String get leadConverted => 'Түрлендірілген';

  @override
  String get customersEmpty => 'Клиенттер жоқ';

  @override
  String get customersEmptyBody =>
      'Ұйымдар бойынша мәміле жасалғаннан кейін осында көрінеді.';

  @override
  String get detailPipeline => 'Воронка';

  @override
  String get detailCommercial => 'Коммерция';

  @override
  String get detailOwnership => 'Жауапкершілік';

  @override
  String get detailCompany => 'Компания';

  @override
  String get fieldStage => 'Кезең';

  @override
  String get fieldValue => 'Сомасы';

  @override
  String get fieldProbability => 'Ықтималдық';

  @override
  String get fieldExpectedClose => 'Күтілетін жабылу';

  @override
  String get fieldNextStep => 'Келесі қадам';

  @override
  String get fieldOwner => 'Жауапты';

  @override
  String get fieldSource => 'Дереккөз';

  @override
  String get fieldTerritory => 'Аймақ';

  @override
  String get fieldIndustry => 'Сала';

  @override
  String get fieldWebsite => 'Сайт';

  @override
  String get fieldEmployees => 'Қызметкерлер';

  @override
  String get fieldRevenue => 'Жылдық айналым';

  @override
  String get fieldOriginLead => 'Лидтен';

  @override
  String get fieldUpdated => 'Жаңартылды';

  @override
  String get actionCall => 'Қоңырау шалу';

  @override
  String get actionEmail => 'Хат';

  @override
  String get actionWhatsApp => 'WhatsApp';

  @override
  String get navApprovals => 'Келісімдер';

  @override
  String get navProduction => 'Өндіріс';

  @override
  String get approvalsEmpty => 'Шешім қажет емес';

  @override
  String get approvalsEmptyBody =>
      'Мұнда агент күтіп тұрған шешімдер көрінеді.';

  @override
  String get approvalApprove => 'Келісу';

  @override
  String get approvalReject => 'Бас тарту';

  @override
  String get approvalApproved => 'Келісілді';

  @override
  String get approvalRejected => 'Бас тартылды';

  @override
  String get approvalRejectDialogTitle => 'Әрекеттен бас тарту';

  @override
  String get approvalRejectReasonHint => 'Бас тарту себебі (міндетті емес)';

  @override
  String get approvalExpires => 'Мерзімі';

  @override
  String get approvalExpired => 'Мерзімі өтті';

  @override
  String get productionEmpty => 'Тапсырыстар жоқ';

  @override
  String get productionEmptyBody =>
      'Мәміле өндіріске өткенде тапсырыстар осында көрінеді.';

  @override
  String get paPending => 'Күтуде';

  @override
  String get paApproved => 'Келісілді';

  @override
  String get paRejected => 'Бас тартылды';

  @override
  String get paExpired => 'Мерзімі өтті';

  @override
  String get woDraft => 'Жоба';

  @override
  String get woSubmitted => 'Расталды';

  @override
  String get woNotStarted => 'Басталмаған';

  @override
  String get woInProcess => 'Жұмыста';

  @override
  String get woStockReserved => 'Материал брондалды';

  @override
  String get woStockPartial => 'Материал ішінара';

  @override
  String get woCompleted => 'Аяқталды';

  @override
  String get woStopped => 'Тоқтатылды';

  @override
  String get woClosed => 'Жабылды';

  @override
  String get woCancelled => 'Болдырылмады';

  @override
  String get navQuotes => 'Шоттар';

  @override
  String get navWarehouse => 'Қойма';

  @override
  String get navOperations => 'Операциялар';

  @override
  String get quotesEmpty => 'Шоттар жоқ';

  @override
  String get quotesEmptyBody =>
      'Мәміле бойынша шот жасалғанда осында көрінеді.';

  @override
  String get warehouseEmpty => 'Позициялар жоқ';

  @override
  String get warehouseEmptyBody => 'Қойма позициялары осында көрінеді.';

  @override
  String get fieldValidTill => 'Жарамды';

  @override
  String get fieldReserved => 'Резерв';

  @override
  String get warehouseNoStock => 'Ешбір қоймада жоқ';

  @override
  String get quoteExpiredSoon => 'Мерзімі бітеді';

  @override
  String get qDraft => 'Жоба';

  @override
  String get qOpen => 'Ашық';

  @override
  String get qReplied => 'Жауап бар';

  @override
  String get qPartiallyOrdered => 'Ішінара тапсырыс';

  @override
  String get qOrdered => 'Тапсырыс берілді';

  @override
  String get qLost => 'Жоғалтылды';

  @override
  String get qCancelled => 'Болдырылмады';

  @override
  String get qExpired => 'Мерзімі өтті';

  @override
  String get navNotifications => 'Хабарламалар';

  @override
  String get notificationsEmpty => 'Әзірге ештеңе жіберілмеді.';

  @override
  String get notificationsEmptyBody =>
      'Тағайындаулар, аталымдар және ескертулер осында көрінеді.';

  @override
  String get notificationsMarkAllRead => 'Барлығын белгілеу';

  @override
  String get navAssistant => 'Көмекші';

  @override
  String get navMenu => 'Мәзір';

  @override
  String get chatNew => 'Жаңа чат';

  @override
  String get chatRecent => 'Соңғылары';

  @override
  String get chatGreeting => 'Немен көмектесе аламын?';

  @override
  String get chatPlaceholder => 'KORKEM-нен кез келген нәрсені сұраңыз…';

  @override
  String get chatSend => 'Жіберу';

  @override
  String get chatDictate => 'Дауыспен енгізу';

  @override
  String get chatDictateStop => 'Дауысты тоқтату';

  @override
  String get chatDictateUnavailable =>
      'Микрофон қолжетімсіз. Телефон параметрлерінде рұқсат беріңіз немесе мәтінмен жазыңыз.';

  @override
  String get chatLocalMode => 'Жергілікті режим · KORKEM деректері';

  @override
  String get chatThinking => 'Ойланудамын';

  @override
  String get chatEmptyThreads => 'Әзірге әңгіме жоқ';

  @override
  String get chatEmptyThreadsBody =>
      'Мұнда ассистентпен сұхбаттарыңыз пайда болады.';

  @override
  String get chatOpen => 'Ашу';

  @override
  String get chatNotConnected =>
      'Мен әзірге тілдік модельге қосылмағанмын, оған жауап бере алмаймын. KORKEM деректерін көрсете аламын:';

  @override
  String get chatSuggestDeals => 'Мәмілелерімді көрсет';

  @override
  String get chatSuggestAttention => 'Не назар аударуды қажет етеді?';

  @override
  String get chatSuggestOverdue => 'Не мерзімі өтті?';

  @override
  String get chatSuggestProduction => 'Қазір өндірісте не бар?';

  @override
  String get chatCardOpenDeals => 'Ашық мәмілелер';

  @override
  String get chatCardAttention => 'Назар аударуды қажет етеді';

  @override
  String get chatCardTasks => 'Менің тапсырмаларым';

  @override
  String get chatCardProduction => 'Өндірісте';

  @override
  String get chatHistory => 'Тарих';

  @override
  String get chatToday => 'Бүгін';

  @override
  String get chatYesterday => 'Кеше';

  @override
  String get chatEarlier => 'Бұрынырақ';

  @override
  String get chatScrollToEnd => 'Соңғы хабарламаға';

  @override
  String get chatWorkspace => 'AI Workspace';

  @override
  String get chatRename => 'Атын өзгерту';

  @override
  String get chatDelete => 'Жою';

  @override
  String get chatDeleteTitle => 'Әңгімені жою керек пе?';

  @override
  String chatDeleteBody(String title) {
    return '«$title» осы құрылғыдан жойылады. Қайтару мүмкін емес.';
  }

  @override
  String get chatRenameTitle => 'Әңгіме атауы';

  @override
  String get navClients => 'Клиенттер';

  @override
  String get chatErrorNotConfigured =>
      'ЖИ серверде әлі бапталмаған. KORKEM әкімшісіне хабарласыңыз.';

  @override
  String get chatErrorOffline =>
      'KORKEM-ге қосыла алмадым. Байланысты тексеріңіз.';

  @override
  String get chatErrorRefused => 'Бұл сұрауға рұқсатыңыз жеткіліксіз.';

  @override
  String get chatErrorUnknown => 'Жауап бере алмадым. Қайталап көріңіз.';

  @override
  String get chatWorking => 'Жұмыс істеп жатырмын…';

  @override
  String get chatToolDeals => 'Мәмілелерді іздеп жатырмын…';

  @override
  String get chatToolLeads => 'Лидтерді іздеп жатырмын…';

  @override
  String get chatToolCustomers => 'Клиенттерді іздеп жатырмын…';

  @override
  String get chatToolTasks => 'Тапсырмаларды іздеп жатырмын…';

  @override
  String get chatToolProduction => 'Өндірісті қарап жатырмын…';

  @override
  String get chatToolOrders => 'Тапсырыстарды қараймын…';

  @override
  String get chatToolShortage => 'Материал тапшылығын есептеймін…';

  @override
  String get chatToolStock => 'Қалдықтарды тексеремін…';

  @override
  String get chatToolProcurement => 'Сатып алу өтінімін дайындаймын…';

  @override
  String get chatToolProfile => 'Профиліңізді тексеріп жатырмын…';

  @override
  String get chatErrorProviderUnavailable =>
      'ЖИ қызметі жауап бермей тұр. Сәлден соң қайталаңыз.';

  @override
  String get chatErrorRateLimited =>
      'ЖИ қызметі бос емес. Сәл күтіп, қайталаңыз.';

  @override
  String get chatErrorToolError =>
      'KORKEM-де бұл әрекетті орындау мүмкін болмады.';

  @override
  String get chatConfirmTitle => 'Әрекетті растаңыз';

  @override
  String get chatConfirmBody =>
      'Көмекші өзгеріс енгізгісі келеді. Әзірге ештеңе болған жоқ.';

  @override
  String get chatConfirmApprove => 'Растау';

  @override
  String get chatConfirmReject => 'Болдырмау';

  @override
  String get chatConfirmRejected => 'Болдырылмады. Ештеңе өзгерген жоқ.';

  @override
  String get chatFallbackBadge => 'ЖИ емес — тікелей дерек';

  @override
  String get chatErrorTimedOut =>
      'ЖИ қызметі тым ұзақ жауап берді. Қайталап көріңіз.';

  @override
  String get chatErrorModelNotFound =>
      'Таңдалған модель қолжетімсіз. ЖИ параметрлерінен басқасын таңдаңыз.';

  @override
  String get chatErrorContextTooLarge =>
      'Бұл диалог тым ұзын. Жаңасын бастаңыз.';

  @override
  String get aiSettingsTitle => 'ЖИ провайдерлері';

  @override
  String get aiSettingsSubtitle => 'Қай ЖИ жауап беретінін таңдап, қосыңыз.';

  @override
  String get aiSettingsDefault => 'Әдепкі';

  @override
  String get aiSettingsMakeDefault => 'Негізгі ету';

  @override
  String get aiSettingsNotConfigured => 'Бапталмаған';

  @override
  String get aiSettingsConnected => 'Қосылды';

  @override
  String get aiSettingsTestFailed => 'Қосылу сәтсіз';

  @override
  String get aiSettingsTest => 'Қосылымды тексеру';

  @override
  String get aiSettingsSave => 'Сақтау';

  @override
  String get aiSettingsApiKey => 'API кілті';

  @override
  String get aiSettingsApiKeyStored =>
      'Кілт сақталған. Өзгертпеу үшін бос қалдырыңыз.';

  @override
  String get aiSettingsModel => 'Модель';

  @override
  String get aiSettingsBaseUrl => 'Негізгі URL';

  @override
  String get aiSettingsKeyNeverLeaves =>
      'Кілттер KORKEM серверінде сақталады және бұл құрылғыға жіберілмейді.';

  @override
  String get aiSettingsCapabilities => 'Мүмкіндіктер';

  @override
  String get aiSettingsLocalNoKey =>
      'Жергілікті жұмыс істейді — кілт қажет емес.';

  @override
  String get channelsTitle => 'Чаттар';

  @override
  String get channelsSubtitle =>
      'Telegram және WhatsApp боттарын қосыңыз және екінші жақта кім екенін көрсетіңіз.';

  @override
  String get channelsSecretsNote =>
      'Токендер KORKEM серверінде сақталады және бұл құрылғыға берілмейді.';

  @override
  String get channelsStateNotConfigured => 'Бапталмаған';

  @override
  String get channelsStateDisabled => 'Өшірулі';

  @override
  String get channelsStateReady => 'Дайын';

  @override
  String get channelsTest => 'Байланысты тексеру';

  @override
  String get channelsTestOk => 'Байланыс бар';

  @override
  String get channelsTestFailed => 'Байланыс жоқ';

  @override
  String get channelsEnabled => 'Қосулы';

  @override
  String get channelsSave => 'Сақтау';

  @override
  String get channelsStored => 'Сақталған. Өзгертпеу үшін бос қалдырыңыз.';

  @override
  String get channelsBotToken => 'Бот токені';

  @override
  String get channelsWebhookSecret => 'Вебхук құпиясы';

  @override
  String get channelsAccessToken => 'Қатынау токені';

  @override
  String get channelsPhoneNumberId => 'Нөмір ID-і';

  @override
  String get channelsVerifyToken => 'Тексеру токені';

  @override
  String get channelsWebhookUrl => 'Вебхук URL-і';

  @override
  String get channelsIdentities => 'Кім жазады';

  @override
  String get channelsIdentityUnlinked => 'Байланыспаған';

  @override
  String get channelsLink => 'Байланыстыру';

  @override
  String get channelsUnlink => 'Ажырату';

  @override
  String get channelsUser => 'KORKEM пайдаланушысы';

  @override
  String get channelsIdentitiesEmpty => 'Ботқа әлі ешкім жазған жоқ.';

  @override
  String get channelsStateConnected => 'Байланыс бар';

  @override
  String get channelsStateInvalid => 'Тіркелгі деректері қабылданбады';

  @override
  String get channelsStateWebhookError => 'Вебхук мәселесі';

  @override
  String get channelsStateUnavailable => 'Провайдер қолжетімсіз';

  @override
  String get channelsConfigureWebhook => 'Вебхукты баптау';

  @override
  String get channelsRemoveWebhook => 'Вебхукты алып тастау';

  @override
  String get channelsWebhookManual =>
      'Бұл мекенжайды провайдер панеліне қойыңыз.';

  @override
  String get channelsLastChecked => 'Соңғы тексеру';

  @override
  String get channelsPending => 'Провайдерде күтуде';

  @override
  String get notificationsTitle => 'Хабарламалар';

  @override
  String get notificationsSubtitle =>
      'Жүйе адамдарға не хабарлады және не жеткізілмеді.';

  @override
  String get notificationsRetry => 'Қайталау';

  @override
  String get notificationsRetryAll => 'Барлығын қайталау';

  @override
  String get notificationsCancel => 'Болдырмау';

  @override
  String get notificationsAttempts => 'Әрекеттер';

  @override
  String get notificationsNextAttempt => 'Келесі әрекет';

  @override
  String get notificationsFilterAll => 'Барлығы';

  @override
  String get instructionsTitle => 'Тапсырмалар';

  @override
  String get instructionsSubtitle => 'Кімнен сұралды және не жауап берді.';

  @override
  String get instructionsEmpty => 'Әзірге тапсырма жоқ.';

  @override
  String get instructionsAnsweredIn => 'Жауап берді';

  @override
  String get channelsSendTest => 'Тест хабарлама жіберу';

  @override
  String get channelsDisconnect => 'Ажырату';

  @override
  String get channelsLastInbound => 'Соңғы кіріс';

  @override
  String get channelsLastOutbound => 'Соңғы шығыс';

  @override
  String get channelsFailedDeliveries => 'Жеткізілмеді';

  @override
  String get channelsPendingRetries => 'Қайталауды күтуде';

  @override
  String get channelsStateForbidden => 'Провайдер бұғаттады';

  @override
  String get channelsStateRateLimited => 'Жиілік шектеуі';

  @override
  String get ordersTitle => 'Тапсырыстар';

  @override
  String get ordersEmpty => 'Әзірге тапсырыстар жоқ';

  @override
  String get ordersEmptyBody =>
      'Жаңа тұтынушы тапсырыстары осында пайда болады.';

  @override
  String get ordersActionStartProduction => 'Өндірісті бастау';

  @override
  String get ordersStartingProduction => 'Өндіріс іске қосылуда...';

  @override
  String ordersStartSuccess(String id) {
    return '$id бойынша өндіріс басталды';
  }

  @override
  String ordersTopUpSuccess(String id) {
    return '$id бойынша материал берілді';
  }

  @override
  String ordersAlreadyStarted(String id) {
    return '$id бойынша өндіріс әлдеқашан басталған';
  }

  @override
  String ordersNothingToStart(String id) {
    return '$id тапсырысы бойынша іске қосатын ештеңе жоқ';
  }

  @override
  String get ordersBlockedTitle => 'Материалдар жеткіліксіз';

  @override
  String get ordersBlockedBody =>
      'Өндірісті бастау үшін қоймада материалдар жетіспейді:';

  @override
  String ordersBlockedSummary(String id) {
    return '$id іске қосылмады: қоймада материалдар жеткіліксіз';
  }

  @override
  String ordersDeliveredProgress(String percent) {
    return '$percent% жөнелтілді';
  }

  @override
  String ordersDeliveryDate(String date) {
    return 'Жеткізу: $date';
  }

  @override
  String ordersTransactionDate(String date) {
    return 'Күні: $date';
  }

  @override
  String get soDraft => 'Жоба';

  @override
  String get soToDeliverAndBill => 'Жөнелту және төлем күтілуде';

  @override
  String get soToBill => 'Төлем күтілуде';

  @override
  String get soToDeliver => 'Жөнелту күтілуде';

  @override
  String get soCompleted => 'Аяқталды';

  @override
  String get soCancelled => 'Бас тартылды';

  @override
  String get soClosed => 'Жабылды';

  @override
  String get soOnHold => 'Кідіртілген';

  @override
  String get todayTitle => 'Назар аударуды қажет етеді';

  @override
  String get todaySubtitle => 'Өндіріс пен сату тізбегін күнделікті бақылау';

  @override
  String get todayActiveOrders => 'Белсенді тапсырыстар';

  @override
  String todayLateOrders(int count) {
    return '$count мерзімі өткен';
  }

  @override
  String get todayOrdersAllOnTrack => 'Барлығы кестеде';

  @override
  String get todayInProduction => 'Өндірісте';

  @override
  String todayWorkOrdersCount(int count) {
    return '$count тапсырма';
  }

  @override
  String get todayProductionAllOnTrack => 'Кідіріссіз';

  @override
  String get todayApprovals => 'Растауды күтуде';

  @override
  String todayApprovalsCount(int count) {
    return '$count шешім';
  }

  @override
  String get todayApprovalsNone => 'Барлығы келісілді';

  @override
  String get todayStockDeficit => 'Қойма тапшылығы';

  @override
  String todayDeficitCount(int count) {
    return '$count позиция нөлден төмен';
  }

  @override
  String get todayDeficitNone => 'Тапшылық жоқ';

  @override
  String get todayAttentionTitle => 'Назар аударуды қажет етеді';

  @override
  String get todayAllClearTitle => 'Барлығы дұрыс';

  @override
  String get todayAllClearSubtitle =>
      'Өндірісте сыни кідірістер мен тапшылық жоқ';

  @override
  String get todayQuickNav => 'Жылдам өту';

  @override
  String get todayTileError => 'Жүктеу мүмкін болмады';

  @override
  String get todayUnassignedCapturesTitle => 'Жұмысқа берілмеген';

  @override
  String get todayUnassignedCapturesEmpty =>
      'Ештеңе жоғалған жоқ: барлық өтініштер жұмысқа берілді';

  @override
  String get todayOverdueTasksTitle => 'Мерзімі өткен тапсырмалар';

  @override
  String get todayOverdueTasksEmpty =>
      'Барлығы уақытында: мерзімі өткен өлшеу, дизайн немесе монтаж жоқ';

  @override
  String get todayOrdersWithoutDesignTitle => 'Дизайнсыз тапсырыстар';

  @override
  String get todayOrdersWithoutDesignEmpty =>
      'Барлық тапсырыстар бойынша дизайн тағайындалды';

  @override
  String get todayDeliveredNotInvoicedTitle => 'Шотсыз жөнелтілгендер';

  @override
  String get todayDeliveredNotInvoicedEmpty =>
      'Барлық жөнелтілімдер шоттармен жабылған';

  @override
  String get todayAllClearHeadline => 'Барлығы бақылауда';

  @override
  String get todayAllClearDescription =>
      'Барлық өтініштер тапсырылды, мерзімі өткендер жоқ, барлық тапсырыстар бойынша дизайн тағайындалды және жөнелтілімдер шоттармен жабылды.';

  @override
  String todayOverdueWasDue(String date) {
    return 'Мерзімі өтті: $date';
  }

  @override
  String todayDeliveryDue(String date) {
    return 'Тапсыру мерзімі: $date';
  }

  @override
  String todayBilledProgress(String delivered, String billed) {
    return '$delivered% жөнелтілді, $billed% шот шығарылды';
  }

  @override
  String get orderProductionSection => 'Өндіріс';

  @override
  String get orderNoProductionTitle => 'Өндіріс әлі басталған жоқ';

  @override
  String get orderNoProductionBody =>
      'Бұл тапсырыс бойынша бірде-бір тапсырма жоқ. Тапсырыс расталған соң өндірісті бастаңыз.';

  @override
  String get workOrderLinkedSalesOrder => 'Байланысты тапсырыс';

  @override
  String get workOrderNoLinkedSalesOrder => 'Тапсырыс байланыстырылмаған';

  @override
  String workOrderPlannedEnd(String date) {
    return 'Жоспарланған аяқталуы: $date';
  }

  @override
  String workOrderActualEnd(String date) {
    return 'Нақты аяқталуы: $date';
  }

  @override
  String workOrderBomNo(String bom) {
    return 'Ерекшелік: $bom';
  }

  @override
  String workOrderWipWarehouse(String warehouse) {
    return 'Аяқталмаған өндіріс қоймасы: $warehouse';
  }

  @override
  String workOrderFgWarehouse(String warehouse) {
    return 'Дайын өнім қоймасы: $warehouse';
  }

  @override
  String workOrderProducedProgress(String produced, String qty) {
    return 'Өндірілгені: $produced / $qty';
  }

  @override
  String get workOrderOperationsSection => 'Операциялар';

  @override
  String get workOrderNoOperationsTitle => 'Операциялар жоқ';

  @override
  String get workOrderNoOperationsBody =>
      'Бұл өндірістік тапсырмада операциялар көрсетілмеген.';

  @override
  String workOrderOperationSequence(int sequence) {
    return '№ $sequence';
  }

  @override
  String workOrderOperationWorkstation(String workstation) {
    return 'Жұмыс орны: $workstation';
  }

  @override
  String workOrderOperationCompleted(String qty) {
    return 'Орындалды: $qty';
  }

  @override
  String workOrderOperationScrap(String qty) {
    return 'Ақау: $qty';
  }

  @override
  String workOrderOperationTime(int minutes) {
    return 'Жоспар: $minutes мин';
  }

  @override
  String get opPending => 'Күтілуде';

  @override
  String get opInProgress => 'Орындалуда';

  @override
  String get opCompleted => 'Аяқталды';

  @override
  String get opClosed => 'Жабылды';

  @override
  String get opCancelled => 'Бас тартылды';

  @override
  String get stockBalancesSection => 'Қоймалар бойынша қалдықтар';

  @override
  String get stockSummarySection => 'Барлық қоймалар бойынша жиынтық';

  @override
  String get stockActualQty => 'Нақты қалдық';

  @override
  String get stockReservedQty => 'Резервте';

  @override
  String get stockProjectedQty => 'Болжам';

  @override
  String get stockDeficitAlert => 'Қоймада тапшылық';

  @override
  String get stockNoBalancesTitle => 'Қоймаларда жоқ';

  @override
  String get stockNoBalancesBody => 'Позиция компанияның ешбір қоймасында жоқ.';

  @override
  String get warehouseActionOpen => 'Ашу';

  @override
  String get outboxTitle => 'Командалар кезегі';

  @override
  String get outboxEmptyTitle => 'Барлық командалар жіберілді';

  @override
  String get outboxEmptyBody =>
      'Күтудегі немесе қабылданбаған командалар жоқ. Байланыс үзілгенде жаңа әрекеттер осында сақталады.';

  @override
  String outboxPendingSection(int count) {
    return 'Жіберуді күтуде ($count)';
  }

  @override
  String outboxRejectedSection(int count) {
    return 'Қабылданбады ($count)';
  }

  @override
  String outboxRejectedPending(int count) {
    return 'Назар аударуды қажет етеді: $count';
  }

  @override
  String get outboxDismissRejected => 'Түсінікті, алып тастау';

  @override
  String get outboxDismissAll => 'Барлығын алып тастау';

  @override
  String outboxCommandStartProduction(String order) {
    return '$order бойынша өндірісті бастау';
  }

  @override
  String outboxCommandCompleteOperation(String operation) {
    return 'Операция бойынша есеп: $operation';
  }

  @override
  String outboxCommandReceiveReceipt(String order) {
    return '$order бойынша қабылдау';
  }

  @override
  String outboxCommandCreatePurchaseOrder(String request) {
    return '$request бойынша тапсырыс';
  }

  @override
  String outboxCommandCreateDelivery(String order) {
    return '$order бойынша жөнелту';
  }

  @override
  String outboxCommandGeneric(String path) {
    return 'Команда: $path';
  }

  @override
  String outboxParamItem(String item) {
    return 'Позиция: $item';
  }

  @override
  String outboxParamSupplier(String supplier) {
    return 'Жеткізуші: $supplier';
  }

  @override
  String outboxParamWorkOrder(String workOrder) {
    return 'Тапсырма: $workOrder';
  }

  @override
  String outboxParamCompletedQty(String qty) {
    return 'Дайын: $qty';
  }

  @override
  String outboxParamScrapQty(String qty) {
    return 'Ақау: $qty';
  }

  @override
  String get todayOutboxTitle => 'Жіберілмеген';

  @override
  String get todayOutboxAllSent => 'Барлығы жіберілді';

  @override
  String get orderDeliveriesSection => 'Жөнелтілімдер';

  @override
  String get orderNoDeliveriesTitle => 'Әлі жөнелтілімдер болған жоқ';

  @override
  String get orderNoDeliveriesBody =>
      'Тауарлар жөнелтілгенде мұнда жүкқұжаттар пайда болады.';

  @override
  String get searchTitle => 'Іздеу';

  @override
  String get searchPlaceholder => 'Тапсырыс, тұтынушы, материал...';

  @override
  String get searchEmptyPromptTitle => 'Барлық жүйе бойынша іздеу';

  @override
  String get searchEmptyPromptBody =>
      'Тапсырыс нөмірін, тұтынушы атын, өндіріс тапсырмасын немесе материал кодын енгізіңіз.';

  @override
  String get searchNoResultsTitle => 'Ештеңе табылмады';

  @override
  String searchNoResultsBody(String query) {
    return '«$query» сұранысы бойынша ештеңе табылмады.';
  }

  @override
  String searchSectionOrders(int count) {
    return 'Тапсырыстар ($count)';
  }

  @override
  String searchSectionWorkOrders(int count) {
    return 'Тапсырмалар ($count)';
  }

  @override
  String searchSectionStock(int count) {
    return 'Қойма ($count)';
  }

  @override
  String searchSectionError(String section) {
    return 'Бөлімді жүктеу сәтсіз аяқталды: $section';
  }

  @override
  String get searchNavTooltip => 'Іздеу';

  @override
  String get ordersSelectPromptTitle => 'Тапсырысты таңдаңыз';

  @override
  String get ordersSelectPromptBody =>
      'Параметрлерін, күйін, өндіріс тапсырмаларын және жөнелтілімдерін көру үшін сол жақтағы тізімнен тапсырысты таңдаңыз.';

  @override
  String get productionSelectPromptTitle => 'Тапсырманы таңдаңыз';

  @override
  String get productionSelectPromptBody =>
      'Параметрлері мен технологиялық операцияларын көру үшін тізімнен тапсырманы таңдаңыз.';

  @override
  String get warehouseSelectPromptTitle => 'Позицияны таңдаңыз';

  @override
  String get warehouseSelectPromptBody =>
      'Қойма қалдықтары мен параметрлерді көру үшін тізімнен позицияны таңдаңыз.';

  @override
  String get completeOperationAction => 'Жабу';

  @override
  String get completeOperationTitle => 'Операцияны аяқтау';

  @override
  String get completeOperationQtyLabel => 'Дайын өнім';

  @override
  String get completeOperationScrapQtyLabel => 'Ақау';

  @override
  String completeOperationSuccess(String operation) {
    return '«$operation» операциясы аяқталды';
  }

  @override
  String get completeOperationAlreadyComplete => 'Операция бұрын аяқталған';

  @override
  String get completeOperationInvalidQty => 'Дұрыс теріс емес санды енгізіңіз';

  @override
  String get completeOperationBlockedTitle => 'Операцияны аяқтау мүмкін емес';

  @override
  String get ordersActionCreateDelivery => 'Жөнелту құру';

  @override
  String orderDeliverySuccess(String note) {
    return '$note жөнелтілімі жасалды';
  }

  @override
  String orderDeliveryAdjustedSuccess(String note) {
    return 'Қоймадағы бар тауар бойынша ішінара жөнелту $note жасалды';
  }

  @override
  String get orderAlreadyDelivered => 'Тапсырыс толық жөнелтілген';

  @override
  String get orderNothingShippable => 'Қоймада жөнелтуге дайын тауар жоқ';

  @override
  String get orderDeliveryBlockedTitle => 'Жөнелтуді жасау мүмкін емес';

  @override
  String get warehouseActionReceive => 'Жеткізілімді қабылдау';

  @override
  String get receiveDeliveryDialogTitle => 'Жеткізілімді қабылдау';

  @override
  String get receivePurchaseOrderFieldLabel => 'Жеткізушіге тапсырыс нөмірі';

  @override
  String get receivePurchaseOrderFieldHint => 'мыс. PUR-ORD-2026-00001';

  @override
  String receiveSuccess(String receipt) {
    return '$receipt түсімі қабылданды';
  }

  @override
  String get receiveNothingOutstanding =>
      'Осы тапсырыс бойынша барлық тауарлар қабылданған';

  @override
  String get receiveBlockedTitle => 'Жеткізілімді қабылдау мүмкін емес';

  @override
  String get warehouseActionPurchaseOrder => 'Сатып алуды жасау';

  @override
  String get createPurchaseOrderDialogTitle => 'Жеткізушіге тапсырыс жасау';

  @override
  String get materialRequestFieldLabel => 'Материалдарға сұраныс нөмірі';

  @override
  String get materialRequestFieldHint => 'мыс. MAT-MR-2026-00001';

  @override
  String get supplierFieldLabel => 'Жеткізуші (міндетті емес)';

  @override
  String purchaseOrderSuccess(String order) {
    return '$order жеткізушіге тапсырысы жасалды';
  }

  @override
  String get purchaseOrderBlockedTitle =>
      'Жеткізушіге тапсырыс жасау мүмкін емес';

  @override
  String get receiveNoOrdersTitle => 'Күтілетін жеткізілімдер жоқ';

  @override
  String get receiveNoOrdersBody =>
      'Жеткізушілерге барлық тапсырыстар қабылданған немесе белсенді тапсырыстар жоқ.';

  @override
  String get orderableNoRequestsTitle => 'Материалдарға сұраныстар жоқ';

  @override
  String get orderableNoRequestsBody =>
      'Материалдарды сатып алуға барлық сұраныстар өңделген.';

  @override
  String materialRequestNeededDate(String date) {
    return 'Қажеттілік күні: $date';
  }

  @override
  String purchaseOrderExpectedDate(String date) {
    return 'Күтілетін күн: $date';
  }

  @override
  String get workstationsTitle => 'Жұмыс орындары';

  @override
  String get workstationsSubtitle => 'Станоктар бойынша операциялар кезегі';

  @override
  String get workstationsEmptyTitle => 'Белсенді тапсырмалар жоқ';

  @override
  String get workstationsEmptyBody =>
      'Барлық станоктар бос, аяқталмаған операциялар жоқ.';

  @override
  String get stationQueueEmptyTitle => 'Бұл орында барлығы жасалды';

  @override
  String get stationQueueEmptyBody =>
      'Бұл станокта күтіп тұрған операциялар жоқ.';

  @override
  String workstationWaitingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count операция',
      one: '$count операция',
    );
    return '$_temp0';
  }

  @override
  String workstationDueOn(String date) {
    return 'Мерзімі: $date';
  }

  @override
  String workstationItemLabel(String item) {
    return 'Бұйым: $item';
  }

  @override
  String workstationQtyLabel(String qty) {
    return 'Саны: $qty';
  }

  @override
  String workstationDuration(String minutes) {
    return '$minutes мин';
  }

  @override
  String updateAvailable(String version) {
    return '$version жаңартуы қолжетімді';
  }

  @override
  String get updateInstall => 'Жаңарту';

  @override
  String get aiCascadeTitle => 'Сұрау тәртібі';

  @override
  String get aiCascadeSubtitle =>
      'Жоғарыдан төмен сұраймыз: біреуінің шегі бітсе, келесісі жауап береді.';

  @override
  String get aiCascadeFree => 'тегін';
}
