import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_plan_screen.dart';

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
  });
}
