import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_debts.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_debts_screen.dart';

import '../../support/widget_harness.dart';

/// Two of OnayBaza's «Қарыз» rows of 06.11.2026.
final _debts = MdfDebts.fromJson(const {
  'customers': [
    {
      'customer': 'Даурен',
      'customer_name': 'Даурен',
      'orders': 2,
      'debt': 274845,
    },
    {
      'customer': 'Жанболат',
      'customer_name': 'Жанболат',
      'orders': 1,
      'debt': 7480,
    },
  ],
  'orders': [
    {
      'name': 'SAL-ORD-1147',
      'created_on': '2026-11-02',
      'customer': 'Даурен',
      'customer_name': 'Даурен',
      'total': 259335,
      'paid': 0,
      'debt': 259335,
      'handed_over': true,
    },
    {
      'name': 'SAL-ORD-1148',
      'created_on': '2026-11-02',
      'customer': 'Даурен',
      'customer_name': 'Даурен',
      'total': 15510,
      'paid': 0,
      'debt': 15510,
    },
    {
      'name': 'SAL-ORD-1158',
      'created_on': '2026-11-04',
      'customer': 'Жанболат',
      'customer_name': 'Жанболат',
      'total': 7480,
      'paid': 0,
      'debt': 7480,
    },
  ],
  'total': 282325,
});

void main() {
  testWidgets('the total, the customers, and every order that owes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfDebtsProvider.overrideWith((ref) async => _debts)],
        child: harness(const MdfDebtsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('debtsTotal')), findsOneWidget);
    expect(find.byKey(const ValueKey('debtCustomer:Даурен')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('debtOrder:SAL-ORD-1158')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('debtOrder:SAL-ORD-1158')),
      findsOneWidget,
    );
  });
}
