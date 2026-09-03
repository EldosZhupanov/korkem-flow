import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/today/application/today_controller.dart';
import 'package:korkem_flow/features/today/data/today_attention_repository.dart';
import 'package:korkem_flow/features/today/domain/today_attention.dart';
import 'package:korkem_flow/features/today/presentation/today_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeTodayAttentionRepository extends TodayAttentionRepository {
  _FakeTodayAttentionRepository({required this.attention}) : super(dummyClient);

  static final dummyDio = Dio();
  static final dummyClient = FrappeClient(dummyDio);

  final TodayAttention attention;

  @override
  Future<TodayAttention> fetchTodayAttention() async => attention;
}

void main() {
  /// Экран стал длинным: сверху сводки, ниже — то, что застряло. `ListView`
  /// строит лениво, поэтому в окне на 600 точек нижняя половина просто не
  /// существует, и тест ищет то, чего никто не рисовал. Окно на высоту экрана.
  Future<void> pumpScreen(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Widget buildHarness({
    required _FakeTodayAttentionRepository repo,
    List<RouteBase>? additionalRoutes,
    bool stockFails = false,
  }) {
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const TodayScreen(),
        ),
        ...?additionalRoutes,
      ],
    );

    return ProviderScope(
      // Riverpod 3 повторяет упавший провайдер с задержкой, и он навсегда
      // остаётся «загружается», а не «упал». В тесте нам нужен именно отказ.
      retry: (_, _) => null,
      overrides: [
        todayAttentionRepositoryProvider.overrideWithValue(repo),
        // Сводки заглушены целиком: без этого экран уходит в сеть, и картинка
        // теста начинает зависеть от того, кто ответил первым.
        todayOrdersSummaryProvider.overrideWith(
          (ref) async => const TodayOrdersSummary(
            activeCount: 0,
            lateCount: 0,
            totalCount: 0,
          ),
        ),
        todayProductionSummaryProvider.overrideWith(
          (ref) async =>
              const TodayProductionSummary(inProcessCount: 0, lateCount: 0),
        ),
        todayApprovalsSummaryProvider.overrideWith(
          (ref) async => const TodayApprovalsSummary(pendingCount: 0),
        ),
        todayStockSummaryProvider.overrideWith(
          (ref) async => stockFails
              ? throw Exception('склад недоступен')
              : const TodayStockSummary(deficitCount: 0),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets(
    'renders single all-clear hero when all four attention groups are empty',
    (tester) async {
      final repo = _FakeTodayAttentionRepository(
        attention: const TodayAttention(),
      );

      await pumpScreen(tester, buildHarness(repo: repo));

      expect(find.text('Что требует внимания'), findsOneWidget);
      expect(find.text('Всё под контролем'), findsOneWidget);
      expect(
        find.textContaining('Все обращения переданы, просрочек нет'),
        findsOneWidget,
      );

      // Ensure 4 group headers are NOT rendered when all clear
      expect(find.text('Не передано в работу'), findsNothing);
      expect(find.text('Просроченные задачи'), findsNothing);
      expect(find.text('Заказы без дизайна'), findsNothing);
      expect(find.text('Отгружено без счёта'), findsNothing);
    },
  );

  testWidgets(
    'renders four groups, showing items for active ones '
    'and good news for empty ones',
    (tester) async {
      final repo = _FakeTodayAttentionRepository(
        attention: const TodayAttention(
          unassignedCaptures: [
            UnassignedCaptureItem(
              capture: 'CAP-001',
              said: 'Заказчик просит прихожую',
              since: '2026-09-02 09:00',
              customer: 'Аскар',
            ),
          ],
          ordersWithoutDesign: [
            OrderWithoutDesignItem(
              salesOrder: 'SAL-ORD-2026-00001',
              customer: 'ТОО Мебель',
              due: '2026-09-20',
            ),
          ],
          deliveredNotInvoiced: [
            DeliveredNotInvoicedItem(
              salesOrder: 'SAL-ORD-2026-00002',
              customer: 'ЖК Батыс',
              total: 2500000,
              deliveredPercent: 100,
            ),
          ],
        ),
      );

      await pumpScreen(tester, buildHarness(repo: repo));

      // Group 1: Has item
      expect(find.text('Не передано в работу'), findsOneWidget);
      expect(find.text('«Заказчик просит прихожую»'), findsOneWidget);
      expect(find.textContaining('Аскар'), findsOneWidget);

      // Group 2: Empty -> Good news!
      expect(find.text('Просроченные задачи'), findsOneWidget);
      expect(
        find.text('Всё в срок: нет просроченных замеров, дизайнов и монтажей'),
        findsOneWidget,
      );

      // Group 3: Has item
      expect(find.text('Заказы без дизайна'), findsOneWidget);
      expect(find.text('SAL-ORD-2026-00001'), findsOneWidget);
      expect(find.textContaining('ТОО Мебель'), findsOneWidget);

      // Group 4: Has item
      expect(find.text('Отгружено без счёта'), findsOneWidget);
      expect(find.textContaining('SAL-ORD-2026-00002'), findsOneWidget);
      expect(find.textContaining('ЖК Батыс'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping attention items navigates to target resolution screens',
    (tester) async {
      String? navigatedRoute;

      final repo = _FakeTodayAttentionRepository(
        attention: const TodayAttention(
          unassignedCaptures: [
            UnassignedCaptureItem(
              capture: 'CAP-001',
              said: 'Заказчик просит прихожую',
              since: '2026-09-02',
              customer: 'Аскар',
            ),
          ],
          overdueTasks: [
            OverdueTaskItem(
              task: 'TASK-001',
              title: 'Замер',
              who: 'Ерлан',
              wasDue: '2026-09-01',
              on: 'SAL-ORD-2026-00099',
            ),
          ],
          ordersWithoutDesign: [
            OrderWithoutDesignItem(
              salesOrder: 'SAL-ORD-2026-00001',
              customer: 'ТОО Мебель',
            ),
          ],
        ),
      );

      final additionalRoutes = [
        GoRoute(
          path: '/enquiry-flow',
          builder: (context, state) {
            navigatedRoute =
                '/enquiry-flow?capture=${state.uri.queryParameters['capture']}';
            return const Scaffold(body: Text('Enquiry Flow Screen'));
          },
        ),
        GoRoute(
          path: '/orders/:name',
          builder: (context, state) {
            navigatedRoute = '/orders/${state.pathParameters['name']}';
            return const Scaffold(body: Text('Order Detail Screen'));
          },
        ),
      ];

      await pumpScreen(
        tester,
        buildHarness(repo: repo, additionalRoutes: additionalRoutes),
      );
      await tester.pumpAndSettle();

      // Tap capture -> navigates to enquiry-flow with capture parameter
      await tester.tap(find.text('«Заказчик просит прихожую»'));
      await tester.pumpAndSettle();
      expect(navigatedRoute, '/enquiry-flow?capture=CAP-001');

      // Go back to today
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      // Tap overdue task linked to Sales Order -> navigates to order
      await tester.tap(find.text('Замер'));
      await tester.pumpAndSettle();
      expect(navigatedRoute, '/orders/SAL-ORD-2026-00099');
    },
  );

  testWidgets('упавшая сводка не прячет список дел', (tester) async {
    // Склад недоступен — это не повод оставить владельца без списка того, что
    // застряло. Раньше сводки и дела жили на разных экранах, и такой вопрос не
    // возникал; теперь они рядом, и падение одной половины должно оставаться
    // падением одной половины.
    final repo = _FakeTodayAttentionRepository(
      attention: const TodayAttention(
        unassignedCaptures: [
          UnassignedCaptureItem(
            capture: 'CAP-001',
            said: 'Заказчик просит прихожую',
            since: '2026-09-02',
            customer: 'Данияр',
          ),
        ],
      ),
    );

    await pumpScreen(
      tester,
      buildHarness(repo: repo, stockFails: true),
    );

    expect(find.text('Не удалось загрузить'), findsOneWidget);
    expect(find.textContaining('Заказчик просит прихожую'), findsOneWidget);
    expect(find.text('Не передано в работу'), findsOneWidget);
  });
}
