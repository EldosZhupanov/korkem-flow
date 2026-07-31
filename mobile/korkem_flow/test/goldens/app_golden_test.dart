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
import 'package:korkem_flow/features/approvals/application/approvals_controller.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/dashboard/application/dashboard_controller.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:korkem_flow/features/deals/presentation/deal_detail_screen.dart';
import 'package:korkem_flow/features/notifications/application/notifications_controller.dart';
import 'package:korkem_flow/features/notifications/domain/app_notification.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/quotes/application/quotes_controller.dart';
import 'package:korkem_flow/features/quotes/domain/quote.dart';
import 'package:korkem_flow/features/tasks/application/tasks_controller.dart';
import 'package:korkem_flow/features/tasks/domain/task.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/domain/stock_item.dart';

import '../support/brand_assets.dart';

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

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('login_$suffix.png'),
        );
      });

      testWidgets('dashboard', (tester) async {
        await _pumpApp(tester, brightness: brightness);

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('dashboard_$suffix.png'),
        );
      });

      testWidgets('approvals', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await tester.tap(find.text('Ждут решения'));
        await tester.pumpAndSettle();

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('approvals_$suffix.png'),
        );
      });

      testWidgets('production', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _tapMetric(tester, 'В производстве');

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('production_$suffix.png'),
        );
      });

      testWidgets('notifications', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await tester.tap(find.byTooltip('Уведомления'));
        await tester.pumpAndSettle();

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('notifications_$suffix.png'),
        );
      });

      testWidgets('warehouse', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _tapMetric(tester, 'В производстве');
        await tester.tap(find.text('Склад'));
        await tester.pumpAndSettle();
        // Expanded, because the per-warehouse balance is the whole point of
        // the screen and it does not load until a row is opened.
        await tester.tap(find.text('Фасад МДФ 716×396, белый глянец'));
        await tester.pumpAndSettle();

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('warehouse_$suffix.png'),
        );
      });

      testWidgets('quotes', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Продажи');
        await tester.tap(find.text('Счета'));
        await tester.pumpAndSettle();

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('quotes_$suffix.png'),
        );
      });

      testWidgets('deals', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Продажи');

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('deals_$suffix.png'),
        );
      });

      testWidgets('deal detail', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Продажи');
        await tester.tap(find.text('Астана Мебель Групп'));
        await tester.pumpAndSettle();

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('deal_detail_$suffix.png'),
        );
      });

      testWidgets('tasks', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Задачи');

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('tasks_$suffix.png'),
        );
      });

      testWidgets('profile', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Профиль');

        await precacheBrandAssets(tester);
        await expectLater(
          find.byType(KorkemFlowApp),
          matchesGoldenFile('profile_$suffix.png'),
        );
      });

      // The only golden in this file that does *not* show what a user sees.
      // Tests run in debug, so Settings ends with a "Debug → Design system"
      // row that `kDebugMode` strips from a release build. It is in the image
      // on purpose; a reviewer should not read it as shipping.
      testWidgets('settings', (tester) async {
        await _pumpApp(tester, brightness: brightness);
        await _openTab(tester, 'Профиль');
        await tester.tap(find.byTooltip('Настройки'));
        await tester.pumpAndSettle();

        await precacheBrandAssets(tester);
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
        approvalsControllerProvider.overrideWith(_StubApprovals.new),
        productionControllerProvider.overrideWith(_StubProduction.new),
        quotesControllerProvider.overrideWith(_StubQuotes.new),
        notificationsControllerProvider.overrideWith(_StubNotifications.new),
        unreadNotificationsProvider.overrideWith((ref) => Future.value(3)),
        warehouseControllerProvider.overrideWith(_StubWarehouse.new),
        for (final item in _items)
          stockBalancesProvider(item.id).overrideWith(
            (ref) => Future<List<StockBalance>>.value(_balances[item.id] ?? []),
          ),
        dealsControllerProvider.overrideWith(_StubDeals.new),
        dealDetailProvider(
          _deals.first.id,
        ).overrideWith((ref) => Future<Deal>.value(_dealDetail)),
        tasksControllerProvider.overrideWith(_StubTasks.new),
      ],
      child: const KorkemFlowApp(),
    ),
  );

  await tester.pumpAndSettle();
}

