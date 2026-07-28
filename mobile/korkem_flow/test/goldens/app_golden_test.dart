import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/crm/status_catalog_providers.dart';
import 'package:korkem_flow/core/crm/status_catalog_repository.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/dashboard/application/dashboard_controller.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:korkem_flow/features/tasks/application/tasks_controller.dart';
import 'package:korkem_flow/features/tasks/domain/task.dart';

/// Renders the **real** app — `KorkemFlowApp`, its router, its shell — rather
/// than isolated widgets, so the goldens show what a user would actually see,
/// bottom navigation and all.
///
/// Only the data boundary is stubbed. Everything above it is production code.
void main() {
  for (final brightness in Brightness.values) {
    final suffix = brightness.name;

    group('golden: $suffix', () {
      testWidgets('login', (tester) async {
        // Signed out, so the router's redirect lands here on its own — the
        // golden proves the guard works, not just that the screen renders.
        await _pumpApp(tester, brightness: brightness, signedIn: false);

        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('login_$suffix.png'),
        );
      });

      testWidgets('dashboard', (tester) async {
        await _pumpApp(tester, brightness: brightness);

        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('dashboard_$suffix.png'),
        );
      });

      testWidgets('deals', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Продажи');

        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('deals_$suffix.png'),
        );
      });

      testWidgets('tasks', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Задачи');

        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('tasks_$suffix.png'),
        );
      });

      testWidgets('profile', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Профиль');

        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('profile_$suffix.png'),
        );
      });

      testWidgets('settings', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Профиль');
        await tester.tap(find.byTooltip('Настройки'));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('settings_$suffix.png'),
        );
      });
    });
  }
}

/// A phone viewport. 2.0 rather than 3.0 keeps the PNGs reviewable in a diff
/// without changing a single layout decision — logical size is what matters.
const _logicalSize = Size(390, 844);
const _pixelRatio = 2.0;

/// Fixed so the overdue / today / upcoming split — and the dates printed on the
/// cards — are identical on every run. With a live clock these goldens would
/// fail once a day, every day.
final _now = DateTime(2026, 7, 28, 11);

Future<void> _pumpApp(
  WidgetTester tester, {
  required Brightness brightness,
  bool signedIn = true,
}) async {
  tester.view
    ..physicalSize = _logicalSize * _pixelRatio
    ..devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        // Stubbed at the session boundary, so no test ever reaches the platform
        // keychain — on Linux that is libsecret over D-Bus, absent in a runner.
        sessionProvider.overrideWith(
          () => _StubSession(
            signedIn
                ? const Session(
                    serverUrl: 'https://korkem.example.kz',
                    credentials: ApiKeyCredentials(
                      user: 'aidos@korkem.kz',
                      apiKey: 'golden',
                      apiSecret: 'golden',
                    ),
                  )
                : const Session(serverUrl: 'https://korkem.example.kz'),
          ),
        ),
        settingsControllerProvider.overrideWith(
          () => _StubSettings(
            AppSettings(
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              locale: const Locale('ru'),
            ),
          ),
        ),
        statusCatalogProvider(
          StatusCatalogRepository.dealStatusDoctype,
        ).overrideWith((ref) => Future<StatusCatalog>.value(_dealStatuses)),
        dashboardControllerProvider.overrideWith(_StubDashboard.new),
        dealsControllerProvider.overrideWith(_StubDeals.new),
        tasksControllerProvider.overrideWith(_StubTasks.new),
      ],
      child: const KorkemFlowApp(),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

class _StubSession extends SessionController {
  _StubSession(this._session);

  final Session _session;

  @override
  Future<Session> build() async => _session;
}

