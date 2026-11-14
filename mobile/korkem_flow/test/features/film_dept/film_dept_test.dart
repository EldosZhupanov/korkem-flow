import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/domain/film_orders.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_screen.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_orders_page.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_print.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

import '../../support/widget_harness.dart';

const _stock = <String, dynamic>{
  'films': [
    {
      'item': 'MAT-1',
      'maker': 'KIRA',
      'colour': 'Белый Матовый',
      'label': 'KIRA · Белый Матовый',
      'code': 'KR-101',
      'daily_m': 2,
      'days_left': 42,
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
      'price_m': 3100,
      'price_since': {
        'price_m': {'date': '2026-10-10', 'via': 'приход'},
      },
      'on_hand': 6,
      'held': 0,
      'low': true,
      'reorder': {
        'metres': 50,
        'supplier': 'SUP-1',
        'supplier_name': 'МС-Груп',
        'price_m': 3100,
      },
      'coming': [
        {
          'entry': 'STE-30',
          'metres': 30,
          'due': '2026-11-13',
          'late_days': 1,
          'supplier': 'МС-Груп',
        },
      ],
    },
  ],
  'suppliers': [
    {'supplier': 'SUP-1', 'name': 'МС-Груп', 'enabled': true},
  ],
  'can_edit': true,
  'wanted': 2,
  'waiting': 1,
};

// The day's list: МС-Груп is to be sent Графит that ran out and Белый
// Матовый for a customer and the shelf; Kira was sent a list at 10:20.
const _wanted = <String, dynamic>{
  'count': 2,
  'metres': 100,
  'waiting': 1,
  'can_edit': true,
  'suppliers': [
    {
      'supplier': 'SUP-1',
      'name': 'МС-Груп',
      'phone': '+7 701 000 00 01',
      'order_until': '16:00',
      'open': [
        {
          'id': 'FORD-1',
          'item': 'MAT-1',
          'title': 'KIRA · Белый Матовый',
          'metres': 20,
          'customer': 'CUST-1',
          'customer_name': 'Мебель-ЮГ',
          'at': '09:10',
        },
        {
          'id': 'FORD-2',
          'item': 'MAT-1',
          'title': 'KIRA · Белый Матовый',
          'metres': 30,
          'at': '14:55',
        },
        {
          'item': 'MAT-2',
          'title': 'JS Group · Графит',
          'metres': 50,
          'auto': true,
        },
      ],
      'sent': <Object>[],
    },
    {
      'supplier': 'SUP-2',
      'name': 'Kira',
      'open': <Object>[],
      'sent': [
        {
          'id': 'FORD-7',
          'item': 'MAT-1',
          'title': 'KIRA · Белый Матовый',
          'metres': 15,
          'customer': 'CUST-2',
          'customer_name': 'ИП Ахметов',
        },
      ],
      'sent_at': '2026-11-12 10:20',
    },
  ],
};

class _Orders implements FilmOrdersRepository {
  final added = <(String, double, String?)>[];
  final dropped = <(String?, String?)>[];
  final sentTo = <String?>[];
  final deliveries = <(String, List<FilmDeliveryLine>, String?)>[];
  final deliveriesPaid = <bool>[];

  @override
  Future<FilmWanted> wanted() async => FilmWanted.fromJson(_wanted);

  @override
  Future<void> add({
    required String item,
    required double metres,
    String? customer,
    String? supplier,
  }) async => added.add((item, metres, customer));

  @override
  Future<void> update(String line, {required double metres}) async {}

  @override
  Future<void> drop({String? line, String? item}) async =>
      dropped.add((line, item));

  @override
  Future<void> sent(String? supplier) async => sentTo.add(supplier);

  @override
  Future<void> receiveMany({
    required String supplier,
    required List<FilmDeliveryLine> lines,
    Map<String, Object?>? delivery,
    String? receivedBy,
    String? arrivesOn,
    bool supplierPaid = true,
  }) async {
    deliveries.add((supplier, lines, arrivesOn));
    deliveriesPaid.add(supplierPaid);
  }

  @override
  Future<void> arrivedBatch(String batch) async {}

  @override
  Future<List<FilmForProduction>> forProduction(String item) async => [
    (
      order: 'SO-998',
      customerName: 'Дастан',
      deliveryDate: '2026-11-18',
      needed: 6.2,
      short: 6.2,
    ),
  ];
}

/// The last pump's list of what is to be ordered.
late _Orders _orders;

