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
}
