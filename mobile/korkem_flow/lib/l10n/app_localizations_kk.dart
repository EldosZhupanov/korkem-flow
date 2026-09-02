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
  String get settingsTitle => 'Параметрлер';

  @override
  String get settingsAccount => 'Есептік жазба';

  @override
  String get settingsSignedInAs => 'Сіз кірдіңіз';

  @override
  String get settingsConnection => 'Қосылым';

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
  String get todayTitle => 'Бүгін';

  @override
  String get todaySubtitle => 'Цехтың жедел жиынтығы';

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
}
