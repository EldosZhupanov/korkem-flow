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
  final remembered = <String>{};
  final parts = <List<({double amount, String method, String? bank})>>[];
  final received = <(String, double, double, bool)>[];
  final deliveries = <(Map<String, Object?>?, String?)>[];
  final sellers = <String?>[];
  final teamSet = <(double, double, double)>[];

  @override
  Future<FilmDeliveryOptions> deliveryOptions() async =>
      FilmDeliveryOptions.fromJson(const {
        'transports': ['Привёз поставщик', 'Такси'],
        'cities': ['Алматы', 'Астана'],
        'last': {
          'SUP-1': {'transport': 'Такси', 'city': 'Алматы'},
        },
        'staff': [
          {'user': 'a@k.kz', 'name': 'Айбек'},
          {'user': 'b@k.kz', 'name': 'Бауыржан'},
        ],
        'me': 'a@k.kz',
      });

  @override
  Future<FilmTeam> team(String? month) async => FilmTeam.fromJson(const {
    'month': '2026-11',
    'rows': [
      {
        'seller': 'a@k.kz',
        'name': 'Айбек',
        'metres': 120,
        'sales': 4,
        'paid': 400000,
        'margin': 60000,
        'share': 75,
        'bonus': 4500,
      },
      {
        'seller': 'b@k.kz',
        'name': 'Бауыржан',
        'metres': 40,
        'sales': 1,
        'paid': 130000,
        'margin': 20000,
        'share': 25,
        'bonus': 1500,
      },
    ],
    'team': {'metres': 160, 'sales': 5, 'paid': 530000, 'margin': 80000},
    'plan_m': 200,
    'done': 80,
    'pct': 7.5,
    'pot': 6000,
    'settings': {'plan_m': 200, 'pct': 10, 'pct_below': 7.5},
    'can_set': true,
  });

  @override
  Future<void> setTeamSettings({
    required double planM,
    required double pct,
    required double pctBelow,
  }) async => teamSet.add((planM, pct, pctBelow));
  final corrected = <(String, String, String, double?)>[];

  @override
  Future<void> correct({
    required String entry,
    required String item,
    required String reason,
    double? metres,
    double? priceM,
    String? supplier,
    String? order,
    String? why,
  }) async => corrected.add((entry, item, reason, metres));

  @override
  Future<void> receive({
    required String item,
    required double metres,
    required double priceM,
    required String supplier,
    bool updatePrice = true,
    Map<String, Object?>? delivery,
    String? receivedBy,
  }) async {
    received.add((item, metres, priceM, updatePrice));
    deliveries.add((delivery, receivedBy));
  }

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
    List<({double amount, String method, String? bank})> payments = const [],
    Set<String> remember = const {},
    String? seller,
  }) async {
    sellers.add(seller);
    remembered.addAll(remember);
    parts.add(payments);
    sold.add((customer, lines, payments.fold(0, (s, p) => s + p.amount)));
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

  testWidgets('a movement entered wrong is put right with a reason', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-1')));
    await tester.pumpAndSettle();
    // The sale of 12 m was really 10.
    await tester.tap(find.byKey(const ValueKey('filmMove:1')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('filmCorrect:save'));
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '10');
    await tester.pumpAndSettle();
    // Why must be said.
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('filmCorrect:reason')),
      'ошибся в метраже',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.corrected.single, ('STE-2', 'MAT-1', 'ошибся в метраже', 10.0));
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

  testWidgets('a receipt puts its price on the card unless unticked', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmPage:receive')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '10');
    await tester.enterText(find.byKey(const ValueKey('filmPrice')), '3500');
    await tester.pumpAndSettle();
    // The card has no purchase price yet: the receipt offers to put it.
    final tick = find.byKey(const ValueKey('filmReceiveUpdatePrice'));
    expect(tick, findsOneWidget);
    await tester.tap(tick);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceiveSave')));
    await tester.pumpAndSettle();
    expect(repo.received.single, ('MAT-1', 10.0, 3500.0, false));
    // How it came: as this supplier's last roll — by taxi from Almaty —
    // nothing paid, taken in by whoever is signed in.
    expect(repo.deliveries.single.$1, {
      'transport': 'Такси',
      'city': 'Алматы',
      'amount': 0.0,
      'urgent': false,
    });
    expect(repo.deliveries.single.$2, 'a@k.kz');
  });

  testWidgets('a receipt says how it came, what that cost, who took it in', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmPage:receive')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '10');
    await tester.enterText(find.byKey(const ValueKey('filmPrice')), '3500');
    await tester.tap(
      find.byKey(const ValueKey('filmDelivery:transport:Привёз поставщик')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmDelivery:cost')),
      '5000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmDelivery:urgent')));
    await tester.tap(find.byKey(const ValueKey('filmDelivery:taker:2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Бауыржан').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceiveSave')));
    await tester.pumpAndSettle();
    expect(repo.deliveries.single.$1, {
      'transport': 'Привёз поставщик',
      'city': 'Алматы',
      'amount': 5000.0,
      'urgent': true,
    });
    expect(repo.deliveries.single.$2, 'b@k.kz');
  });

  testWidgets('the team: the month by seller, the pot, the owner sets it', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:team')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmTeam:row:a@k.kz')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmTeam:row:b@k.kz')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmTeam:pot')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmTeam:plan')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmTeam:settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmTeam:planM')), '250');
    await tester.tap(find.byKey(const ValueKey('filmTeam:save')));
    await tester.pumpAndSettle();
    expect(repo.teamSet.single, (250.0, 10.0, 7.5));
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

  testWidgets('a sale is paid several ways at once, the rest a debt', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmDept:sell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSaleCustomer:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мебель-ЮГ').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmSaleMetres:0')),
      '10',
    );
    await tester.pumpAndSettle();
    // 32 980 in all: 10 000 cash, the rest — offered — by transfer.
    await tester.enterText(find.byKey(const ValueKey('filmSalePaid')), '10000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSaleAddPart')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('filmSalePaid:1')))
          .controller!
          .text,
      '22980',
    );
    // Less is paid by transfer: the rest stays a debt.
    await tester.enterText(
      find.byKey(const ValueKey('filmSalePaid:1')),
      '20000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSaleSave')));
    await tester.pumpAndSettle();
    expect(repo.parts.single, [
      (amount: 10000.0, method: 'Наличные', bank: null),
      (amount: 20000.0, method: 'Перевод', bank: null),
    ]);
    expect(repo.sold.single.$3, 30000);
    // Sold by whoever is signed in, unless another seller is picked.
    expect(repo.sellers.single, 'a@k.kz');
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