class _Fake implements FilmDeptRepository {
  final writeOffs = <(String, double, String)>[];
  final sold =
      <(String, List<({String item, double metres, double priceM})>, double)>[];
  final terms = <(String, bool, double)>[];
  final remembered = <String>{};
  final parts = <List<({double amount, String method, String? bank})>>[];
  final received = <(String, double, double, bool)>[];
  final deliveries = <(Map<String, Object?>?, String?)>[];
  final arrivals = <String?>[];
  final came = <(String, double?)>[];

  final settled = <(String, String)>[];
  final supplierPaidFor = <(String, String, String)>[];
  final receivedPaid = <bool>[];

  @override
  Future<FilmCashBook> cash(String? since, String? until) async =>
      FilmCashBook.fromJson(const {
        'since': '2026-11-11',
        'until': '2026-11-11',
        'in': [
          {'way': 'Наличные', 'amount': 8000},
        ],
        'in_total': 8000,
        'out': [
          {
            'date': '2026-11-11',
            'what': 'Такси',
            'amount': 5000,
            'way': 'Наличные',
            'receipt': 'STE-1',
          },
        ],
        'out_total': 5000,
        'balance': 3000,
        'sales': 1,
        'spent': 1,
        'where': [
          {'way': 'Наличные', 'amount': 3000},
        ],
        // Counted at yesterday's close: what the drawer started with.
        'opening': {'cash': 45000, 'closed_on': '2026-11-10'},
        'moves': [
          {
            'date': '2026-11-11',
            'in': true,
            'amount': 8000,
            'way': 'Наличные',
            'what': 'Мебель-ЮГ',
          },
        ],
        'days': [
          {'date': '2026-11-10', 'in': 0, 'out': 0},
          {'date': '2026-11-11', 'in': 8000, 'out': 5000},
        ],
        'previous': {'in_total': 4000, 'out_total': 5000, 'balance': -1000},
        'logistics': 10000,
        'logistics_per_m': 200,
        'owed': {
          'employees': [
            {
              'receipt': 'STE-3',
              'date': '2026-11-11',
              'amount': 3000,
              'name': 'Айбек',
              'supplier': 'МС-Груп',
            },
          ],
          'carriers': [
            {
              'receipt': 'STE-4',
              'date': '2026-11-11',
              'amount': 2000,
              'transport': 'КАМАЗ',
              'driver': 'Ерлан',
              'phone': '+7 701 555 12 34',
            },
          ],
          'suppliers': [
            {
              'receipt': 'STE-5',
              'date': '2026-11-10',
              'amount': 96000,
              'metres': 30,
              'film': 'KIRA Дуб',
              'supplier': 'МС-Груп',
              'coming': false,
            },
          ],
        },
      });

  final closes = <(String, double, String?)>[];

  @override
  Future<void> closeDay(String day, double counted, {String? reason}) async =>
      closes.add((day, counted, reason));

  @override
  Future<void> settleDelivery(String receipt, String method) async =>
      settled.add((receipt, method));

  @override
  Future<void> paySupplier(
    String receipt,
    String method, {
    String source = FilmPaySource.dept,
  }) async => supplierPaidFor.add((receipt, method, source));

  @override
  Future<void> arrived(String entry, {double? metres}) async =>
      came.add((entry, metres));
  final sellers = <String?>[];
  final teamSet = <(double, double, double)>[];
  final holds = <(String, String, double)>[];

