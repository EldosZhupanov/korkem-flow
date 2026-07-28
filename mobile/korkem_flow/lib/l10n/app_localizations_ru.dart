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
  String get actionRetry => 'Повторить';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionDone => 'Готово';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionClearFilter => 'Сбросить фильтр';

  @override
  String get actionFilter => 'Фильтр';

  @override
  String get actionSearch => 'Поиск';

  @override
  String get actionSelectAll => 'Все';

  @override
  String get errorGeneric => 'Что-то пошло не так.';

  @override
  String get errorOffline => 'Нет связи с сервером.';

  @override
  String get errorNoAccess => 'У вас нет доступа к этому разделу.';

  @override
  String get errorNotFound => 'Не найдено.';

  @override
  String get offlineBanner => 'Нет сети. Показаны сохранённые данные.';

  @override
  String staleData(String time) {
    return 'Обновлено $time';
  }

  @override
  String get emptyTitle => 'Здесь пока пусто';

  @override
  String get emptyGeneric => 'Новые записи появятся здесь автоматически.';

  @override
  String get loading => 'Загрузка';

  @override
  String get loadingMore => 'Загружаем ещё';

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
  String get taskProduction => 'Производство';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileAppearance => 'Оформление';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileAbout => 'О приложении';

  @override
  String get profileVersion => 'Версия';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get actionUndo => 'Отменить';

  @override
  String get profileServer => 'Сервер';

  @override
  String get dealStatusQualification => 'Квалификация';

  @override
  String get dealStatusDemo => 'Демо / Проект';

  @override
  String get dealStatusProposal => 'Предложение';

  @override
  String get dealStatusNegotiation => 'Переговоры';

  @override
  String get dealStatusReady => 'Готово к закрытию';

  @override
  String get dealStatusWon => 'Выиграна';

  @override
  String get dealStatusLost => 'Проиграна';

  @override
  String get taskPriorityHigh => 'Высокий приоритет';

  @override
  String get taskPriorityMedium => 'Средний приоритет';

  @override
  String get taskPriorityLow => 'Низкий приоритет';

  @override
  String get authTitle => 'Вход';

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
  String get authSignIn => 'Войти';

  @override
  String get authSignOut => 'Выйти';

  @override
  String get authSignOutConfirm => 'Выйти на этом устройстве?';

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
  String get dashboardAttention => 'Требует внимания';

  @override
  String get dashboardAllClear => 'Сейчас ничего не требует вашего участия';

  @override
  String get dashboardAllClearBody =>
      'Здесь появятся просроченные задачи и решения, которые ждут вас.';

  @override
  String get dashboardNoAccess => 'Недоступно для вашей роли';

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
  String get customerEmployees => 'Сотрудников';

  @override
  String get customerIndustry => 'Отрасль';

  @override
  String get customerTerritory => 'Регион';

  @override
  String get detailPipeline => 'Воронка';

  @override
  String get detailContact => 'Контакт';

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
  String get fieldJobTitle => 'Должность';

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
  String get detailNotFound => 'Эта запись больше не существует.';

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
  String get fieldQuantity => 'Количество';

  @override
  String get fieldProduced => 'Изготовлено';

  @override
  String get fieldPlannedEnd => 'Плановое завершение';

  @override
  String get fieldItem => 'Изделие';

  @override
  String get fieldDeal => 'Сделка';

  @override
  String get fieldWarehouse => 'Склад';

  @override
  String get fieldProgress => 'Готовность';

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
  String get fieldQuoteDate => 'Дата';

  @override
  String get fieldCustomer => 'Клиент';

  @override
  String get fieldInStock => 'На складе';

  @override
  String get fieldReserved => 'Резерв';

  @override
  String get fieldProjected => 'Прогноз';

  @override
  String get fieldGroup => 'Группа';

  @override
  String get fieldUnit => 'Ед. изм.';

  @override
  String get warehouseNoStock => 'Нет ни на одном складе';

  @override
  String get quoteExpiredSoon => 'Истекает';

  @override
  String get itemDisabled => 'Отключена';

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
}
