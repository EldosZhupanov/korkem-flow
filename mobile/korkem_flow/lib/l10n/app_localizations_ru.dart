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
}
