import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/film_shortage.dart';
import 'package:korkem_flow/features/mdf/presentation/film_shortage_screen.dart';

import '../../support/widget_harness.dart';

/// OnayBaza's «Пленка» of 06.11.2026, in short: Венге is short, Белый is not.
final _report = FilmShortage.fromJson(const {
  'by_film': [
    {
      'decor': 'Венге (Korkem)',
      'item': 'FILM-1',
      'title': 'Венге (Korkem)',
      'unit': 'м',
      'orders': 2,
      'needed': 12.4,
      'held': 4.2,
      'free': 0,
      'to_buy': 8.2,
    },
    {
      'decor': 'Белый матовый (JS group)',
      'item': null,
      'title': 'Белый матовый (JS group)',
      'unit': 'м',
      'orders': 1,
      'needed': 3.1,
      'held': 3.1,
      'free': 0,
      'to_buy': 0,
    },
  ],
  'orders': [
    {
      'order': 'SAL-ORD-1129',
      'customer_name': 'Арман Қалдыбаев',
      'delivery_date': '2026-11-10',
      'decor': 'Венге (Korkem)',
      'needed': 6.2,
      'held': 0,
      'short': 6.2,
    },
  ],
  'needed_total': 15.5,
  'to_buy_total': 8.2,
});

void main() {
  testWidgets('what to buy is red, what is enough is green, totals on top', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmShortageProvider.overrideWith((ref) async => _report)],
        child: harness(const FilmShortageScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmTotals')), findsOneWidget);
    expect(find.textContaining('8.2'), findsWidgets);
    expect(
      find.byKey(const ValueKey('filmBuy:Венге (Korkem)')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('filmOrder:SAL-ORD-1129:Венге (Korkem)')),
      findsOneWidget,
    );
  });
}
