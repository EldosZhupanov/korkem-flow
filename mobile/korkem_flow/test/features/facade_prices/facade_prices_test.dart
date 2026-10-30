import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/facade_prices/data/facade_price_repository.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_price_table.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/facade_prices/presentation/facade_prices_screen.dart';
import 'package:korkem_flow/features/facade_prices/presentation/facade_quote_screen.dart';

import '../../support/widget_harness.dart';

const _pvc = 'ПВХ плёнка';
const _enamel = 'Эмаль';

FacadePriceTable _table({bool canEdit = true, double kvadroPvc = 21000}) =>
    FacadePriceTable(
      finishes: const [_pvc, _enamel],
      prices: [
        FacadePrice(milling: 'Квадро', finish: _pvc, pricePerM2: kvadroPvc),
        const FacadePrice(
          milling: 'Квадро',
          finish: _enamel,
          pricePerM2: 35000,
        ),
        const FacadePrice(milling: 'Тегіс', finish: _pvc, pricePerM2: 17000),
      ],
      canEdit: canEdit,
    );

class _FakeRepository implements FacadePriceRepository {
  _FakeRepository(this.table);

  FacadePriceTable table;
  final saves = <(String, String, double)>[];

  @override
  Future<FacadePriceTable> fetch() async => table;

  @override
  Future<FacadePriceTable> save({
    required String milling,
    required String finish,
    required double pricePerM2,
    bool enabled = true,
  }) async {
    saves.add((milling, finish, pricePerM2));
    return table = _table(kvadroPvc: pricePerM2);
  }

  FacadeRules currentRules = const FacadeRules();
  final quoted = <List<FacadeLineInput>>[];
  final ordered = <(String, DateTime, int)>[];

  @override
  Future<List<FacadeCustomer>> customers({String? search}) async => const [
    FacadeCustomer(name: 'CUST-1', title: 'ТОО Уют', phone: '+7 700 000 00 00'),
  ];

  @override
  Future<FacadeOrderResult> createOrder({
    required String customer,
    required DateTime deliveryDate,
    required List<FacadeLineInput> lines,
    bool demolition = false,
    double? prepaymentAmount,
  }) async {
    ordered.add((customer, deliveryDate, lines.length));
    return const FacadeOrderResult(
      salesOrder: 'SAL-ORD-2026-00099',
      total: 8400,
      prepayment: 4200,
      balance: 4200,
    );
  }

  @override
  Future<FacadeRules> fetchRules() async => currentRules;

  @override
  Future<FacadeRules> saveRules(FacadeRules rules) async =>
      currentRules = rules;

  @override
  Future<FacadeQuote> quote(
    List<FacadeLineInput> lines, {
    bool demolition = false,
    double? prepaymentAmount,
  }) async {
    quoted.add(lines);
    return const FacadeQuote(
      pieces: 2,
      areaM2: 0.4,
      facadesTotal: 8400,
      demolition: 0,
      total: 8400,
      prepayment: 4200,
      balance: 4200,
      prepaymentSource: 'settings',
      lineAmounts: [8400],
    );
  }
}

void main() {
  group('FacadePriceTable', () {
    test('reads the server matrix', () {
      final table = FacadePriceTable.fromJson(const {
        'finishes': [_pvc, _enamel],
        'prices': [
          {
            'milling': 'Квадро',
            'finish': _pvc,
            'price_per_m2': 21000,
            'enabled': true,
          },
        ],
        'can_edit': true,
      });
      expect(table.cell('Квадро', _pvc)?.pricePerM2, 21000);
      expect(table.canEdit, isTrue);
    });

    test('a combination the factory does not sell has no cell', () {
      expect(_table().cell('Тегіс', _enamel), isNull);
    });

    test('lists each milling once', () {
      expect(_table().millings, ['Квадро', 'Тегіс']);
    });
  });

  Future<_FakeRepository> pump(WidgetTester tester, FacadePriceTable t) async {
    final repo = _FakeRepository(t);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [facadePriceRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FacadePricesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('a manager edits a price and sees what the server stored', (
    tester,
  ) async {
    final repo = await pump(tester, _table());

    await tester.tap(find.byKey(const ValueKey('facadePrice:Квадро:$_pvc')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('facadePriceValue')),
      '22000',
    );
    await tester.tap(find.byKey(const ValueKey('facadePriceSave')));
    await tester.pumpAndSettle();

    expect(repo.saves, [('Квадро', _pvc, 22000.0)]);
    expect(find.textContaining('22'), findsWidgets);
  });

  testWidgets('somebody who may not edit gets no pencil and no add button', (
    tester,
  ) async {
    await pump(tester, _table(canEdit: false));

    expect(find.byKey(const ValueKey('facadePriceAdd')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('facadePrice:Квадро:$_pvc')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the quote screen sends the sizes and shows the server totals', (
    tester,
  ) async {
    final repo = _FakeRepository(_table());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [facadePriceRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FacadeQuoteScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('facadeQuoteWidth:0')),
      '500',
    );
    await tester.enterText(
      find.byKey(const ValueKey('facadeQuoteHeight:0')),
      '400',
    );
    await tester.enterText(find.byKey(const ValueKey('facadeQuoteQty:0')), '2');
    await tester.tap(find.byKey(const ValueKey('facadeQuoteCalculate')));
    await tester.pumpAndSettle();

    final sent = repo.quoted.single.single;
    expect((sent.widthMm, sent.heightMm, sent.qty), (500.0, 400.0, 2));
    expect(sent.milling, 'Квадро');
    expect(find.byKey(const ValueKey('facadeQuoteTotals')), findsOneWidget);
  });

  test('a line sends its spec only when one was chosen', () {
    const plain = FacadeLineInput(
      widthMm: 500,
      heightMm: 400,
      qty: 1,
      milling: 'Квадро',
      finish: _pvc,
    );
    expect(plain.toJson().containsKey('decor_top'), isFalse);

    const specified = FacadeLineInput(
      widthMm: 500,
      heightMm: 400,
      qty: 1,
      milling: 'Квадро',
      finish: _pvc,
      thicknessMm: 19,
      decorTop: 'Графит',
      edgeProfile: 'R3',
    );
    final json = specified.toJson();
    expect(
      (json['thickness_mm'], json['decor_top'], json['edge_profile']),
      (19, 'Графит', 'R3'),
    );
    expect(json.containsKey('decor_bottom'), isFalse);
  });

  testWidgets('options nobody configured are not offered', (tester) async {
    final repo = _FakeRepository(_table());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [facadePriceRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FacadeQuoteScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byKey(const ValueKey('facadeQuoteDemolition')), findsNothing);
  });

  testWidgets('a calculated quote becomes an order for the chosen customer', (
    tester,
  ) async {
    final repo = _FakeRepository(_table());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [facadePriceRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FacadeQuoteScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('facadeQuoteWidth:0')),
      '500',
    );
    await tester.enterText(
      find.byKey(const ValueKey('facadeQuoteHeight:0')),
      '400',
    );
    await tester.tap(find.byKey(const ValueKey('facadeQuoteCalculate')));
    await tester.pumpAndSettle();

    final create = find.byKey(const ValueKey('facadeOrderCreate'));
    await tester.scrollUntilVisible(
      create,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('facadeOrderCustomer')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('facadeOrderCustomer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ТОО Уют'));
    await tester.pumpAndSettle();

    // Scrolled to, not just found: the list builds lazily, and with the folded
    // spec on each line the date row can sit just past the visible edge.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('facadeOrderDate')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('facadeOrderDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      create,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(repo.ordered.single.$1, 'CUST-1');
    expect(repo.ordered.single.$3, 1);
  });
}
