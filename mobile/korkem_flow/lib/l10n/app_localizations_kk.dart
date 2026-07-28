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
  String get actionRetry => 'Қайталау';

  @override
  String get actionCancel => 'Болдырмау';

  @override
  String get actionSave => 'Сақтау';

  @override
  String get actionDone => 'Дайын';

  @override
  String get actionClose => 'Жабу';

  @override
  String get actionClearFilter => 'Сүзгіні тазалау';

  @override
  String get actionFilter => 'Сүзгі';

  @override
  String get actionSearch => 'Іздеу';

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
  String get offlineBanner => 'Желі жоқ. Сақталған деректер көрсетілген.';

  @override
  String staleData(String time) {
    return 'Жаңартылды $time';
  }

  @override
  String get emptyTitle => 'Мұнда әзірге бос';

  @override
  String get emptyGeneric => 'Жаңа жазбалар осы жерде пайда болады.';

  @override
  String get loading => 'Жүктелуде';

  @override
  String get loadingMore => 'Тағы жүктелуде';

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
  String get taskProduction => 'Өндіріс';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileAppearance => 'Безендіру';

  @override
  String get profileLanguage => 'Тіл';

  @override
  String get profileAbout => 'Қосымша туралы';

  @override
  String get profileVersion => 'Нұсқа';

  @override
  String get themeSystem => 'Жүйелік';

  @override
  String get themeLight => 'Жарық';

  @override
  String get themeDark => 'Қараңғы';

  @override
  String get actionUndo => 'Болдырмау';

  @override
  String get profileServer => 'Сервер';

  @override
  String get dealStatusQualification => 'Іріктеу';

  @override
  String get dealStatusDemo => 'Демо / Жоба';

  @override
  String get dealStatusProposal => 'Ұсыныс';

  @override
  String get dealStatusNegotiation => 'Келіссөздер';

  @override
  String get dealStatusReady => 'Жабуға дайын';

  @override
  String get dealStatusWon => 'Жеңіске жетті';

  @override
  String get dealStatusLost => 'Жоғалтылды';

  @override
  String get taskPriorityHigh => 'Жоғары басымдық';

  @override
  String get taskPriorityMedium => 'Орташа басымдық';

  @override
  String get taskPriorityLow => 'Төмен басымдық';

  @override
  String get authTitle => 'Кіру';

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
  String get authSignIn => 'Кіру';

  @override
  String get authSignOut => 'Шығу';

  @override
  String get authSignOutConfirm => 'Осы құрылғыдан шығу керек пе?';

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
  String get dashboardAttention => 'Назар аударыңыз';

  @override
  String get dashboardAllClear => 'Қазір сізден ештеңе талап етілмейді';

  @override
  String get dashboardAllClearBody =>
      'Мұнда мерзімі өткен тапсырмалар мен сізді күтіп тұрған шешімдер көрінеді.';

  @override
  String get dashboardNoAccess => 'Сіздің рөліңізге қолжетімсіз';

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
}