  @override
  Future<void> hold({
    required String item,
    required String customer,
    required double metres,
    String? until,
  }) async => holds.add((item, customer, metres));

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
        'drivers': [
          {
            'driver': 'Ерлан',
            'phone': '+7 701 555 12 34',
            'transport': 'Такси',
          },
        ],
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
  Future<FilmReport> report(String? month) async => FilmReport.fromJson(const {
    'month': '2026-11',
    'metres': 50,
    'amount': 200000,
    'margin': 40000,
    'top': [
      {
        'item': 'MAT-1',
        'title': 'KIRA · Белый Матовый',
        'metres': 50,
        'amount': 200000,
        'margin': 40000,
        'margin_m': 800,
      },
    ],
    'idle': [
      {
        'item': 'MAT-2',
        'title': 'JS Group · Графит',
        'on_hand': 6,
        'days': 75,
        'value': 18000,
      },
    ],
    'idle_days': 60,
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
    String? arrivesOn,
    bool supplierPaid = true,
  }) async {
    receivedPaid.add(supplierPaid);
    arrivals.add(arrivesOn);
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
    String? issuedBy,
    String? belowReason,
  }) async {
    belowReasons.add(belowReason);
    sellers.add(seller);
    remembered.addAll(remember);
    parts.add(payments);
    sold.add((customer, lines, payments.fold(0, (s, p) => s + p.amount)));
    return const FilmSale(entry: 'STE-9', date: '2026-11-10');
  }

  final paid = <(String, double, String)>[];
  final cancelled = <(String, String)>[];
  final belowReasons = <String?>[];

  @override
  Future<List<FilmSale>> sales({
    String? customer,
    String? since,
    String? until,
  }) async => const [
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
      phone: '8 701 555 12 34',
      wholesale: true,
      discount: 3,
      debt: 26800,
      debtDays: 12,
      debtLimit: 30000,
      rhythmDays: 7,
      call: 'debt',
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
    double? debtLimit,
    int? debtDays,
  }) async {
    terms.add((customer, wholesale, discount));
    limits.add((debtLimit, debtDays));
  }

  final limits = <(double?, int?)>[];

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
        filmOrdersRepositoryProvider.overrideWithValue(_orders = _Orders()),
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
  TestWidgetsFlutterBinding.ensureInitialized();

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
    // The shelf at a glance: 90 m, 30 m on its way, one running out, one
    // to order — and what burns is first on the list.
    String figure(String id) => tester
        .widget<Text>(find.byKey(ValueKey('figure:filmStock:$id:value')))
        .data!;
    expect(
      [for (final id in ['onHand', 'onWay', 'runsOut', 'toOrder']) figure(id)],
      ['90 м', '30 м', '1', '1'],
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('filmStock:MAT-2'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('filmStock:MAT-1'))).dy,
      ),
    );
    expect(find.byKey(const ValueKey('filmStock:order:MAT-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmDept:low')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmStock:MAT-1')), findsNothing);
    expect(find.byKey(const ValueKey('filmStock:MAT-2')), findsOneWidget);
  });

  testWidgets('the stock: receipt first, filters, a search, days left', (
    tester,
  ) async {
    await _pump(tester);
    // Goods in comes first, then the sale (owner, 13.11.2026).
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('filmDept:receive'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('filmDept:sell'))).dx,
      ),
    );
    expect(find.text('KR-101 · lasts ≈ 42 d'), findsOneWidget);
    expect(find.text('On the way · 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmDept:filter:onWay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmStock:MAT-1')), findsNothing);
    expect(find.byKey(const ValueKey('filmStock:MAT-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmDept:filter:all')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmDept:search')),
      'граф',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmStock:MAT-1')), findsNothing);
    expect(find.byKey(const ValueKey('filmStock:MAT-2')), findsOneWidget);
    // Each row has its own buttons.
    expect(
      find.byKey(const ValueKey('filmStock:sell:MAT-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('filmStock:receive:MAT-2')),
      findsOneWidget,
    );
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

  testWidgets('the history tells a receipt from a sale and filters by kind', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-1')));
    await tester.pumpAndSettle();
    // What stayed after each, counted back from the 84 m there now.
    expect(find.text('then 84 m'), findsOneWidget);
    expect(find.text('then 34 m'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmHistory:receipt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmMove:0')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmMove:1')), findsNothing);
    expect(find.text('Receipts +50 м'), findsOneWidget);
  });

  testWidgets('who owes, how long, and a reminder ready to send', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:customers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCustomers:debtors')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmCustomer:CUST-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmCustomer:CUST-2')), findsNothing);
    expect(
      find.byKey(const ValueKey('filmCustomer:remind:CUST-1')),
      findsOneWidget,
    );
  });

  test("a sale's receipt is a PDF with its films and sums", () async {
    final bytes = await buildFilmReceiptPdf(
      const FilmSale(
        entry: 'STE-7',
        date: '2026-11-09',
        customerName: 'Мебель-ЮГ',
        amount: 46800,
        paid: 20000,
        debt: 26800,
        seller: 'Olzhas',
        sellerPhone: '+7 701 555 12 34',
        issuedBy: 'Айбек',
        payments: [
          (date: '2026-11-09', amount: 15000, method: 'Наличные', bank: null),
          (date: '2026-11-09', amount: 5000, method: 'Перевод', bank: 'Kaspi'),
        ],
        lines: [
          FilmSaleLine(
            item: 'MAT-1',
            title: 'KIRA · Белый Матовый',
            metres: 12,
            priceM: 3900,
            maker: 'KIRA',
            colour: 'Белый Матовый',
            code: 'KR-101',
            type: 'Супер матовое',
            thicknessMm: 0.3,
          ),
        ],
      ),
      (
        title: 'Чек',
        date: 'Дата',
        customer: 'Клиент',
        film: 'Плёнка',
        metres: 'Метров',
        price: 'Цена',
        amount: 'Сумма',
        total: 'Итого',
        paid: 'Оплачено',
        debt: 'Долг',
        payment: 'Оплата',
        method: (m) => m,
        servedBy: (n) => 'Продавец: $n',
        phone: (p) => 'Тел.: $p',
        signedSold: 'Продал',
        signedGot: 'Получил',
        issuedBy: (n) => 'Выдал со склада: $n',
        signedIssued: 'Выдал',
        code: (c) => 'код $c',
        thickness: (mm) => '$mm мм',
        thanks: 'Спасибо!',
        wish: 'Хорошего дня',
      ),
    );
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('a reminder opens WhatsApp with the text, the number made whole', () {
    final uri = ContactActions.whatsAppMessageUri('8 701 555 12 34', 'Долг');
    expect(
      uri.toString(),
      'https://wa.me/77015551234'
      '?text=%D0%94%D0%BE%D0%BB%D0%B3',
    );
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
    // The film itself paid for, unless said otherwise.
    expect(repo.receivedPaid.single, isTrue);
    // On its way, due in two days unless said — a Sunday moves to Monday.
    expect(repo.arrivals.single, mdfIso(mdfDueIn(DateTime.now(), days: 2)));
  });

  testWidgets('a receipt taken from the supplier on credit says so', (
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
    final credit = find.byKey(const ValueKey('filmSupplierPay:credit'));
    await tester.ensureVisible(credit);
    await tester.tap(credit);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('filmReceiveSave'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.receivedPaid.single, isFalse);
  });

  testWidgets('what ran low is ordered as last time, on its way', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmReorder:open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmReorder:metres:0')),
      '60',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReorder:save')));
    await tester.pumpAndSettle();
    expect(repo.received.single, ('MAT-2', 60.0, 3100.0, true));
    expect(repo.arrivals.single, isNotNull);
  });

  testWidgets('metres are put by for a customer, no more than is free', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmPage:hold')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmHoldCustomer:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мебель-ЮГ').last);
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '30');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmHoldSave')));
    await tester.pumpAndSettle();
    expect(repo.holds.single, ('MAT-1', 'CUST-1', 30.0));
  });

  test('a supplier gets one message: each film once, in all', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    final g = FilmWanted.fromJson(_wanted).groups.first;
    expect(FilmWantGroup.byFilm(g.open).map((f) => f.length), [2, 1]);
    final text = filmOrderText(l10n, g, DateTime(2026, 11, 12));
    expect(text, contains('Заказ на 12.11.2026'));
    expect(text, contains('1. KIRA · Белый Матовый — 50 м'));
    expect(text, contains('2. JS Group · Графит — 50 м'));
    expect(text, contains('позиций 2, 100 м'));
  });

  testWidgets('the film to take in is found by a word of its name', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmDept:receive')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmPick:search')),
      'граф',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmReceivePick:MAT-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmReceivePick:MAT-1')), findsNothing);
    // By its code too.
    await tester.enterText(
      find.byKey(const ValueKey('filmPick:search')),
      'kr-1',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmReceivePick:MAT-1')), findsOneWidget);
  });

  testWidgets('one delivery brings several films, one for a customer', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmDept:receive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceivePick:MAT-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '10');
    await tester.enterText(find.byKey(const ValueKey('filmPrice')), '3500');
    // What ran low at this supplier comes in with it, as much as last time.
    await tester.tap(find.byKey(const ValueKey('filmReceive:low')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('filmMetres:1')))
          .controller!
          .text,
      '50',
    );
    await tester.enterText(find.byKey(const ValueKey('filmPrice:1')), '3100');
    await tester.pumpAndSettle();
    // The second film is bought for a customer.
    await tester.tap(find.byKey(const ValueKey('filmReceiveFor:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceiveFor:CUST-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmReceive:total')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmReceiveSave')));
    await tester.pumpAndSettle();
    // Several films: one delivery, not a receipt each.
    expect(repo.received, isEmpty);
    final (supplier, lines, _) = _orders.deliveries.single;
    expect(supplier, 'SUP-1');
    expect(
      [for (final l in lines) (l.item, l.metres, l.priceM, l.customer)],
      [('MAT-1', 10.0, 3500.0, null), ('MAT-2', 50.0, 3100.0, 'CUST-1')],
    );
  });

  testWidgets('a roll goes into production, to a customer and the shelf', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmDept:receive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceivePick:MAT-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '10');
    await tester.enterText(find.byKey(const ValueKey('filmPrice')), '3410');
    await tester.pumpAndSettle();
    // Dearer than the card's 3 100: said, with by how much.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('filmReceivePriceMoved')))
          .data,
      contains('+10%'),
    );
    // An MDF order lacks this film: it takes what it lacks.
    await tester.ensureVisible(find.byKey(const ValueKey('filmReceiveProd')));
    await tester.tap(find.byKey(const ValueKey('filmReceiveProd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceiveProd:SO-998')));
    await tester.pumpAndSettle();
    // A customer takes what is left; then 2 m of it go back to the shelf.
    await tester.ensureVisible(find.byKey(const ValueKey('filmReceiveFor')));
    await tester.tap(find.byKey(const ValueKey('filmReceiveFor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceiveFor:CUST-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('filmReceiveDest:1')),
        matching: find.byType(TextField),
      ),
      '1,8',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmReceiveShelf')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmReceive:total')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmReceiveSave')));
    await tester.pumpAndSettle();
    final (_, lines, _) = _orders.deliveries.single;
    final line = lines.single;
    expect(line.production, [(order: 'SO-998', metres: 6.2)]);
    expect(line.sales, [(customer: 'CUST-1', metres: 1.8)]);
    expect(line.customer, isNull);
  });

  testWidgets('the day’s list goes to the supplier and comes back a delivery', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('To order · 2 · waiting: 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmDept:orders')));
    await tester.pumpAndSettle();
    // One film wanted twice is one row: 20 m for a customer, 30 for the shelf.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('filmOrders:metres:MAT-1')))
          .data,
      '50 m',
    );
    expect(find.text('Мебель-ЮГ 20 m · 09:10'), findsOneWidget);
    expect(find.text('ran out · 50 m'), findsOneWidget);
    expect(find.text('takes orders until 16:00'), findsOneWidget);
    // The supplier's part goes out; it waits for his answer.
    await tester.tap(find.byKey(const ValueKey('filmOrders:send:SUP-1')));
    await tester.pumpAndSettle();
    expect(_orders.sentTo, ['SUP-1']);
    // Struck off: by its line, or — offered by itself — by its film.
    await tester.tap(find.byKey(const ValueKey('filmOrders:drop:MAT-2')));
    await tester.pumpAndSettle();
    expect(_orders.dropped, [(null, 'MAT-2')]);
    // Kira confirmed: the delivery window opens with its film and lines.
    expect(find.text('Sent at 10:20 · waiting for an answer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmOrders:confirmed:SUP-2')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('filmMetres')))
          .controller!
          .text,
      '15',
    );
    expect(find.text('For: ИП Ахметов 15 m'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('filmPrice')), '3300');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceiveSave')));
    await tester.pumpAndSettle();
    final (supplier, lines, _) = _orders.deliveries.single;
    expect(supplier, 'SUP-2');
    expect(lines.single.orders, ['FORD-7']);
    expect(lines.single.customer, isNull);
  });

  testWidgets('a film is put on the list for a customer', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmDept:orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmOrders:add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceivePick:MAT-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmWant:metres')), '12');
    await tester.tap(find.byKey(const ValueKey('filmWant:customer:2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мебель-ЮГ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmWant:save')));
    await tester.pumpAndSettle();
    expect(_orders.added.single, ('MAT-1', 12.0, 'CUST-1'));
  });

  testWidgets('a receipt starts from the stock list: pick the film first', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmDept:receive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceivePick:MAT-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '10');
    await tester.enterText(find.byKey(const ValueKey('filmPrice')), '3500');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmReceiveSave')));
    await tester.pumpAndSettle();
    expect(repo.received.single.$1, 'MAT-1');
  });

  testWidgets('a roll already here goes on the shelf at once', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmPage:receive')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '10');
    await tester.enterText(find.byKey(const ValueKey('filmPrice')), '3500');
    expect(find.byKey(const ValueKey('filmArrival:day')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmArrival:0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmArrival:day')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('filmReceiveSave')));
    await tester.pumpAndSettle();
    expect(repo.arrivals.single, isNull);
  });

  testWidgets('a roll on its way is late; when it comes, fewer metres', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmComing:0')), findsOneWidget);
    // Beside the name: what is on the shelf and what is on its way.
    expect(find.text('6 м'), findsOneWidget);
    expect(find.text('30 м'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmComing:arrived')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmMetres')), '28');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmArrivedSave')));
    await tester.pumpAndSettle();
    expect(repo.came.single, ('STE-30', 28.0));
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
    await tester.tap(find.byKey(const ValueKey('filmDelivery:payer:employee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmDelivery:method:Перевод')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmDelivery:driver:Ерлан')));
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
      // Paid by an employee out of his pocket, by transfer: to give back.
      'payer': 'employee',
      'paid_by': 'a@k.kz',
      'method': 'Перевод',
      // The driver picked from those who came before.
      'driver': 'Ерлан',
      'phone': '+7 701 555 12 34',
    });
    expect(repo.deliveries.single.$2, 'b@k.kz');
  });

  testWidgets('the film cash: in, out, and what is owed is settled', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:cash')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmCash:logistics')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmCash:in')), findsOneWidget);
    // One day: a waterfall down to what is left, not a single bar.
    expect(find.byKey(const ValueKey('filmCash:waterfall')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmCash:chart')), findsNothing);
    // Against the period before: in doubled.
    expect(find.textContaining('▲ 100%'), findsOneWidget);
    // The drawer started with what was counted at the last close.
    expect(find.byKey(const ValueKey('filmCash:opening')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmCash:quiet')), findsNothing);
    // The day closed: short of what the drawer should hold — not without why.
    await tester.tap(find.byKey(const ValueKey('filmCash:closeDay')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmCash:counted')),
      '1000',
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('filmCash:closeSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('filmCash:reason')),
      'такси',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.closes.single.$2, 1000);
    expect(
      find.byKey(const ValueKey('filmCash:where:Наличные')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('filmCash:employee:STE-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('filmCash:carrier:STE-4')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('filmCash:wa:STE-4')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmCash:settle:STE-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCash:settle:Перевод')));
    await tester.pumpAndSettle();
    expect(repo.settled.single, ('STE-3', 'Перевод'));
    // Film taken on credit: paid to the supplier, not settled as a delivery.
    expect(
      find.byKey(const ValueKey('filmCash:supplier:STE-5')),
      findsOneWidget,
    );
    final pay = find.byKey(const ValueKey('filmCash:settle:STE-5'));
    await tester.ensureVisible(pay);
    await tester.pumpAndSettle();
    await tester.tap(pay);
    await tester.pumpAndSettle();
    // Asked where the money came from: from elsewhere, the cash not touched.
    expect(
      find.byKey(const ValueKey('filmCash:settle:elsewhere')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('filmCash:settle:elsewhere')));
    await tester.pumpAndSettle();
    expect(repo.supplierPaidFor.single, (
      'STE-5',
      'Наличные',
      FilmPaySource.elsewhere,
    ));
    expect(repo.settled.single, ('STE-3', 'Перевод'));
  });

  testWidgets('the week is a bar a day, and a tapped day filters the moves', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:cash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCash:span:7')));
    await tester.pumpAndSettle();
    final chart = find.byKey(const ValueKey('filmCash:chart'));
    expect(chart, findsOneWidget);
    expect(find.byKey(const ValueKey('filmCash:waterfall')), findsNothing);
    expect(find.textContaining('Мебель-ЮГ'), findsOneWidget);
    final box = tester.getRect(chart);
    // The first day had no moves: picked, the list empties.
    await tester.tapAt(box.topLeft + Offset(box.width * 0.25, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmCash:picked')), findsOneWidget);
    expect(find.textContaining('Мебель-ЮГ'), findsNothing);
    // The second day had the sale; tapping it again lets it go.
    await tester.tapAt(box.topLeft + Offset(box.width * 0.75, 40));
    await tester.pumpAndSettle();
    expect(find.textContaining('Мебель-ЮГ'), findsOneWidget);
    await tester.tapAt(box.topLeft + Offset(box.width * 0.75, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmCash:picked')), findsNothing);
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
    // The month on one page: what sold, and what lies unmoved.
    expect(find.byKey(const ValueKey('filmReport:top:MAT-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmReport:idle:MAT-2')), findsOneWidget);
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

  testWidgets('a sale says what stays; too much offers all that is there', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmPage:sell')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmSaleMetres:0')),
      '4',
    );
    await tester.pumpAndSettle();
    expect(find.text('2 m left'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('filmSaleMetres:0')),
      '9',
    );
    await tester.pumpAndSettle();
    expect(find.text('only 6 m in stock'), findsOneWidget);
    // The roll on its way is said, so the customer can be told when.
    expect(
      find.byKey(const ValueKey('filmSaleComing:0:STE-30')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('filmSaleAll:0')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('filmSaleMetres:0')),
    );
    expect(field.controller!.text, '6');
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
    // The customer's card: his terms from there (owner, 12.11.2026).
    await tester.tap(find.byKey(const ValueKey('filmCustomer:CUST-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCustomerPage:terms')));
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

  testWidgets('the sales say the period, who paid, who owes', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:sales')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmSales:kpi:amount')), findsOneWidget);
    // Paid in part: an orange mark with what is owed.
    expect(find.byKey(const ValueKey('filmSales:state:STE-7')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmSales:filter:paid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmSaleRow:0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('filmSales:filter:debt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmSaleRow:0')), findsOneWidget);
    // Who owes, the oldest first — a reminder a tap away.
    await tester.tap(find.byKey(const ValueKey('filmSales:kpi:debt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmDebtors')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('filmDebtor:remind:CUST-1')),
      findsOneWidget,
    );
  });

  test('how often a customer buys, from three sales on', () {
    FilmSale on(String d) => FilmSale(entry: d, date: d);
    expect(filmRhythmDays([on('2026-11-01'), on('2026-11-08')]), isNull);
    expect(
      filmRhythmDays([on('2026-11-15'), on('2026-11-08'), on('2026-11-01')]),
      7,
    );
  });

  testWidgets('below cost asks why; the customer is known at once', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmStock:MAT-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmPage:sell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSaleCustomer:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мебель-ЮГ').last);
    await tester.pumpAndSettle();
    // What he owes, and his last sale to sell again.
    expect(find.byKey(const ValueKey('filmSaleHint')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmSaleLikeLast')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('filmSaleMetres:0')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmSalePrice:0')),
      '3000',
    );
    await tester.pumpAndSettle();
    // Bought at 3 100: below cost — not sold until it is said why.
    expect(find.byKey(const ValueKey('filmSaleBelow:0')), findsOneWidget);
    final save = find.byKey(const ValueKey('filmSaleSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('filmSaleBelowWhy:rest')),
    );
    await tester.tap(find.byKey(const ValueKey('filmSaleBelowWhy:rest')));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.belowReasons.single, 'end of a roll');
  });

  test('a debt limit is broken by the sum or the days', () {
    const c = FilmCustomer(
      customer: 'C',
      name: 'C',
      debt: 20000,
      debtDays: 5,
      debtLimit: 30000,
      debtLimitDays: 14,
    );
    expect(c.overLimit(5000), isNull);
    expect(c.overLimit(15000), (sum: true, days: false));
    const late = FilmCustomer(
      customer: 'L',
      name: 'L',
      debt: 100,
      debtDays: 20,
      debtLimitDays: 14,
    );
    expect(late.overLimit(0), (sum: false, days: true));
  });

  test('a statement: every sale and payment, the balance after each', () {
    final lines = filmStatement(const [
      FilmSale(
        entry: 'S1',
        date: '2026-11-01',
        amount: 30000,
        payments: [
          (date: '2026-11-01', amount: 10000, method: 'Наличные', bank: null),
          (date: '2026-11-05', amount: 5000, method: 'Перевод', bank: null),
        ],
      ),
      FilmSale(entry: 'S2', date: '2026-11-03', amount: 12000),
    ]);
    expect(
      [for (final l in lines) (l.date, l.balance)],
      [
        ('2026-11-01', 30000.0),
        ('2026-11-01', 20000.0),
        ('2026-11-03', 32000.0),
        ('2026-11-05', 27000.0),
      ],
    );
  });

  testWidgets('who to call: owing too long, silent past his rhythm', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('filmTab:customers')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmCustomers:call')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmCall:CUST-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmCall:CUST-2')), findsNothing);
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
