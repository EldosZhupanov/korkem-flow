import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/features/mdf/domain/shop_board.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_plan_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tv_screen.dart';

import '../../support/widget_harness.dart';

final _plan = MdfPlan.fromJson(const {
  'stages': [
    {
      'stage': 'cut',
      'area_m2': 3.04,
      'orders': [
        {
          'name': 'SAL-ORD-1129',
          'customer_name': 'Арман',
          'delivery_date': '2026-11-10',
          'decor_top': 'Венге (Korkem)',
          'area_m2': 3.04,
          'overdue': true,
          'days_left': -1,
          'stages_left': 4,
          'at_risk': false,
        },
        {
          'name': 'SAL-ORD-40',
          'customer_name': 'Ерлан',
          'delivery_date': '2026-11-09',
          'area_m2': 1.2,
          'days_left': 1,
          'stages_left': 5,
          'at_risk': true,
          'tags': ['urgent'],
        },
      ],
    },
    {'stage': 'mill', 'area_m2': 0, 'orders': <Object>[]},
    {
      'stage': 'vacuum',
      'area_m2': 9.6,
      'orders': [
        {
          'name': 'SAL-ORD-36',
          'customer_name': 'Тұрсын',
          'delivery_date': '2026-11-12',
          'area_m2': 9.6,
          'days_left': 4,
          'stages_left': 1,
        },
      ],
    },
  ],
  'intake': [
    {'date': '2026-11-06', 'orders': 2, 'area_m2': 12.64},
  ],
  'in_work_m2': 12.64,
});

/// «Цех» (26.11.2026): the month, the stages with their people, the late.
final _board = ShopBoard.fromJson(const {
  'month': {
    'plan_m2': 400,
    'plan_from': 'due',
    'done_m2': 260,
    'expected_m2': 333,
    'forecast_m2': 312,
    'in_shop_m2': 85,
    'in_shop_orders': 31,
    'taken_m2': 350,
    'taken_orders': 112,
  },
  'stages': [
    {
      'stage': 'cut',
      'waiting_m2': 4.24,
      'waiting_orders': 2,
      'today_m2': 9,
      'month_m2': 305,
      'per_day_m2': 10,
      'days': 0.4,
      'posts': [
        {
          'post': 'cut.cutter',
          'title': 'Раскройщик',
          'people': [
            {
              'employee': 'HR-1',
              'name': 'Владимир',
              'today_m2': 9,
              'in_work': 3,
            },
          ],
        },
      ],
    },
    {
      'stage': 'mill',
      'waiting_m2': 24,
      'today_m2': 6,
      'days': 3.0,
      'jam': true,
      'posts': [
        {'post': 'cnc.operator', 'title': 'ЧПУшник', 'people': <Object>[]},
      ],
      'nobody': true,
    },
    {'stage': 'sand', 'waiting_m2': 0},
    {'stage': 'vacuum', 'waiting_m2': 9.6, 'waiting_orders': 1},
    {'stage': 'paint', 'waiting_m2': 0},
    {'stage': 'ready', 'waiting_m2': 11},
  ],
  'late': [
    {
      'order': 'SAL-ORD-1129',
      'number': 1129,
      'customer': 'Арман',
      'stage': 'cut',
      'delivery_date': '2026-11-10',
      'area_m2': 3.04,
      'overdue': true,
    },
  ],
  'side': [
    {
      'department': 'film_sales',
      'title': 'Продажа плёнки',
      'sales_today': 4,
      'metres_today': 120,
      'posts': [
        {
          'post': 'film_sales.seller',
          'title': 'Продажник',
          'people': <Object>[],
        },
      ],
    },
  ],
});

