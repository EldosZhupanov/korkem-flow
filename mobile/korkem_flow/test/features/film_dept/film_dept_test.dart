import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_screen.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';

import '../../support/widget_harness.dart';

const _stock = <String, dynamic>{
  'films': [
    {
      'item': 'MAT-1',
      'maker': 'KIRA',
      'colour': 'Белый Матовый',
      'label': 'KIRA · Белый Матовый',
      'code': 'KR-101',
      'on_hand': 84,
      'held': 0,
      'retail_m': 3900,
      'wholesale_m': 3400,
    },
    {
      'item': 'MAT-2',
      'maker': 'JS Group',
      'colour': 'Графит',
      'label': 'JS Group · Графит',
      'on_hand': 6,
      'held': 0,
      'low': true,
    },
  ],
  'suppliers': [
    {'supplier': 'SUP-1', 'name': 'МС-Груп', 'enabled': true},
  ],
  'can_edit': true,
};

class _Fake implements FilmDeptRepository {
  final writeOffs = <(String, double, String)>[];
  final sold =
      <(String, List<({String item, double metres, double priceM})>, double)>[];
  final terms = <(String, bool, double)>[];

  @override
  Future<FilmCatalog> stock() async => FilmCatalog.fromJson(_stock);

  @override
  Future<List<FilmMove>> history(String item) async => const [
    FilmMove(
      entry: 'STE-1',
      date: '2026-11-02',
      kind: FilmMoveKind.receipt,
      metres: 50,
      priceM: 3300,
      party: 'МС-Груп',
    ),
    FilmMove(
      entry: 'STE-2',
      date: '2026-11-05',
      kind: FilmMoveKind.sale,
      metres: -12,
      party: 'Мебель-ЮГ',
    ),
  ];

  @override
  Future<void> writeOff({
    required String item,
    required double metres,
    required String reason,
  }) async => writeOffs.add((item, metres, reason));

  @override
  Future<FilmPrice> priceFor(String item, {String? customer}) async =>
      FilmPrice(
        wholesale: customer == 'CUST-1',
        priceM: customer == 'CUST-1' ? 3298 : 3900,
      );

  @override
  Future<FilmSale> sell({
    required String customer,
    required List<({String item, double metres, double priceM})> lines,
    double paid = 0,
    String? method,
    String? bank,
  }) async {
    sold.add((customer, lines, paid));
    return const FilmSale(entry: 'STE-9', date: '2026-11-10');
  }

  final paid = <(String, double, String)>[];
  final cancelled = <(String, String)>[];

  @override
  Future<List<FilmSale>> sales() async => const [
    FilmSale(
      entry: 'STE-7',
      date: '2026-11-09',
      customer: 'CUST-1',
      customerName: 'Мебель-ЮГ',
      amount: 46800,
      paid: 20000,
      debt: 26800,
      lines: [
        FilmSaleLine(
          item: 'MAT-1',
          title: 'KIRA · Белый Матовый',
          metres: 12,
          priceM: 3900,
        ),
      ],
    ),
  ];

  @override
  Future<FilmSale> pay(
    String entry, {
    required double amount,
    required String method,
    String? bank,
  }) async {
    paid.add((entry, amount, method));
    return const FilmSale(entry: 'STE-7', date: '2026-11-09');
  }

  @override
  Future<void> cancel(String entry, String reason) async =>
      cancelled.add((entry, reason));

  @override
  Future<List<FilmCustomer>> customers() async => const [
    FilmCustomer(
      customer: 'CUST-1',
      name: 'Мебель-ЮГ',
      wholesale: true,
      discount: 3,
      monthM: 120,
      total: 468000,
      last: '2026-11-05',
    ),
    FilmCustomer(
      customer: 'CUST-2',
      name: 'ИП Ахметов',
      total: 92000,
      last: '2026-08-28',
      idleDays: 74,
      asleep: true,
    ),
  ];

