import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_cash.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_cash_screen.dart';

import '../../support/widget_harness.dart';

const Map<String, Object> _day = {
  'date': '2026-11-07',
  'in': 50000,
  'out': 3500,
  'net': 46500,
  'by_method': {'Kaspi': 30000, 'Наличные': 20000},
};

const Map<String, Object> _rest = {
  'by_method': [
    {'method': 'Kaspi', 'amount': 30000},
    {'method': 'Наличные', 'amount': 20000},
  ],
  'payments': [
    {
      'date': '2026-11-07',
      'method': 'Kaspi',
      'order': 'SAL-ORD-1129',
      'customer_name': 'Арман',
      'amount': 30000,
    },
  ],
  'expenses': [
    {
      'date': '2026-11-07',
      'purpose': 'Пилки',
      'category': 'Инструмент',
      'amount': 3500,
    },
  ],
  'total_in': 50000,
  'total_out': 3500,
  'net': 46500,
};

MdfCash _cash(MdfPeriod p) => MdfCash.fromJson({
  ..._rest,
  'since': p.since,
  'until': p.until,
  'days': [
    _day,
    if (p.since != p.until)
      const <String, Object>{
        'date': '2026-11-06',
        'in': 0,
        'out': 0,
        'net': 0,
        'by_method': <String, Object>{},
      },
  ],
});

void main() {
  test('a range ends today and goes back 0, 6 or 29 days', () {
    final today = DateTime(2026, 11, 7);
    expect(cashPeriodOf(CashRange.today, today), (
      since: '2026-11-07',
      until: '2026-11-07',
    ));
    expect(cashPeriodOf(CashRange.week, today).since, '2026-11-01');
    expect(cashPeriodOf(CashRange.month, today).since, '2026-10-09');
  });

  testWidgets('totals, methods; a longer range shows the days', (
    tester,
  ) async {
    final asked = <MdfPeriod>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfCashProvider.overrideWith((ref, p) async {
            asked.add(p);
            return _cash(p);
          }),
        ],
        child: harness(MdfCashScreen(today: DateTime(2026, 11, 7))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cashIn')), findsOneWidget);
    expect(find.byKey(const ValueKey('cashMethod:Kaspi')), findsOneWidget);
    expect(find.byKey(const ValueKey('cashDay:2026-11-07')), findsNothing);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(asked.last, (since: '2026-11-01', until: '2026-11-07'));
    expect(find.byKey(const ValueKey('cashDay:2026-11-06')), findsOneWidget);
  });
}
