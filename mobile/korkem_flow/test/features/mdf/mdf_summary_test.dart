import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_summary_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_summary.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_summary_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

import '../../support/widget_harness.dart';

// November so far against October's first part: more orders, a goal set,
// a furniture maker gone quiet, Белый Матовый short for the open orders.
const _json = <String, dynamic>{
  'since': '2026-11-01',
  'until': '2026-11-12',
  'orders': 48,
  'area_m2': 612,
  'total': 14800000,
  'paid': 11200000,
  'debt': 3600000,
  'avg_total': 308000,
  'avg_area': 12.7,
  'rate_m2': 24200,
  'before': {'orders': 40, 'area_m2': 680, 'total': 12800000},
  'stages': [
    {'stage': 'cut', 'orders': 5, 'area_m2': 21},
    {'stage': 'mill', 'orders': 0, 'area_m2': 0},
    {'stage': 'paint', 'orders': 8, 'area_m2': 46},
  ],
  'at_risk': 2,
  'days': [
    {'date': '2026-11-11', 'orders': 3, 'area_m2': 14, 'total': 340000},
    {'date': '2026-11-12', 'orders': 1, 'area_m2': 4.5, 'total': 98000},
  ],
  'customers_count': 21,
  'new_customers': 7,
  'plan': {
    'target_m2': 800,
    'done_m2': 612,
    'done_total': 14800000,
    'days_left': 18,
    'forecast_m2': 1530,
    'forecast_total': 37000000,
    'progress': 0.765,
  },
  'shop': {
    'in_work_m2': 186,
    'in_work_orders': 14,
    'pace_m2_day': 28.0,
    'queue_days': 7,
    'ready_on': '2026-11-20',
    'overdue': 3,
  },
  'top_customers': [
    {
      'customer': 'C-1',
      'customer_name': 'Олжас',
      'orders': 9,
      'area_m2': 142,
      'total': 3400000,
      'tags': ['furniture_maker'],
    },
  ],
  'asleep': [
    {
      'customer': 'C-9',
      'customer_name': 'ИП Ахметов',
      'phone': '8 701 555 12 34',
      'orders': 6,
      'rhythm_days': 12,
      'idle_days': 41,
      'gone': true,
    },
  ],
  'films': [
    {
      'decor': 'Белый Матовый',
      'item': 'MAT-1',
      'orders': 20,
      'area_m2': 214,
      'to_buy_m': 60,
      'free_m': 10,
    },
    {'decor': 'Графит', 'orders': 9, 'area_m2': 120, 'to_buy_m': 0},
  ],
  'millings': [
    {'milling': 'R3', 'area_m2': 355, 'share': 0.58},
  ],
  'deadlines': {
    'handed_over': 22,
    'on_time': 19,
    'on_time_share': 0.864,
    'late_days_avg': 1.5,
  },
  'quality': {
    'orders': 2,
    'area_m2': 24,
    'share': 0.04,
    'returned': 1,
    'reasons': [
      {'reason': 'пузырь на кромке', 'count': 1},
    ],
  },
  'debts': {
    'week': {'amount': 1900000, 'customers': 5},
    'month': {'amount': 1200000, 'customers': 3},
    'older': {'amount': 500000, 'customers': 2},
    'oldest': [
      {
        'customer': 'C-5',
        'customer_name': 'Дом мебели',
        'debt': 300000,
        'days': 44,
      },
    ],
  },
  'managers': [
    {
      'user': 'a@x',
      'name': 'Олжас',
      'orders': 31,
      'area_m2': 402,
      'total': 9600000,
    },
  ],
};

class _Repo implements MdfSummaryRepository {
  final goals = <double?>[];

  @override
  Future<MdfSummary> summary({
    required String since,
    required String until,
  }) async => MdfSummary.fromJson(_json);

  @override
  Future<void> setTarget(double? m2) async => goals.add(m2);
}

class _Orders implements FilmOrdersRepository {
  final added = <(String, double)>[];

  @override
  Future<void> add({
    required String item,
    required double metres,
    String? customer,
    String? supplier,
  }) async => added.add((item, metres));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the summary reads what moved and what is coming', () {
    final s = MdfSummary.fromJson(_json);
    expect(mdfChange(s.now.orders.toDouble(), s.before.orders.toDouble()), 20);
    expect(mdfChange(s.now.areaM2, s.before.areaM2), -10);
    expect(mdfChange(5, 0), isNull);
    expect((s.plan.targetM2, s.shop.queueDays), (800, 7));
    expect(s.asleep.single.gone, isTrue);
    expect(s.debts.olderCustomers, 2);
    expect(
      summaryPeriodOf(SummaryRange.week, DateTime(2026, 11, 12)).since,
      '2026-11-06',
    );
  });

  test('the copied summary is a few lines for WhatsApp', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    final text = mdfSummaryText(
      l10n,
      NumberFormat.currency(locale: 'ru', symbol: '₸', decimalDigits: 0),
      MdfSummary.fromJson(_json),
    );
    expect(text, startsWith('Итоги МДФ 01.11.2026 — 12.11.2026'));
    expect(text, contains('Заказов: 48 · 612.0 м²'));
    expect(text, contains('-10%'));
    expect(text, contains('Уснувших клиентов: 1'));
  });

  testWidgets('the summary shows the plan, the queue, who is asleep', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    final orders = _Orders();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfSummaryRepositoryProvider.overrideWithValue(repo),
          filmOrdersRepositoryProvider.overrideWithValue(orders),
        ],
        child: harness(MdfSummaryScreen(today: DateTime(2026, 11, 12))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('48'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('mdfSum:orders:change')))
          .data,
      '▲ 20% on the last',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('mdfSum:area:change')))
          .data,
      '▼ 10% on the last',
    );
    expect(find.byKey(const ValueKey('mdfSum:readyOn')), findsOneWidget);
    expect(find.text('in 7 d · 20.11'), findsOneWidget);
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('usually every 12 d · none for 41 d'), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfSum:wake:C-9')), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    // A film the open orders lack goes on the day's order list.
    expect(find.text('60 m short'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mdfSum:order:Белый Матовый')));
    await tester.pumpAndSettle();
    expect(orders.added.single, ('MAT-1', 60.0));
    // The month's goal is set from here.
    await tester.tap(find.byKey(const ValueKey('mdfSum:goal')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mdfSum:goalField')),
      '900',
    );
    await tester.tap(find.byKey(const ValueKey('mdfSum:goalSave')));
    await tester.pumpAndSettle();
    expect(repo.goals.single, 900);
    // The dashboard (14.11.2026): what burns, where the orders wait, a bar a
    // day — a tapped one says what came in that day.
    expect(find.byKey(const ValueKey('mdfSum:alert:overdue')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfSum:alert:atRisk')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfSum:alert:film')), findsOneWidget);
    expect(find.byKey(const ValueKey('barRow:paint')), findsOneWidget);
    expect(find.byKey(const ValueKey('barRow:mill')), findsNothing);
    expect(find.byKey(const ValueKey('mdfSum:debtBars')), findsOneWidget);
    final chart = find.byKey(const ValueKey('mdfSum:intakeChart'));
    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    final box = tester.getRect(chart);
    await tester.tapAt(box.topLeft + Offset(box.width * 0.25, 40));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mdfSum:intakeDay'))).data,
      contains('3 orders'),
    );
  });
}