class _StubSettings extends SettingsController {
  _StubSettings(this._settings);

  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

class _StubDashboard extends DashboardController {
  @override
  Future<DashboardSummary> build() async => _summary;
}

class _StubDeals extends DealsController {
  @override
  Future<PagedList<Deal>> build() async =>
      PagedList(items: _deals, hasMore: false);
}

class _StubTasks extends TasksController {
  @override
  Future<List<WorkTask>> build() async => _tasks;
}

/// The site's configured deal stages, as the catalogue endpoint returns them.
const _dealStatuses = StatusCatalog([
  CrmStatus(name: 'Qualification', type: CrmStatusType.open, position: 1),
  CrmStatus(
    name: 'Proposal/Quotation',
    type: CrmStatusType.ongoing,
    position: 3,
  ),
  CrmStatus(name: 'Negotiation', type: CrmStatusType.ongoing, position: 4),
  CrmStatus(name: 'Won', type: CrmStatusType.won, position: 6),
  CrmStatus(name: 'Lost', type: CrmStatusType.lost, position: 7),
]);

final _summary = DashboardSummary(
  user: 'aidos@korkem.kz',
  metrics: const {
    DashboardSummary.openDeals: 24,
    DashboardSummary.openLeads: 61,
    DashboardSummary.myOpenTasks: 7,
    DashboardSummary.overdueTasks: 2,
    DashboardSummary.pendingActions: 3,
    // Null, not zero: this role cannot read Work Order, and the tile must show
    // a dash rather than assert a count it has no standing to know.
    DashboardSummary.workOrdersInProgress: null,
  },
  attention: [
    AttentionItem(
      kind: AttentionKind.pendingAction,
      name: 'PA-2026-0007',
      title: 'Согласовать смету',
      subtitle: 'CRM Deal CRM-DEAL-2026-00041',
      due: DateTime(2026, 7, 28, 17),
    ),
    AttentionItem(
      kind: AttentionKind.overdueTask,
      name: '512',
      title: 'Кромление фасадов — партия 12',
      subtitle: 'MFG-WO-2026-00019',
      due: DateTime(2026, 7, 27, 16),
    ),
  ],
);

final _deals = <Deal>[
  Deal(
    id: 'CRM-DEAL-2026-00041',
    organization: 'Астана Мебель Групп',
    status: 'Negotiation',
    nextStep: 'Согласовать смету по фасадам МДФ',
    mobileNo: '+7 701 000 11 22',
    modified: _now,
  ),
  Deal(
    id: 'CRM-DEAL-2026-00040',
    organization: 'ЖК «Есиль Парк»',
    status: 'Proposal/Quotation',
    nextStep: 'Отправить коммерческое предложение',
    mobileNo: '+7 705 448 90 13',
    modified: _now,
  ),
  Deal(
    id: 'CRM-DEAL-2026-00038',
    organization: 'Қарағанды Интерьер',
    status: 'Won',
    nextStep: 'Передать в производство',
    mobileNo: '+7 747 213 55 08',
    modified: _now,
  ),
  Deal(
    id: 'CRM-DEAL-2026-00035',
    organization: 'Restaurant Aul',
    status: 'Qualification',
    nextStep: 'Замер 30 июля',
    mobileNo: '+7 702 909 74 61',
    modified: _now,
  ),
  Deal(
    id: 'CRM-DEAL-2026-00031',
    organization: 'Строй Комфорт KZ',
    status: 'Lost',
    nextStep: 'Клиент выбрал другого поставщика',
    modified: _now,
  ),
];

final _tasks = <WorkTask>[
  WorkTask(
    id: 512,
    title: 'Кромление фасадов — партия 12',
    status: TaskStatus.inProgress,
    priority: TaskPriority.high,
    dueDate: DateTime(2026, 7, 27, 16),
    assignedTo: 'Айдос Н.',
    referenceDoctype: 'Work Order',
    referenceName: 'MFG-WO-2026-00019',
  ),
  WorkTask(
    id: 514,
    title: 'Позвонить клиенту по замеру',
    status: TaskStatus.todo,
    priority: TaskPriority.medium,
    dueDate: DateTime(2026, 7, 28, 18, 30),
    assignedTo: 'Дана С.',
  ),
  WorkTask(
    id: 517,
    title: 'Покраска корпусов — заказ 00040',
    status: TaskStatus.todo,
    priority: TaskPriority.high,
    dueDate: DateTime(2026, 7, 30, 9),
    assignedTo: 'Ерлан Т.',
    referenceDoctype: 'Work Order',
    referenceName: 'MFG-WO-2026-00021',
  ),
  const WorkTask(
    id: 519,
    title: 'Подготовить упаковку и маркировку',
    status: TaskStatus.backlog,
    priority: TaskPriority.low,
    referenceDoctype: 'Work Order',
    referenceName: 'MFG-WO-2026-00021',
  ),
];
