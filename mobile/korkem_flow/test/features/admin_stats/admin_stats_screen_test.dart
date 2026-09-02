import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/admin_stats/application/admin_stats_controller.dart';
import 'package:korkem_flow/features/admin_stats/data/admin_stats_repository.dart';
import 'package:korkem_flow/features/admin_stats/domain/admin_stats.dart';
import 'package:korkem_flow/features/admin_stats/presentation/admin_stats_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeAdminStatsRepository extends AdminStatsRepository {
  _FakeAdminStatsRepository(this._handler) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());
  final Future<AdminStats> Function(int days) _handler;

  @override
  Future<AdminStats> getStats({int days = 30}) => _handler(days);
}

class _TestDaysNotifier extends AdminStatsDaysNotifier {
  _TestDaysNotifier(this._initial);
  final int _initial;

  @override
  int build() => _initial;
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required AdminStatsRepository repository,
    int initialDays = 30,
    Locale locale = const Locale('ru'),
  }) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        adminStatsRepositoryProvider.overrideWithValue(repository),
        adminStatsDaysProvider.overrideWith(
          () => _TestDaysNotifier(initialDays),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminStatsScreen(),
      ),
    );
  }

  testWidgets('renders prominent warning when stale > 0 with funnel metrics', (
    tester,
  ) async {
    final repo = _FakeAdminStatsRepository((days) async {
      return const AdminStats(
        days: 30,
        caught: 47,
        handedOver: 45,
        converted: 12,
        dismissed: 3,
        stale: 2,
      );
    });

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Цифровой администратор'), findsOneWidget);
    expect(find.text('ТРЕБУЕТ ВНИМАНИЯ: ПРОТУХЛО'), findsOneWidget);
    expect(
      find.text('2 обращения не переданы в работу более 24 часов'),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);

    // Funnel KPI Tiles
    expect(find.text('Поймано обращений'), findsOneWidget);
    expect(find.text('47'), findsOneWidget);
    expect(find.text('Передано человеку'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('Стало заказами'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Отброшено осознанно'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Decision summary
    expect(find.text('Итог для решения о найме'), findsOneWidget);
  });

  testWidgets(
    'renders good news affirmation when stale == 0 and has captures',
    (tester) async {
      final repo = _FakeAdminStatsRepository((days) async {
        return AdminStats(
          days: days,
          caught: 50,
          handedOver: 50,
          converted: 18,
          dismissed: 4,
          stale: 0,
        );
      });

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('ОТЛИЧНЫЙ РЕЗУЛЬТАТ'), findsOneWidget);
      expect(
        find.text('За 30 дней не потеряно ни одного обращения'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Все зафиксированные обращения вовремя переданы человеку или закрыты',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders clean empty state when caught == 0', (tester) async {
    final repo = _FakeAdminStatsRepository((days) async {
      return AdminStats(
        days: days,
        caught: 0,
        handedOver: 0,
        converted: 0,
        dismissed: 0,
        stale: 0,
      );
    });

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Пока ничего не поймано'), findsOneWidget);
    expect(
      find.text(
        'За выбранный период не зафиксировано обращений. '
        'Новые сообщения из каналов и мессенджеров появятся здесь.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('switching period requests stats with new days count', (
    tester,
  ) async {
    var requestedDays = 0;
    final repo = _FakeAdminStatsRepository((days) async {
      requestedDays = days;
      return AdminStats(
        days: days,
        caught: 10,
        handedOver: 10,
        converted: 3,
        dismissed: 0,
        stale: 0,
      );
    });

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(requestedDays, 30);

    // Switch to Week (7 days)
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();

    expect(requestedDays, 7);
    expect(
      find.text('За 7 дней не потеряно ни одного обращения'),
      findsOneWidget,
    );

    // Switch to 3 months (90 days)
    await tester.tap(find.text('3 месяца'));
    await tester.pumpAndSettle();

    expect(requestedDays, 90);
    expect(
      find.text('За 90 дней не потеряно ни одного обращения'),
      findsOneWidget,
    );
  });

  testWidgets('shows error state and retries on tap', (tester) async {
    var fail = true;
    final repo = _FakeAdminStatsRepository((days) async {
      if (fail) throw const NetworkFailure('Network timeout');
      return const AdminStats(
        days: 30,
        caught: 5,
        handedOver: 5,
        converted: 1,
        dismissed: 0,
        stale: 0,
      );
    });

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Нет связи с сервером.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('ОТЛИЧНЫЙ РЕЗУЛЬТАТ'), findsOneWidget);
  });
}
