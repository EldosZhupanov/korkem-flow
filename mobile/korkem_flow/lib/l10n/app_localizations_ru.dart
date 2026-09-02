// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'KORKEM Flow';

  @override
  String get filterNoResults => 'По этому фильтру ничего нет.';

  @override
  String get actionClearHistory => 'Очистить историю';

  @override
  String get actionClearSearch => 'Очистить поиск';

  @override
  String get actionRefresh => 'Обновить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionClearFilter => 'Сбросить фильтр';

  @override
  String get actionFilter => 'Фильтр';

  @override
  String get actionSelectAll => 'Все';

  @override
  String get errorGeneric => 'Что-то пошло не так.';

  @override
  String get errorOffline => 'Нет связи с сервером.';

  @override
  String get outboxQueued => 'Нет связи. Команда ждёт отправки.';

  @override
  String outboxPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count команды ждут отправки',
      many: '$count команд ждут отправки',
      few: '$count команды ждут отправки',
      one: '$count команда ждёт отправки',
    );
    return '$_temp0';
  }

  @override
  String get outboxRetry => 'Отправить сейчас';

  @override
  String outboxRejected(String reason) {
    return 'Команда из очереди отклонена: $reason';
  }

  @override
  String get errorNoAccess => 'У вас нет доступа к этому разделу.';

  @override
  String get errorNotFound => 'Не найдено.';

  @override
  String get emptyTitle => 'Здесь пока пусто';

  @override
  String get emptyGeneric => 'Новые записи появятся здесь автоматически.';

  @override
  String get searchHint => 'Поиск';

  @override
  String searchNoResults(String query) {
    return 'Ничего не найдено по запросу «$query»';
  }

  @override
  String semanticStatus(String status) {
    return 'Статус: $status';
  }

  @override
  String get navDeals => 'Сделки';

  @override
  String get navTasks => 'Задачи';

  @override
  String get navProfile => 'Профиль';

  @override
  String get tasksOverdue => 'Просрочено';

  @override
  String get tasksToday => 'Сегодня';

  @override
  String get tasksUpcoming => 'Предстоящие';

  @override
  String get tasksEmpty => 'Нет открытых задач';

  @override
  String get tasksEmptyBody => 'Назначенная работа появится здесь.';

  @override
  String get taskComplete => 'Завершить';

  @override
  String get taskCompleted => 'Задача завершена';

  @override
  String taskCompleteFailed(String reason) {
    return 'Не удалось завершить задачу. $reason';
  }

  @override
  String get actionUndo => 'Отменить';

  @override
  String get taskProduction => 'Производство';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileAppearance => 'Оформление';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileVersion => 'Версия';

  @override
  String get themeSystem => 'Системная';

  @override
  String get languageSystem => 'Язык устройства';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get profileServer => 'Сервер';

  @override
  String get taskPriorityHigh => 'Высокий приоритет';

  @override
  String get authSubtitle => 'Подключитесь к рабочему пространству KORKEM';

  @override
  String get authServer => 'Адрес сервера';

  @override
  String get authServerHint => 'korkem.example.kz';

  @override
  String get authEmail => 'Электронная почта';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authShowPassword => 'Показать пароль';

  @override
  String get authHidePassword => 'Скрыть пароль';

  @override
  String get authSignIn => 'Войти';

  @override
  String get authSignOut => 'Выйти';

  @override
  String get authSignOutConfirm => 'Выйти на этом устройстве?';

  @override
  String get authSignOutBody =>
      'Чтобы войти снова, понадобятся адрес сервера и пароль.';

  @override
  String get authFieldRequired => 'Обязательное поле';

  @override
  String get authInvalidServer => 'Некорректный адрес.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAccount => 'Учётная запись';

  @override
  String get settingsSignedInAs => 'Вы вошли как';

  @override
  String get settingsConnection => 'Подключение';

  @override
  String get navDashboard => 'Главная';

  @override
  String get dashboardGreeting => 'Сегодня';

  @override
  String get dashboardMyWork => 'Моя работа';

  @override
  String dashboardWorkload(int overdue, int total) {
    return '$overdue из $total просрочены';
  }

  @override
  String get dashboardAttention => 'Требует внимания';

  @override
  String get dashboardAllClear => 'Сейчас ничего не требует вашего участия';

  @override
  String get dashboardAllClearBody =>
      'Здесь появятся просроченные задачи и решения, которые ждут вас.';

  @override
  String get metricOpenDeals => 'Открытые сделки';

  @override
  String get metricOpenLeads => 'Лиды';

  @override
  String get metricMyOpenTasks => 'Мои задачи';

  @override
  String get metricOverdueTasks => 'Просрочено';

  @override
  String get metricPendingActions => 'Ждут решения';

  @override
  String get metricWorkOrders => 'В производстве';

  @override
  String get attentionPendingAction => 'Нужно решение';

  @override
  String get attentionOverdueTask => 'Просроченная задача';

  @override
  String get navSales => 'Продажи';

  @override
  String get navLeads => 'Лиды';

  @override
  String get navCustomers => 'Клиенты';

  @override
  String get dealsEmptyAssigned => 'На вас пока ничего не назначено';

  @override
  String get dealsEmptyAssignedBody =>
      'Вы видите только свои сделки и те, где вы назначены. Попросите руководителя назначить вам сделку.';

  @override
  String get leadsEmpty => 'Лидов нет';

  @override
  String get leadsEmptyBody =>
      'Новые обращения появятся здесь по мере поступления.';

  @override
  String get leadConverted => 'Сконвертирован';

  @override
  String get customersEmpty => 'Клиентов нет';

  @override
  String get customersEmptyBody =>
      'Организации появятся здесь, как только по ним заведут сделку.';

  @override
  String get detailPipeline => 'Воронка';

  @override
  String get detailCommercial => 'Коммерция';

  @override
  String get detailOwnership => 'Ответственность';

  @override
  String get detailCompany => 'Компания';

  @override
  String get fieldStage => 'Стадия';

  @override
  String get fieldValue => 'Сумма';

  @override
  String get fieldProbability => 'Вероятность';

  @override
  String get fieldExpectedClose => 'Ожидаемое закрытие';

  @override
  String get fieldNextStep => 'Следующий шаг';

  @override
  String get fieldOwner => 'Ответственный';

  @override
  String get fieldSource => 'Источник';

  @override
  String get fieldTerritory => 'Регион';

  @override
  String get fieldIndustry => 'Отрасль';

  @override
  String get fieldWebsite => 'Сайт';

  @override
  String get fieldEmployees => 'Сотрудников';

  @override
  String get fieldRevenue => 'Годовой оборот';

  @override
  String get fieldOriginLead => 'Из лида';

  @override
  String get fieldUpdated => 'Обновлено';

  @override
  String get actionCall => 'Позвонить';

  @override
  String get actionEmail => 'Письмо';

  @override
  String get actionWhatsApp => 'WhatsApp';

  @override
  String get navApprovals => 'Согласования';

  @override
  String get navProduction => 'Производство';

  @override
  String get approvalsEmpty => 'Решений не требуется';

  @override
  String get approvalsEmptyBody =>
      'Здесь появятся решения, которых ждёт агент.';

  @override
  String get approvalApprove => 'Согласовать';

  @override
  String get approvalReject => 'Отклонить';

  @override
  String get approvalApproved => 'Согласовано';

  @override
  String get approvalRejected => 'Отклонено';

  @override
  String get approvalExpires => 'Истекает';

  @override
  String get approvalExpired => 'Истекло';

  @override
  String get productionEmpty => 'Заказов нет';

  @override
  String get productionEmptyBody =>
      'Заказы появятся, когда сделка уйдёт в производство.';

  @override
  String get paPending => 'Ожидает';

  @override
  String get paApproved => 'Согласовано';

  @override
  String get paRejected => 'Отклонено';

  @override
  String get paExpired => 'Истекло';

  @override
  String get woDraft => 'Черновик';

  @override
  String get woSubmitted => 'Подтверждён';

  @override
  String get woNotStarted => 'Не начат';

  @override
  String get woInProcess => 'В работе';

  @override
  String get woStockReserved => 'Материалы зарезервированы';

  @override
  String get woStockPartial => 'Материалы частично';

  @override
  String get woCompleted => 'Завершён';

  @override
  String get woStopped => 'Остановлен';

  @override
  String get woClosed => 'Закрыт';

  @override
  String get woCancelled => 'Отменён';

  @override
  String get navQuotes => 'Счета';

  @override
  String get navWarehouse => 'Склад';

  @override
  String get navOperations => 'Операции';

  @override
  String get quotesEmpty => 'Счетов нет';

  @override
  String get quotesEmptyBody => 'Счета появятся, когда их выставят по сделке.';

  @override
  String get warehouseEmpty => 'Позиций нет';

  @override
  String get warehouseEmptyBody => 'Складские позиции появятся здесь.';

  @override
  String get fieldValidTill => 'Действителен до';

  @override
  String get fieldReserved => 'Резерв';

  @override
  String get warehouseNoStock => 'Нет ни на одном складе';

  @override
  String get quoteExpiredSoon => 'Истекает';

  @override
  String get qDraft => 'Черновик';

  @override
  String get qOpen => 'Открыт';

  @override
  String get qReplied => 'Есть ответ';

  @override
  String get qPartiallyOrdered => 'Частично заказан';

  @override
  String get qOrdered => 'Заказан';

  @override
  String get qLost => 'Проигран';

  @override
  String get qCancelled => 'Отменён';

  @override
  String get qExpired => 'Истёк';

  @override
  String get navNotifications => 'Уведомления';

  @override
  String get notificationsEmpty => 'Пока ничего не отправлялось.';

  @override
  String get notificationsEmptyBody =>
      'Назначения, упоминания и оповещения появятся здесь.';

  @override
  String get notificationsMarkAllRead => 'Отметить все';

  @override
  String get navAssistant => 'Ассистент';

  @override
  String get navMenu => 'Меню';

  @override
  String get chatNew => 'Новый чат';

  @override
  String get chatRecent => 'Недавние';

  @override
  String get chatGreeting => 'Чем могу помочь?';

  @override
  String get chatPlaceholder => 'Спросите KORKEM о чём угодно…';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatDictate => 'Продиктовать';

  @override
  String get chatDictateStop => 'Остановить диктовку';

  @override
  String get chatLocalMode => 'Локальный режим · данные KORKEM';

  @override
  String get chatThinking => 'Думаю';

  @override
  String get chatEmptyThreads => 'Разговоров пока нет';

  @override
  String get chatOpen => 'Открыть';

  @override
  String get chatNotConnected =>
      'Я пока не подключён к языковой модели и не могу на это ответить. Могу показать данные KORKEM:';

  @override
  String get chatSuggestDeals => 'Покажи мои сделки';

  @override
  String get chatSuggestAttention => 'Что требует внимания?';

  @override
  String get chatSuggestOverdue => 'Что просрочено?';

  @override
  String get chatSuggestProduction => 'Что сейчас в производстве?';

  @override
  String get chatCardOpenDeals => 'Открытые сделки';

  @override
  String get chatCardAttention => 'Требует внимания';

  @override
  String get chatCardTasks => 'Мои задачи';

  @override
  String get chatCardProduction => 'В производстве';

  @override
  String get chatHistory => 'История';

  @override
  String get chatToday => 'Сегодня';

  @override
  String get chatYesterday => 'Вчера';

  @override
  String get chatEarlier => 'Ранее';

  @override
  String get chatScrollToEnd => 'К последнему сообщению';

  @override
  String get chatWorkspace => 'AI Workspace';

  @override
  String get chatRename => 'Переименовать';

  @override
  String get chatDelete => 'Удалить';

  @override
  String get chatDeleteTitle => 'Удалить разговор?';

  @override
  String chatDeleteBody(String title) {
    return 'Разговор «$title» будет удалён с этого устройства. Отменить нельзя.';
  }

  @override
  String get chatRenameTitle => 'Название разговора';

  @override
  String get navClients => 'Клиенты';

  @override
  String get chatErrorNotConfigured =>
      'ИИ ещё не настроен на сервере. Обратитесь к администратору KORKEM.';

  @override
  String get chatErrorOffline =>
      'Не удалось связаться с KORKEM. Проверьте подключение.';

  @override
  String get chatErrorRefused => 'Недостаточно прав для этого запроса.';

  @override
  String get chatErrorUnknown => 'Не удалось ответить. Попробуйте ещё раз.';

  @override
  String get chatWorking => 'Работаю…';

  @override
  String get chatToolDeals => 'Ищу сделки…';

  @override
  String get chatToolLeads => 'Ищу лиды…';

  @override
  String get chatToolCustomers => 'Ищу клиентов…';

  @override
  String get chatToolTasks => 'Ищу задачи…';

  @override
  String get chatToolProduction => 'Смотрю производство…';

  @override
  String get chatToolOrders => 'Смотрю заказы…';

  @override
  String get chatToolShortage => 'Считаю дефицит материалов…';

  @override
  String get chatToolStock => 'Проверяю остатки…';

  @override
  String get chatToolProcurement => 'Готовлю заявку на закупку…';

  @override
  String get chatToolProfile => 'Проверяю ваш профиль…';

  @override
  String get chatErrorProviderUnavailable =>
      'Сервис ИИ не отвечает. Попробуйте чуть позже.';

  @override
  String get chatErrorRateLimited =>
      'Сервис ИИ перегружен. Подождите немного и повторите.';

  @override
  String get chatErrorToolError =>
      'Не удалось выполнить это действие в KORKEM.';

  @override
  String get chatConfirmTitle => 'Подтвердите действие';

  @override
  String get chatConfirmBody =>
      'Помощник хочет внести изменение. Пока ничего не произошло.';

  @override
  String get chatConfirmApprove => 'Подтвердить';

  @override
  String get chatConfirmReject => 'Отменить';

  @override
  String get chatConfirmRejected => 'Отменено. Ничего не изменилось.';

  @override
  String get chatFallbackBadge => 'Без ИИ — прямые данные';

  @override
  String get chatErrorTimedOut =>
      'Сервис ИИ отвечал слишком долго. Попробуйте ещё раз.';

  @override
  String get chatErrorModelNotFound =>
      'Выбранная модель недоступна. Выберите другую в настройках ИИ.';

  @override
  String get chatErrorContextTooLarge =>
      'Этот диалог слишком длинный. Начните новый.';

  @override
  String get aiSettingsTitle => 'Провайдеры ИИ';

  @override
  String get aiSettingsSubtitle =>
      'Выберите, какой ИИ отвечает, и подключите его.';

  @override
  String get aiSettingsDefault => 'По умолчанию';

  @override
  String get aiSettingsMakeDefault => 'Сделать основным';

  @override
  String get aiSettingsNotConfigured => 'Не настроен';

  @override
  String get aiSettingsConnected => 'Подключено';

  @override
  String get aiSettingsTestFailed => 'Не удалось подключиться';

  @override
  String get aiSettingsTest => 'Проверить подключение';

  @override
  String get aiSettingsSave => 'Сохранить';

  @override
  String get aiSettingsApiKey => 'API-ключ';

  @override
  String get aiSettingsApiKeyStored =>
      'Ключ сохранён. Оставьте пустым, чтобы не менять.';

  @override
  String get aiSettingsModel => 'Модель';

  @override
  String get aiSettingsBaseUrl => 'Базовый URL';

  @override
  String get aiSettingsKeyNeverLeaves =>
      'Ключи хранятся на сервере KORKEM и никогда не передаются на это устройство.';

  @override
  String get aiSettingsCapabilities => 'Возможности';

  @override
  String get aiSettingsLocalNoKey => 'Работает локально — ключ не нужен.';

  @override
  String get channelsTitle => 'Каналы';

  @override
  String get channelsSubtitle =>
      'Подключите ботов Telegram и WhatsApp и укажите, кто на другой стороне.';

  @override
  String get channelsSecretsNote =>
      'Токены хранятся на сервере KORKEM и никогда не передаются на это устройство.';

  @override
  String get channelsStateNotConfigured => 'Не настроен';

  @override
  String get channelsStateDisabled => 'Выключен';

  @override
  String get channelsStateReady => 'Готов';

  @override
  String get channelsTest => 'Проверить связь';

  @override
  String get channelsTestOk => 'Связь есть';

  @override
  String get channelsTestFailed => 'Связи нет';

  @override
  String get channelsEnabled => 'Включён';

  @override
  String get channelsSave => 'Сохранить';

  @override
  String get channelsStored => 'Сохранено. Оставьте пустым, чтобы не менять.';

  @override
  String get channelsBotToken => 'Токен бота';

  @override
  String get channelsWebhookSecret => 'Секрет вебхука';

  @override
  String get channelsAccessToken => 'Токен доступа';

  @override
  String get channelsPhoneNumberId => 'ID номера';

  @override
  String get channelsVerifyToken => 'Токен проверки';

  @override
  String get channelsWebhookUrl => 'URL вебхука';

  @override
  String get channelsIdentities => 'Кто пишет';

  @override
  String get channelsIdentityUnlinked => 'Не связан';

  @override
  String get channelsLink => 'Связать';

  @override
  String get channelsUnlink => 'Отвязать';

  @override
  String get channelsUser => 'Пользователь KORKEM';

  @override
  String get channelsIdentitiesEmpty => 'Боту ещё никто не писал.';

  @override
  String get channelsStateConnected => 'Связь есть';

  @override
  String get channelsStateInvalid => 'Учётные данные отклонены';

  @override
  String get channelsStateWebhookError => 'Проблема с вебхуком';

  @override
  String get channelsStateUnavailable => 'Провайдер недоступен';

  @override
  String get channelsConfigureWebhook => 'Настроить вебхук';

  @override
  String get channelsRemoveWebhook => 'Убрать вебхук';

  @override
  String get channelsWebhookManual =>
      'Вставьте этот адрес в панель провайдера.';

  @override
  String get channelsLastChecked => 'Последняя проверка';

  @override
  String get channelsPending => 'Ожидает у провайдера';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsSubtitle =>
      'Что система сообщила людям и что доставить не удалось.';

  @override
  String get notificationsRetry => 'Повторить';

  @override
  String get notificationsRetryAll => 'Повторить все';

  @override
  String get notificationsCancel => 'Отменить';

  @override
  String get notificationsAttempts => 'Попыток';

  @override
  String get notificationsNextAttempt => 'Следующая попытка';

  @override
  String get notificationsFilterAll => 'Все';

  @override
  String get instructionsTitle => 'Поручения';

  @override
  String get instructionsSubtitle => 'Кого попросили и что он ответил.';

  @override
  String get instructionsEmpty => 'Поручений пока нет.';

  @override
  String get instructionsAnsweredIn => 'Ответ через';

  @override
  String get channelsSendTest => 'Отправить тестовое';

  @override
  String get channelsDisconnect => 'Отключить';

  @override
  String get channelsLastInbound => 'Последнее входящее';

  @override
  String get channelsLastOutbound => 'Последнее исходящее';

  @override
  String get channelsFailedDeliveries => 'Не доставлено';

  @override
  String get channelsPendingRetries => 'Ждут повтора';

  @override
  String get channelsStateForbidden => 'Заблокировано провайдером';

  @override
  String get channelsStateRateLimited => 'Ограничение частоты';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get ordersEmpty => 'Заказов пока нет';

  @override
  String get ordersEmptyBody => 'Новые заказы клиентов появятся здесь.';

  @override
  String get ordersActionStartProduction => 'Запустить производство';

  @override
  String get ordersStartingProduction => 'Запуск производства...';

  @override
  String ordersStartSuccess(String id) {
    return 'Производство запущено по $id';
  }

  @override
  String ordersTopUpSuccess(String id) {
    return 'Материал передан по $id';
  }

  @override
  String ordersAlreadyStarted(String id) {
    return 'Производство по $id уже запущено';
  }

  @override
  String ordersNothingToStart(String id) {
    return 'По заказу $id нечего запускать';
  }

  @override
  String get ordersBlockedTitle => 'Недостаточно материалов';

  @override
  String get ordersBlockedBody =>
      'Для запуска производства не хватает материалов на складе:';

  @override
  String ordersBlockedSummary(String id) {
    return 'Нельзя запустить $id: не хватает материалов на складе';
  }

  @override
  String ordersDeliveredProgress(String percent) {
    return 'Отгружено $percent%';
  }

  @override
  String ordersDeliveryDate(String date) {
    return 'Доставка: $date';
  }

  @override
  String ordersTransactionDate(String date) {
    return 'От $date';
  }

  @override
  String get soDraft => 'Черновик';

  @override
  String get soToDeliverAndBill => 'К отгрузке и оплате';

  @override
  String get soToBill => 'К оплате';

  @override
  String get soToDeliver => 'К отгрузке';

  @override
  String get soCompleted => 'Завершён';

  @override
  String get soCancelled => 'Отменён';

  @override
  String get soClosed => 'Закрыт';

  @override
  String get soOnHold => 'На удержании';

  @override
  String get todayTitle => 'Сегодня';

  @override
  String get todaySubtitle => 'Оперативная сводка цеха';

  @override
  String get todayActiveOrders => 'Активные заказы';

  @override
  String todayLateOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count просрочено',
      many: '$count просрочено',
      few: '$count просрочено',
      one: '$count просрочен',
    );
    return '$_temp0';
  }

  @override
  String get todayOrdersAllOnTrack => 'Все в графике';

  @override
  String get todayInProduction => 'В производстве';

  @override
  String todayWorkOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заданий',
      many: '$count заданий',
      few: '$count задания',
      one: '$count задание',
    );
    return '$_temp0';
  }

  @override
  String get todayProductionAllOnTrack => 'Без задержек';

  @override
  String get todayApprovals => 'Ожидают подтверждения';

  @override
  String todayApprovalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count решений',
      many: '$count решений',
      few: '$count решения',
      one: '$count решение',
    );
    return '$_temp0';
  }

  @override
  String get todayApprovalsNone => 'Все согласованы';

  @override
  String get todayStockDeficit => 'Дефицит склада';

  @override
  String todayDeficitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count позиций ниже нуля',
      many: '$count позиций ниже нуля',
      few: '$count позиции ниже нуля',
      one: '$count позиция ниже нуля',
    );
    return '$_temp0';
  }

  @override
  String get todayDeficitNone => 'Дефицита нет';

  @override
  String get todayAttentionTitle => 'Требует внимания';

  @override
  String get todayAllClearTitle => 'Всё в порядке';

  @override
  String get todayAllClearSubtitle =>
      'Критических задержек и дефицита на производстве нет';

  @override
  String get todayQuickNav => 'Быстрый переход';

  @override
  String get todayTileError => 'Не удалось загрузить';

  @override
  String get orderProductionSection => 'Производство';

  @override
  String get orderNoProductionTitle => 'Производство ещё не запущено';

  @override
  String get orderNoProductionBody =>
      'По этому заказу нет ни одного задания. Запустите производство, когда заказ подтверждён.';

  @override
  String get workOrderLinkedSalesOrder => 'Связанный заказ';

  @override
  String get workOrderNoLinkedSalesOrder => 'Заказ не привязан';

  @override
  String workOrderPlannedEnd(String date) {
    return 'Плановое окончание: $date';
  }

  @override
  String workOrderActualEnd(String date) {
    return 'Фактическое окончание: $date';
  }

  @override
  String workOrderBomNo(String bom) {
    return 'Спецификация: $bom';
  }

  @override
  String workOrderWipWarehouse(String warehouse) {
    return 'Склад незавершённого производства: $warehouse';
  }

  @override
  String workOrderFgWarehouse(String warehouse) {
    return 'Склад готовой продукции: $warehouse';
  }

  @override
  String workOrderProducedProgress(String produced, String qty) {
    return 'Изготовлено: $produced из $qty';
  }

  @override
  String get workOrderOperationsSection => 'Операции';

  @override
  String get workOrderNoOperationsTitle => 'Нет операций';

  @override
  String get workOrderNoOperationsBody =>
      'В этом производственном задании операции не заданы.';

  @override
  String workOrderOperationSequence(int sequence) {
    return '№ $sequence';
  }

  @override
  String workOrderOperationWorkstation(String workstation) {
    return 'Рабочий центр: $workstation';
  }

  @override
  String workOrderOperationCompleted(String qty) {
    return 'Выполнено: $qty';
  }

  @override
  String workOrderOperationScrap(String qty) {
    return 'Брак: $qty';
  }

  @override
  String workOrderOperationTime(int minutes) {
    return 'План: $minutes мин';
  }

  @override
  String get opPending => 'Ожидает';

  @override
  String get opInProgress => 'В работе';

  @override
  String get opCompleted => 'Выполнено';

  @override
  String get opClosed => 'Закрыто';

  @override
  String get opCancelled => 'Отменено';

  @override
  String get stockBalancesSection => 'Остатки по складам';

  @override
  String get stockSummarySection => 'Итого по всем складам';

  @override
  String get stockActualQty => 'Фактический остаток';

  @override
  String get stockReservedQty => 'В резерве';

  @override
  String get stockProjectedQty => 'Прогноз';

  @override
  String get stockDeficitAlert => 'Дефицит на складе';

  @override
  String get stockNoBalancesTitle => 'Нет на складах';

  @override
  String get stockNoBalancesBody =>
      'Позиция не числится ни на одном складе компании.';

  @override
  String get warehouseActionOpen => 'Открыть';

  @override
  String get outboxTitle => 'Очередь команд';

  @override
  String get outboxEmptyTitle => 'Все команды отправлены';

  @override
  String get outboxEmptyBody =>
      'Нет ожидающих или отклонённых команд. При потере связи новые действия сохранятся здесь.';

  @override
  String outboxPendingSection(int count) {
    return 'Ждут отправки ($count)';
  }

  @override
  String outboxRejectedSection(int count) {
    return 'Отклонены ($count)';
  }

  @override
  String outboxRejectedPending(int count) {
    return 'Требуют внимания: $count';
  }

  @override
  String get outboxDismissRejected => 'Понятно, убрать';

  @override
  String get outboxDismissAll => 'Убрать все';

  @override
  String outboxCommandStartProduction(String order) {
    return 'Запуск производства по $order';
  }

  @override
  String outboxCommandCompleteOperation(String operation) {
    return 'Отчёт по операции: $operation';
  }

  @override
  String outboxCommandReceiveReceipt(String order) {
    return 'Приёмка по $order';
  }

  @override
  String outboxCommandCreatePurchaseOrder(String request) {
    return 'Заказ поставщику по $request';
  }

  @override
  String outboxCommandCreateDelivery(String order) {
    return 'Отгрузка по $order';
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
    return 'Поставщик: $supplier';
  }

  @override
  String outboxParamWorkOrder(String workOrder) {
    return 'Задание: $workOrder';
  }

  @override
  String outboxParamCompletedQty(String qty) {
    return 'Готово: $qty';
  }

  @override
  String outboxParamScrapQty(String qty) {
    return 'Брак: $qty';
  }

  @override
  String get todayOutboxTitle => 'Не отправлено';

  @override
  String get todayOutboxAllSent => 'Всё отправлено';

  @override
  String get orderDeliveriesSection => 'Отгрузки';

  @override
  String get orderNoDeliveriesTitle => 'Отгрузок ещё не было';

  @override
  String get orderNoDeliveriesBody =>
      'Здесь появятся накладные, когда товары будут отгружены.';

  @override
  String get searchTitle => 'Поиск';

  @override
  String get searchPlaceholder => 'Заказ, клиент, материал...';

  @override
  String get searchEmptyPromptTitle => 'Поиск по всей системе';

  @override
  String get searchEmptyPromptBody =>
      'Введите номер заказа, имя клиента, задание или код материала.';

  @override
  String get searchNoResultsTitle => 'Ничего не найдено';

  @override
  String searchNoResultsBody(String query) {
    return 'По запросу «$query» ничего не найдено.';
  }

  @override
  String searchSectionOrders(int count) {
    return 'Заказы ($count)';
  }

  @override
  String searchSectionWorkOrders(int count) {
    return 'Задания ($count)';
  }

  @override
  String searchSectionStock(int count) {
    return 'Склад ($count)';
  }

  @override
  String searchSectionError(String section) {
    return 'Не удалось загрузить раздел: $section';
  }

  @override
  String get searchNavTooltip => 'Поиск';

  @override
  String get ordersSelectPromptTitle => 'Выберите заказ';

  @override
  String get ordersSelectPromptBody =>
      'Выберите заказ из списка слева, чтобы посмотреть его параметры, статус, задания производства и отгрузки.';

  @override
  String get productionSelectPromptTitle => 'Выберите задание';

  @override
  String get productionSelectPromptBody =>
      'Выберите задание из списка, чтобы просмотреть его параметры и технологические операции.';

  @override
  String get warehouseSelectPromptTitle => 'Выберите позицию';

  @override
  String get warehouseSelectPromptBody =>
      'Выберите позицию из списка, чтобы просмотреть остатки по складам и параметры.';

  @override
  String get completeOperationAction => 'Закрыть';

  @override
  String get completeOperationTitle => 'Закрытие операции';

  @override
  String get completeOperationQtyLabel => 'Готовая продукция';

  @override
  String get completeOperationScrapQtyLabel => 'Брак';

  @override
  String completeOperationSuccess(String operation) {
    return 'Операция «$operation» завершена';
  }

  @override
  String get completeOperationAlreadyComplete =>
      'Операция уже была закрыта ранее';

  @override
  String get completeOperationInvalidQty =>
      'Введите корректное неотрицательное число';

  @override
  String get completeOperationBlockedTitle => 'Не удалось закрыть операцию';

  @override
  String get ordersActionCreateDelivery => 'Создать отгрузку';

  @override
  String orderDeliverySuccess(String note) {
    return 'Отгрузка $note создана';
  }

  @override
  String orderDeliveryAdjustedSuccess(String note) {
    return 'Частичная отгрузка $note создана по наличию на складе';
  }

  @override
  String get orderAlreadyDelivered => 'Заказ уже полностью отгружен';

  @override
  String get orderNothingShippable =>
      'На складе нет готовых позиций для отгрузки';

  @override
  String get orderDeliveryBlockedTitle => 'Не удалось создать отгрузку';

  @override
  String get warehouseActionReceive => 'Принять поставку';

  @override
  String get receiveDeliveryDialogTitle => 'Приёмка поставки';

  @override
  String get receivePurchaseOrderFieldLabel => 'Номер заказа поставщику';

  @override
  String get receivePurchaseOrderFieldHint => 'напр. PUR-ORD-2026-00001';

  @override
  String receiveSuccess(String receipt) {
    return 'Поступление $receipt принято';
  }

  @override
  String get receiveNothingOutstanding =>
      'Все позиции по этому заказу поставщику уже приняты';

  @override
  String get receiveBlockedTitle => 'Не удалось принять поставку';

  @override
  String get warehouseActionPurchaseOrder => 'Создать закупку';

  @override
  String get createPurchaseOrderDialogTitle => 'Создание заказа поставщику';

  @override
  String get materialRequestFieldLabel => 'Номер заявки на материалы';

  @override
  String get materialRequestFieldHint => 'напр. MAT-MR-2026-00001';

  @override
  String get supplierFieldLabel => 'Поставщик (необязательно)';

  @override
  String purchaseOrderSuccess(String order) {
    return 'Заказ поставщику $order создан';
  }

  @override
  String get purchaseOrderBlockedTitle => 'Не удалось создать заказ поставщику';

  @override
  String get receiveNoOrdersTitle => 'Нет ожидаемых поставок';

  @override
  String get receiveNoOrdersBody =>
      'Все заказы поставщикам уже приняты либо нет активных заказов.';

  @override
  String get orderableNoRequestsTitle => 'Нет заявок на материалы';

  @override
  String get orderableNoRequestsBody =>
      'Все заявки на закупку материалов уже обработаны.';

  @override
  String materialRequestNeededDate(String date) {
    return 'Потребность к: $date';
  }

  @override
  String purchaseOrderExpectedDate(String date) {
    return 'Ожидается: $date';
  }

  @override
  String get workstationsTitle => 'Рабочие места';

  @override
  String get workstationsSubtitle => 'Очередь операций по станкам';

  @override
  String get workstationsEmptyTitle => 'Нет активных заданий';

  @override
  String get workstationsEmptyBody =>
      'Все станки свободны, незавершённых операций нет.';

  @override
  String get stationQueueEmptyTitle => 'На этом месте всё сделано';

  @override
  String get stationQueueEmptyBody => 'Нет ожидающих операций на этом станке.';

  @override
  String workstationWaitingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count операций',
      few: '$count операции',
      one: '$count операция',
    );
    return '$_temp0';
  }

  @override
  String workstationDueOn(String date) {
    return 'Срок: $date';
  }

  @override
  String workstationItemLabel(String item) {
    return 'Изделие: $item';
  }

  @override
  String workstationQtyLabel(String qty) {
    return 'Количество: $qty';
  }

  @override
  String workstationDuration(String minutes) {
    return '$minutes мин';
  }
}