  @override
  Future<void> setCustomer(
    String customer, {
    required bool wholesale,
    required double discount,
  }) async => terms.add((customer, wholesale, discount));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Fake> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Fake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        filmDeptRepositoryProvider.overrideWithValue(repo),
        mdfCustomersProvider.overrideWith(
          (ref) async => const [
            FacadeCustomer(name: 'CUST-1', title: 'Мебель-ЮГ'),
          ],
        ),
        mdfDictionariesProvider.overrideWith(
          (ref) async => MdfDictionaries.empty,
        ),
      ],
      child: harness(const FilmDeptScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('metres read as the shop says them', () {
    expect(filmMetres(84), '84');
    expect(filmMetres(1.5), '1,5');
    expect(filmMetres(42.25), '42,25');
    expect(FilmMoveKind.of('write_off'), FilmMoveKind.writeOff);
    final sale = FilmSale.fromJson(const {
      'entry': 'STE-1',
      'date': '2026-11-10',
      'amount': 46800,
      'paid': 20000,
      'debt': 26800,
      'lines': [
        {'item': 'MAT-1', 'title': 'KIRA · Белый Матовый', 'metres': 12},
      ],
    });
    expect((sale.metres, sale.debt), (12, 26800));
  });

  testWidgets('the stock lists each film with its metres; a low one says so', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('KIRA · Белый Матовый'), findsOneWidget);
    expect(find.text('84 м'), findsOneWidget);
    expect(find.text('6 m · low'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmDept:low')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmStock:MAT-1')), findsNothing);
    expect(find.byKey(const ValueKey('filmStock:MAT-2')), findsOneWidget);
  });

  testWidgets('a write-off needs metres and a reason', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-1')));
    await tester.pumpAndSettle();
    // The film's page: what is free, and what came and left.
    expect(find.byKey(const ValueKey('filmPage:free')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmMove:1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmPage:writeOff')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('filmIssueSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '1,5');
    await tester.pumpAndSettle();
    // Metres alone are not enough: why it left must be said.
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('filmReason:0')));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.writeOffs.single, ('MAT-1', 1.5, 'Sample for a customer'));
  });

  testWidgets("a sale takes the customer's price and no more than is there", (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmDept:sell')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('filmSaleSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('filmSaleCustomer:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мебель-ЮГ').last);
    await tester.pumpAndSettle();
    // More than lies on the shelf is refused.
    await tester.enterText(
      find.byKey(const ValueKey('filmSaleMetres:0')),
      '100',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('filmSaleMetres:0')),
      '10',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final (customer, lines, paid) = repo.sold.single;
    // The trade price of this customer, and paid in full unless said.
    expect(customer, 'CUST-1');
    expect(lines.single, (item: 'MAT-1', metres: 10.0, priceM: 3298.0));
    expect(paid, 32980);
  });

  testWidgets('customers: who buys most first, and who fell asleep', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:customers')));
    await tester.pumpAndSettle();
    expect(find.text('120 m this month'), findsOneWidget);
    expect(find.textContaining('asleep · 74 d'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmCustomer:CUST-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmTier:wholesale')));
    await tester.enterText(find.byKey(const ValueKey('filmDiscount')), '5');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmTermsSave')));
    await tester.pumpAndSettle();
    expect(repo.terms.single, ('CUST-2', true, 5.0));
  });

  testWidgets('a sale in debt is paid off from its card, no more than owed', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:sales')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSaleRow:0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmSaleCardDebt')), findsOneWidget);
    final pay = find.byKey(const ValueKey('filmPaySave'));
    // The whole debt is offered; more than is owed is refused.
    await tester.enterText(
      find.byKey(const ValueKey('filmPayAmount')),
      '30000',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(pay).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('filmPayAmount')),
      '26800',
    );
    await tester.pumpAndSettle();
    await tester.tap(pay);
    await tester.pumpAndSettle();
    expect(repo.paid.single, ('STE-7', 26800.0, 'Наличные'));
  });

  testWidgets('a sale entered by mistake is cancelled with a reason', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:sales')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSaleRow:0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSaleCancel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmCancelReason')),
      'Не тот клиент',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done').last);
    await tester.pumpAndSettle();
    expect(repo.cancelled.single, ('STE-7', 'Не тот клиент'));
  });
}
