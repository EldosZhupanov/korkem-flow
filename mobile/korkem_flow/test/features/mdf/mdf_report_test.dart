import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_report.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_report_screen.dart';

import '../../support/widget_harness.dart';

final _report = MdfReport.fromJson(const {
  'since': '2026-11-01',
  'until': '2026-11-07',
  'orders': 2,
  'area_m2': 12.64,
  'total': 243480,
  'paid': 200000,
  'debt': 43480,
  'cancelled': 1,
  'by_status': [
    {'status': 'in_shop', 'orders': 1, 'area_m2': 3.04, 'total': 58680},
    {'status': 'handed_over', 'orders': 1, 'area_m2': 9.6, 'total': 184800},
  ],
  'by_decor': [
    {'decor': 'Венге', 'orders': 2, 'area_m2': 12.64, 'total': 243480},
  ],
  'top_customers': [
    {
      'customer': 'C-1',
      'customer_name': 'Арман',
      'orders': 2,
      'area_m2': 12.64,
      'total': 243480,
      'debt': 43480,
    },
  ],
});

void main() {
  test('this month, last month and the year end where they should', () {
    final today = DateTime(2026, 11, 7);
    expect(reportPeriodOf(ReportRange.thisMonth, today), (
      since: '2026-11-01',
      until: '2026-11-07',
    ));
    expect(reportPeriodOf(ReportRange.lastMonth, today), (
      since: '2026-10-01',
      until: '2026-10-31',
    ));
    expect(
      reportPeriodOf(ReportRange.lastMonth, DateTime(2027, 1, 5)).since,
      '2026-12-01',
    );
    expect(reportPeriodOf(ReportRange.year, today).since, '2026-01-01');
  });

  testWidgets('totals, statuses, films and who owes', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfReportProvider.overrideWith((ref, p) async => _report),
        ],
        child: harness(MdfReportScreen(today: DateTime(2026, 11, 7))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reportOrders')), findsOneWidget);
    expect(find.byKey(const ValueKey('reportStatus:in_shop')), findsOneWidget);
    expect(find.byKey(const ValueKey('reportDecor:Венге')), findsOneWidget);
    expect(find.byKey(const ValueKey('reportCustomer:C-1')), findsOneWidget);
    expect(find.textContaining('owes'), findsOneWidget);
  });
}
