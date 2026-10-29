import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/logistics/data/logistics_repository.dart';
import 'package:korkem_flow/features/logistics/domain/logistics.dart';
import 'package:korkem_flow/features/logistics/presentation/logistics_screen.dart';

import '../../support/widget_harness.dart';

/// The owner's month of 29.10.2026: a Газель of MDF and four films.
const Map<String, Object> _summary = {
  'month': '2026-10',
  'total': 45500,
  'count': 5,
  'previous_total': 30000,
  'by_category': [
    {'name': 'Плёнка ПВХ', 'amount': 35500, 'count': 4, 'average_days': 7},
    {'name': 'МДФ', 'amount': 10000, 'count': 1, 'average_days': null},
  ],
  'by_city': [
    {'name': 'Караганда', 'amount': 25000, 'count': 1},
  ],
  'by_transport': [
    {'name': 'Такси', 'amount': 34000, 'count': 3},
  ],
  'by_carrier': [
    {'name': 'Тайбазаров', 'amount': 1500, 'count': 1, 'average_days': 7},
  ],
  'per_unit': [
    {
      'category': 'МДФ',
      'unit': 'лист',
      'amount': 10000,
      'qty': 30,
      'per_unit': 333.33,
    },
  ],
  'urgent': {'count': 1, 'amount': 4000},
  'unlinked_receipts': [
    {
      'receipt': 'MAT-STE-1',
      'date': '2026-10-28',
      'title': 'МДФ 16 мм Kastamonu',
      'qty': 30,
      'unit': 'лист',
    },
  ],
};

class _FakeRepository implements LogisticsRepository {
  final recorded = <NewDelivery>[];
  final cancelled = <(String, String)>[];

  @override
  Future<List<Delivery>> deliveries(String month) async => [
    Delivery.fromJson(const {
      'delivery': 'LOG-00001',
      'delivered_on': '2026-10-13',
      'ordered_on': '2026-10-06',
      'days': 7,
      'category': 'Плёнка ПВХ',
      'amount': 1500,
      'from_city': 'Алматы',
      'transport': 'Транспортная компания',
      'carrier': 'Тайбазаров',
      'sales_order': '1132',
      'what': 'Белый СМ',
      'qty': 27.9,
      'unit': 'м',
    }),
  ];

  @override
  Future<LogisticsSummary> summary(String month) async =>
      LogisticsSummary.fromJson(_summary);

  @override
  Future<LogisticsSuggestions> suggestions() async =>
      LogisticsSuggestions.fromJson(const {
        'cities': ['Астана', 'Алматы'],
        'transports': ['Газель', 'Такси'],
        'carriers': <String>[],
        'categories': ['МДФ', 'Плёнка ПВХ', 'Прочее'],
      });

  @override
  Future<void> record(NewDelivery delivery) async => recorded.add(delivery);

  @override
  Future<void> cancel(String delivery, String reason) async =>
      cancelled.add((delivery, reason));
}

void main() {
  Future<_FakeRepository> pump(WidgetTester tester) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [logisticsRepositoryProvider.overrideWithValue(repo)],
        child: harness(const LogisticsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test('the summary reads the server breakdown', () {
    final s = LogisticsSummary.fromJson(_summary);
    expect(s.byCategory.map((g) => g.amount), [35500, 10000]);
    expect(s.byCarrier.single.averageDays, 7);
    expect(s.perUnit.single.perUnit, 333.33);
    expect((s.urgentCount, s.urgentAmount), (1, 4000));
    expect(s.unlinked.single.receipt, 'MAT-STE-1');
  });

  test('a delivery is sent with only what was filled in', () {
    final params = NewDelivery(
      amount: 5000,
      fromCity: 'Астана',
      transport: 'Такси',
      category: 'Плёнка ПВХ',
      deliveredOn: DateTime(2026, 10, 5),
      urgent: true,
      salesOrder: '1127',
    ).toParams();
    expect(params['delivered_on'], '2026-10-05');
    expect(params['urgent'], 1);
    expect(params['sales_order'], '1127');
    expect(params.containsKey('carrier'), isFalse);
  });

  testWidgets('the month lists its deliveries with the road they took', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('delivery:LOG-00001')), findsOneWidget);
    expect(find.textContaining('Тайбазаров'), findsOneWidget);
    expect(find.textContaining('7 days on the road'), findsOneWidget);
  });

  testWidgets('the summary shows the month, per unit, and what is unwritten', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('logisticsTotal')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('logisticsPerUnit:МДФ:лист')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('logisticsWrite:MAT-STE-1')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('logisticsSummaryList')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.byKey(const ValueKey('logisticsWrite:MAT-STE-1')),
      findsOneWidget,
    );
  });

  testWidgets('a taxi for an order is written from the form', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('logisticsAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Плёнка ПВХ').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('deliveryAmount')),
      '5000',
    );
    for (final chip in [
      'deliveryCityChip:Астана',
      'deliveryTransportChip:Такси',
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(chip)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(chip)));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('deliveryOrder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('deliveryOrder')), '1127');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('deliverySave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deliverySave')));
    await tester.pumpAndSettle();

    final saved = repo.recorded.single;
    expect(
      (saved.amount, saved.fromCity, saved.transport, saved.category),
      (5000.0, 'Астана', 'Такси', 'Плёнка ПВХ'),
    );
    expect(saved.salesOrder, '1127');
  });
}
