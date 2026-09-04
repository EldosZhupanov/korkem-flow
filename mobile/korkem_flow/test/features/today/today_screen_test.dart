import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/today/data/today_repository.dart';
import 'package:korkem_flow/features/today/domain/today_summary.dart';
import 'package:korkem_flow/features/today/presentation/today_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

void main() {
  final testDate = DateTime(2026, 9, 4, 9);

  Widget buildHarness({
    required AsyncValue<TodaySummary> summaryState,
    List<RouteBase>? additionalRoutes,
    DateTime? clockDate,
  }) {
    final router = GoRouter(
      initialLocation: Routes.today,
      routes: [
        GoRoute(
          path: Routes.today,
          builder: (context, state) => const TodayScreen(),
        ),
        ...?additionalRoutes,
      ],
    );

    return ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => clockDate ?? testDate),
        todaySummaryProvider.overrideWith((ref) => summaryState.value!),
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

  Widget buildErrorHarness({
    required Object error,
    DateTime? clockDate,
  }) {
    final router = GoRouter(
      initialLocation: Routes.today,
      routes: [
        GoRoute(
          path: Routes.today,
          builder: (context, state) => const TodayScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => clockDate ?? testDate),
        todaySummaryProvider.overrideWith(
          (ref) => Future<TodaySummary>.error(error),
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

  group('TodayScreen', () {
    testWidgets('shows localized header date', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          summaryState: const AsyncData(TodaySummary()),
          clockDate: DateTime(2026, 9, 4),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Сегодня, 4 сентября'), findsWidgets);
    });

    testWidgets('1. строка с нулём не показывается', (tester) async {
      // Data matching the mockup partially:
      // only overdue and dueThisWeek are non-zero.
      const summary = TodaySummary(
        overdueOrders: 3,
        dueThisWeekOrders: 7,
      );

      await tester.pumpWidget(
        buildHarness(summaryState: const AsyncData(summary)),
      );
      await tester.pumpAndSettle();

      // Non-zero rows are rendered with their numbers and labels
      expect(find.text('Просрочено'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('заказа'), findsOneWidget);

      expect(find.text('Сдать на этой неделе'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('заказов'), findsOneWidget);

      // Zero-value rows MUST NOT be shown
      expect(find.text('Сдать сегодня'), findsNothing);
      expect(find.text('Не оплачено'), findsNothing);
      expect(find.text('Материала не хватает'), findsNothing);
      expect(find.text('Монтаж сегодня'), findsNothing);
      expect(find.text('Требует решения'), findsNothing);

      // No good news / empty badges for zero counts
      expect(find.textContaining(': 0'), findsNothing);
      expect(find.textContaining('0 заказов'), findsNothing);
    });

    testWidgets('2. всё по нулям — показывается объяснение, а не пустота', (
      tester,
    ) async {
      const emptySummary = TodaySummary();

      await tester.pumpWidget(
        buildHarness(summaryState: const AsyncData(emptySummary)),
      );
      await tester.pumpAndSettle();

      // Explanation state is visible
      expect(find.text('Всё под контролем'), findsOneWidget);
      expect(
        find.text(
          'На сегодня нет просрочек, дефицита материалов и действий, '
          'требующих решения.',
        ),
        findsOneWidget,
      );

      // No metric rows rendered
      expect(find.text('Просрочено'), findsNothing);
      expect(find.text('Сдать сегодня'), findsNothing);
      expect(find.text('Сдать на этой неделе'), findsNothing);
      expect(find.text('Не оплачено'), findsNothing);
      expect(find.text('Материала не хватает'), findsNothing);
      expect(find.text('Монтаж сегодня'), findsNothing);
      expect(find.text('Требует решения'), findsNothing);
    });

    testWidgets('3. нажатие ведёт туда, куда обещает', (tester) async {
      const fullSummary = TodaySummary(
        overdueOrders: 3,
        dueTodayOrders: 2,
        dueThisWeekOrders: 7,
        unpaidAmount: 1240000,
        materialDeficitCount: 4,
        installationsToday: 1,
        pendingApprovals: 2,
      );

      String? lastNavigatedUri;

      final additionalRoutes = [
        GoRoute(
          path: Routes.orders,
          builder: (context, state) {
            lastNavigatedUri = state.uri.toString();
            return const Scaffold(body: Text('Orders Screen'));
          },
        ),
        GoRoute(
          path: Routes.items,
          builder: (context, state) {
            lastNavigatedUri = state.uri.toString();
            return const Scaffold(body: Text('Items Screen'));
          },
        ),
        GoRoute(
          path: Routes.tasks,
          builder: (context, state) {
            lastNavigatedUri = state.uri.toString();
            return const Scaffold(body: Text('Tasks Screen'));
          },
        ),
        GoRoute(
          path: Routes.approvals,
          builder: (context, state) {
            lastNavigatedUri = state.uri.toString();
            return const Scaffold(body: Text('Approvals Screen'));
          },
        ),
      ];

      await tester.pumpWidget(
        buildHarness(
          summaryState: const AsyncData(fullSummary),
          additionalRoutes: additionalRoutes,
        ),
      );
      await tester.pumpAndSettle();

      // All 7 rows are displayed
      expect(find.text('Просрочено'), findsOneWidget);
      expect(find.text('Сдать сегодня'), findsOneWidget);
      expect(find.text('Сдать на этой неделе'), findsOneWidget);
      expect(find.text('Не оплачено'), findsOneWidget);
      expect(find.text('Материала не хватает'), findsOneWidget);
      expect(find.text('Монтаж сегодня'), findsOneWidget);
      expect(find.text('Требует решения'), findsOneWidget);

      // 1. Tap "Просрочено" -> /orders?filter=overdue
      await tester.tap(find.text('Просрочено'));
      await tester.pumpAndSettle();
      expect(lastNavigatedUri, '/orders?filter=overdue');
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      // 2. Tap "Сдать сегодня" -> /orders?filter=due_today
      await tester.tap(find.text('Сдать сегодня'));
      await tester.pumpAndSettle();
      expect(lastNavigatedUri, '/orders?filter=due_today');
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      // 3. Tap "Сдать на этой неделе" -> /orders?filter=due_this_week
      await tester.tap(find.text('Сдать на этой неделе'));
      await tester.pumpAndSettle();
      expect(lastNavigatedUri, '/orders?filter=due_this_week');
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      // 4. Tap "Не оплачено" -> /orders?filter=unpaid
      await tester.tap(find.text('Не оплачено'));
      await tester.pumpAndSettle();
      expect(lastNavigatedUri, '/orders?filter=unpaid');
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      // 5. Tap "Материала не хватает" -> /items?filter=deficit
      await tester.tap(find.text('Материала не хватает'));
      await tester.pumpAndSettle();
      expect(lastNavigatedUri, '/items?filter=deficit');
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      // 6. Tap "Монтаж сегодня" -> /tasks?filter=today
      await tester.tap(find.text('Монтаж сегодня'));
      await tester.pumpAndSettle();
      expect(lastNavigatedUri, '/tasks?filter=today');
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      // 7. Tap "Требует решения" -> /dashboard/approvals
      await tester.tap(find.text('Требует решения'));
      await tester.pumpAndSettle();
      expect(lastNavigatedUri, '/dashboard/approvals');
    });

    testWidgets('4. отказ сервера показан его словами', (tester) async {
      await tester.pumpWidget(
        buildErrorHarness(
          error: const ServerFailure(
            'Сервер перегружен: сервис оперативной сводки временно недоступен',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Сервер перегружен: сервис оперативной сводки временно недоступен',
        ),
        findsOneWidget,
      );
      expect(find.text('Повторить'), findsOneWidget);
    });
  });
}