/// Taps a dashboard metric tile, scrolling to it first.
///
/// The dashboard groups its metrics under three headings now instead of
/// showing one six-up grid, so Production sits below the fold — and a ListView
/// does not build what it is not showing, which reads as "the widget does not
/// exist" rather than "you have not scrolled to it".
Future<void> _tapMetric(WidgetTester tester, String label) async {
  final tile = find.text(label);
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(tile);
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

class _StubApprovals extends ApprovalsController {
  @override
  Future<PagedList<PendingAction>> build() async =>
      PagedList(items: _approvals, hasMore: false);
}

class _StubProduction extends ProductionController {
  @override
  Future<PagedList<WorkOrder>> build() async =>
      PagedList(items: _workOrders, hasMore: false);
}

class _StubQuotes extends QuotesController {
  @override
  Future<PagedList<Quote>> build() async =>
      PagedList(items: _quotes, hasMore: false);
}

class _StubWarehouse extends WarehouseController {
  @override
  Future<PagedList<StockItem>> build() async =>
      const PagedList(items: _items, hasMore: false);
}

class _StubNotifications extends NotificationsController {
  @override
  Future<PagedList<AppNotification>> build() async =>
      PagedList(items: _notifications, hasMore: false);
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

/// The same deal as the first list row, with the fields only `fetchOne` loads.
final _dealDetail = Deal(
  id: 'CRM-DEAL-2026-00041',
  organization: 'Астана Мебель Групп',
  status: 'Negotiation',
  nextStep: 'Согласовать смету по фасадам МДФ',
  mobileNo: '+7 701 000 11 22',
  email: 'zakup@astanamebel.kz',
  dealValue: 4850000,
  currency: 'KZT',
  expectedClosureDate: DateTime(2026, 8, 14),
  probability: 65,
  dealOwner: 'aidos@korkem.kz',
  source: 'WhatsApp',
  territory: 'Астана',
  leadId: 'CRM-LEAD-2026-00112',
  modified: _now,
);

final _approvals = <PendingAction>[
  PendingAction(
    id: 'PA-2026-0007',
    status: PendingActionStatus.pending,
    agentSkill: 'Согласовать смету по фасадам',
    entityType: 'CRM Deal',
    entityName: 'CRM-DEAL-2026-00041',
    expiresAt: DateTime(2026, 7, 28, 17),
  ),
  PendingAction(
    id: 'PA-2026-0006',
    status: PendingActionStatus.pending,
    agentSkill: 'Запустить производство',
    entityType: 'CRM Deal',
    entityName: 'CRM-DEAL-2026-00038',
    // Already past the fixed clock, so the golden pins the expired branch:
    // no buttons, because the backend would refuse them.
    expiresAt: DateTime(2026, 7, 27, 9),
  ),
];

final _workOrders = <WorkOrder>[
  WorkOrder(
    id: 'MFG-WO-2026-00019',
    status: WorkOrderStatus.inProcess,
    qty: 40,
    producedQty: 18,
    itemName: 'Фасад МДФ 716×396, белый глянец',
    originatingDeal: 'CRM-DEAL-2026-00041',
    plannedEndDate: DateTime(2026, 8, 2, 17),
  ),
  WorkOrder(
    id: 'MFG-WO-2026-00021',
    status: WorkOrderStatus.notStarted,
    qty: 12,
    itemName: 'Корпус кухонный нижний 600',
    originatingDeal: 'CRM-DEAL-2026-00040',
    plannedEndDate: DateTime(2026, 7, 26, 12),
  ),
  WorkOrder(
    id: 'MFG-WO-2026-00014',
    status: WorkOrderStatus.completed,
    qty: 8,
    producedQty: 8,
    itemName: 'Столешница массив дуб 3000×600',
    originatingDeal: 'CRM-DEAL-2026-00031',
    plannedEndDate: DateTime(2026, 7, 20, 12),
  ),
];

final _notifications = <AppNotification>[
  AppNotification(
    id: 'n1',
    type: NotificationType.assignment,
    // Already stripped, as the repository does — the wire value is
    // "<strong>Администратор</strong> assigned ... to you".
    subject: 'Администратор назначил вам сделку «Астана Мебель Групп»',
    isRead: false,
    documentType: 'CRM Deal',
    documentName: 'CRM-DEAL-2026-00041',
    createdAt: DateTime(2026, 7, 28, 9, 12),
  ),
  AppNotification(
    id: 'n2',
    type: NotificationType.mention,
    subject: 'Дана С. упомянула вас в задаче «Позвонить клиенту по замеру»',
    isRead: false,
    documentType: 'CRM Task',
    documentName: '514',
    createdAt: DateTime(2026, 7, 27, 16, 40),
  ),
  AppNotification(
    id: 'n3',
    type: NotificationType.alert,
    subject: 'Счёт SAL-QTN-2026-00029 истёк без ответа клиента',
    isRead: true,
    documentType: 'Quotation',
    documentName: 'SAL-QTN-2026-00029',
    createdAt: DateTime(2026, 7, 21, 8, 5),
  ),
];

final _quotes = <Quote>[
  Quote(
    id: 'SAL-QTN-2026-00034',
    status: QuoteStatus.open,
    docStatus: 1,
    customerName: 'Астана Мебель Групп',
    transactionDate: DateTime(2026, 7, 24),
    // Inside the seven-day window against the fixed clock, so the golden pins
    // the "expires soon" wording.
    validTill: DateTime(2026, 8, 3),
    grandTotal: 4850000,
    currency: 'KZT',
  ),
  Quote(
    id: 'SAL-QTN-2026-00031',
    status: QuoteStatus.ordered,
    docStatus: 1,
    customerName: 'Қарағанды Интерьер',
    transactionDate: DateTime(2026, 7, 12),
    validTill: DateTime(2026, 8, 12),
    grandTotal: 1290000,
    currency: 'KZT',
  ),
  Quote(
    id: 'SAL-QTN-2026-00029',
    status: QuoteStatus.open,
    docStatus: 1,
    customerName: 'Строй Комфорт KZ',
    transactionDate: DateTime(2026, 6, 30),
    // Already lapsed: ERPNext rewrites `status` on a scheduled job, so this
    // still reads Open on the wire and must render as expired anyway.
    validTill: DateTime(2026, 7, 20),
    grandTotal: 730000,
    currency: 'KZT',
  ),
];

const _items = <StockItem>[
  StockItem(
    id: 'MDF-716-396-WG',
    name: 'Фасад МДФ 716×396, белый глянец',
    itemGroup: 'Фасады',
    stockUom: 'шт',
  ),
  StockItem(
    id: 'LDSP-16-EGGER',
    name: 'ЛДСП 16 мм Egger H1145',
    itemGroup: 'Плитные материалы',
    stockUom: 'лист',
  ),
  StockItem(
    id: 'ASSEMBLY-SERVICE',
    name: 'Монтаж на объекте',
    itemGroup: 'Услуги',
    stockUom: 'час',
    isStockItem: false,
  ),
];

const _balances = <String, List<StockBalance>>{
  'MDF-716-396-WG': [
    StockBalance(
      warehouse: 'Готовая продукция — KRK',
      actualQty: 124,
      reservedQty: 40,
      projectedQty: 84,
    ),
    StockBalance(warehouse: 'Цех — KRK', actualQty: 18, projectedQty: 18),
  ],
  'LDSP-16-EGGER': [
    StockBalance(
      warehouse: 'Сырьё — KRK',
      actualQty: 6,
      reservedQty: 6,
    ),
  ],
};

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