void main() {
  testWidgets('«Цех»: the month, the stages, the late; a stage shows its '
      'orders', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfPlanProvider.overrideWith((ref) async => _plan),
          shopBoardProvider.overrideWith((ref) async => _board),
        ],
        child: harness(MdfPlanScreen(today: DateTime(2026, 11, 26))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop:month')), findsOne);
    expect(find.byKey(const ValueKey('shop:flow')), findsOne);
    expect(find.byKey(const ValueKey('stage:mill:days')), findsOne);
    // A post with nobody on it says so.
    expect(
      find.byKey(const ValueKey('stage:mill:nobody:cnc.operator')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('shop:late:SAL-ORD-1129')), findsOne);
    expect(find.byKey(const ValueKey('shop:side:film_sales')), findsOne);
    // No stage tapped: no orders list yet. Tap one — its orders alone.
    expect(find.byKey(const ValueKey('plan:cut:SAL-ORD-1129')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stage:vacuum')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan:vacuum:SAL-ORD-36')), findsOne);
    expect(find.byKey(const ValueKey('plan:cut:SAL-ORD-1129')), findsNothing);
    expect(find.byKey(const ValueKey('shop:late')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stage:vacuum')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop:late')), findsOne);
  });

  testWidgets('each stage shows its orders; an empty stage is not shown', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Until the board answers (here: never), «Жоспар» as it was.
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          mdfPlanProvider.overrideWith((ref) async => _plan),
          shopBoardProvider.overrideWith(
            (ref) => Future<ShopBoard>.error(StateError('no board')),
          ),
        ],
        child: harness(const MdfPlanScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('planInWork')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan:cut:SAL-ORD-1129')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan:vacuum:SAL-ORD-36')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('planTick:SAL-ORD-1129')), findsOneWidget);
    // The traffic light: late is red, tomorrow yellow, later green.
    expect(
      find.byKey(const ValueKey('deadline:SAL-ORD-1129:now')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('deadline:SAL-ORD-40:tomorrow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('deadline:SAL-ORD-36:later')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('atRisk:SAL-ORD-40')), findsOneWidget);
    expect(find.byKey(const ValueKey('atRisk:SAL-ORD-36')), findsNothing);
    // The stages as bars; an empty stage has none. Tap one: its orders alone.
    expect(find.byKey(const ValueKey('barRow:cut')), findsOneWidget);
    expect(find.byKey(const ValueKey('barRow:mill')), findsNothing);
    expect(find.byKey(const ValueKey('planIntakeChart')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('barRow:vacuum')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan:cut:SAL-ORD-1129')), findsNothing);
    expect(
      find.byKey(const ValueKey('plan:vacuum:SAL-ORD-36')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('barRow:vacuum')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan:cut:SAL-ORD-1129')), findsOneWidget);
  });

  test('a day count is a traffic light', () {
    expect(MdfDeadline.of(-3), MdfDeadline.now);
    expect(MdfDeadline.of(0), MdfDeadline.now);
    expect(MdfDeadline.of(1), MdfDeadline.tomorrow);
    expect(MdfDeadline.of(2), MdfDeadline.later);
    expect(MdfDeadline.of(null), MdfDeadline.later);
  });

  test('the wall screen puts each order in its column, urgent first', () {
    final columns = mdfTvColumns(_plan);
    expect(
      [for (final o in columns[MdfDeadline.now]!) o.name],
      [
        'SAL-ORD-1129',
      ],
    );
    expect(
      [for (final o in columns[MdfDeadline.tomorrow]!) o.name],
      [
        'SAL-ORD-40',
      ],
    );
    expect(
      [for (final o in columns[MdfDeadline.later]!) o.name],
      [
        'SAL-ORD-36',
      ],
    );
    expect(columns[MdfDeadline.tomorrow]!.single.urgent, isTrue);
  });

  testWidgets('the wall screen shows three columns and asks again by itself', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var asked = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfPlanProvider.overrideWith((ref) async {
            asked++;
            return _plan;
          }),
        ],
        child: harness(const MdfTvScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (final d in MdfDeadline.values) {
      expect(find.byKey(ValueKey('tv:${d.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('tvOrder:SAL-ORD-40')), findsOneWidget);
    expect(asked, 1);
    await tester.pump(mdfTvRefresh);
    await tester.pumpAndSettle();
    expect(asked, 2);
  });
}
