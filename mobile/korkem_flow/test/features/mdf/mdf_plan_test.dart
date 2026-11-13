import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
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

void main() {
  testWidgets('each stage shows its orders; an empty stage is not shown', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfPlanProvider.overrideWith((ref) async => _plan)],
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
