import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/cnc/data/cnc_repository.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';
import 'package:korkem_flow/features/cnc/presentation/cnc_order_screen.dart';
import 'package:korkem_flow/features/cnc/presentation/cnc_orders_screen.dart';
import 'package:korkem_flow/features/cnc/presentation/cnc_prices_screen.dart';

import '../../support/widget_harness.dart';

const _joint = CncService(
  id: 's1',
  title: 'Еврозапил',
  unit: 'шт',
  group: 'Столешницы',
  price: 6000,
  minutes: 30,
);
const _lattice = CncService(
  id: 's2',
  title: 'Решётка / узор',
  unit: cncByAgreement,
  group: 'Решётки и узоры',
);

CncCard _card(CncStatus status, {double debt = 18000}) => CncCard.fromJson({
  'name': 'SAL-ORD-7',
  'status': status.wire,
  'customer': 'C-1',
  'customer_name': 'Ерлан',
  'phone': '+77010000000',
  'delivery_date': '2026-11-19',
  'tags': ['urgent'],
  'intake': [
    {'what': 'Столешница 3000×600', 'qty': 1, 'unit': 'шт', 'defects': 'скол'},
  ],
  'terms': true,
  'lines': [
    {
      'kind': 'service',
      'title': 'Еврозапил',
      'qty': 1,
      'rate': 6000,
      'amount': 6000,
      'unit': 'шт',
      'minutes': 30,
    },
  ],
  'extras': [
    {'title': 'Срочность +20%', 'amount': 1200},
  ],
  'total': 7200,
  'paid': 7200 - debt,
  'debt': debt,
  'queue': {'minutes_ahead': 90, 'eta': '2026-11-17', 'on_machine': false},
});

class _Repo implements CncRepository {
  final calls = <String>[];
  final priced = <List<CncLineInput>>[];
  final savedServices = <Map<String, Object?>>[];
  CncCard current = _card(CncStatus.queued);

  @override
  Future<List<CncService>> services({bool includeDisabled = false}) async => [
    _joint,
    _lattice,
  ];

  @override
  Future<CncSettings> settings() async => const CncSettings();

  @override
  Future<CncQuote> price(
    List<CncLineInput> lines, {
    String? customer,
    List<String> tags = const [],
  }) async {
    priced.add(lines);
    final amount = lines.fold<double>(
      0,
      (s, l) => s + l.qty * (l.rate ?? (l.service == 's1' ? 6000 : 0)),
    );
    return CncQuote.fromJson({
      'lines': [
        for (final l in lines)
          {
            'kind': 'service',
            'title': l.service ?? '',
            'qty': l.qty,
            'rate': 6000,
            'amount': l.qty * (l.rate ?? 6000),
            'no_price': l.service == 's2' && l.rate == null,
          },
      ],
      'extras': tags.contains('urgent')
          ? [
              {'title': 'Срочность +20%', 'amount': amount * 0.2},
            ]
          : [],
      'total': tags.contains('urgent') ? amount * 1.2 : amount,
      'minutes': 30,
    });
  }

  @override
  Future<CncCard> card(String order) async => current;

  @override
  Future<CncCard> start(String order) async {
    calls.add('start');
    return current = _card(CncStatus.onMachine);
  }

  @override
  Future<CncCard> ready(String order, {bool done = true}) async {
    calls.add('ready');
    return current = _card(CncStatus.ready);
  }

  @override
  Future<CncCard> handOver(
    String order, {
    String? comment,
    String? takenBy,
    String? takenPhone,
  }) async {
    calls.add('hand_over:$takenBy');
    return current = _card(CncStatus.handedOver, debt: 0);
  }

  @override
  Future<CncCard> addPayment(String order, double amount, String method) async {
    calls.add('pay:$amount:$method');
    return current = _card(CncStatus.ready, debt: 0);
  }

  @override
  Future<List<CncService>> saveService({
    required String title,
    required String unit,
    String? group,
    double? price,
    double? priceTrade,
    double? minutes,
    String? id,
    bool enabled = true,
  }) async {
    savedServices.add({'title': title, 'unit': unit, 'price': price, 'id': id});
    return [_joint, _lattice];
  }

  @override
  Future<CncListing> listing(CncQuery q) async => CncListing.fromJson({
    'orders': [
      {
        'name': 'SAL-ORD-7',
        'customer_name': 'Ерлан',
        'status': 'queued',
        'due': '2026-11-19',
        'total': 7200,
        'debt': 7200,
        'urgent': true,
        'eta': '2026-11-17',
        'minutes': 30,
      },
    ],
    'queue_minutes': 70,
    'queue_orders': 2,
    'ready': 1,
    'debt': 7200,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Repo> _pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(1600, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [cncRepositoryProvider.overrideWithValue(repo)],
      child: harness(screen),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('the list says how long the machine is booked, and when each '
      'order will be ready', (tester) async {
    await _pump(tester, const CncOrdersScreen());
    expect(find.text('1 h 10 min'), findsOne);
    expect(find.byKey(const ValueKey('cncRow:SAL-ORD-7')), findsOne);
    expect(find.textContaining('ready 17.11'), findsOne);
  });

  testWidgets('a job is put together from the price list; urgent costs more; '
      'a lattice asks its price', (tester) async {
    final repo = await _pump(tester, const CncOrderScreen());
    await tester.tap(find.byKey(const ValueKey('cncAddService')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cncService:Еврозапил')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cncLineQty:0')), '2');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repo.priced.last.single.qty, 2);
    expect(find.byKey(const ValueKey('cncTotals')), findsOne);

    await tester.tap(find.byKey(const ValueKey('cncUrgent')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Срочность +20%'), findsOne);

    await tester.tap(find.byKey(const ValueKey('cncAddService')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cncService:Решётка / узор')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('no price'), findsOne);

    // No customer: it says so, and saves nothing.
    await tester.tap(find.byKey(const ValueKey('cncSave')));
    await tester.pumpAndSettle();
    expect(find.text('Choose the customer'), findsWidgets);
  });

  testWidgets('a queued order goes on the machine, is ready, paid and handed '
      'over', (tester) async {
    final repo = await _pump(tester, const CncOrderScreen(name: 'SAL-ORD-7'));
    expect(find.textContaining('ready 17.11'), findsOne);
    expect(find.textContaining('defects: скол'), findsOne);
    await tester.tap(find.byKey(const ValueKey('cncStart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cncReady')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cncTell')), findsOne);
    await tester.tap(find.byKey(const ValueKey('cncPay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cncPaySave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cncHandOver')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cncTakenBy')), 'Водитель');
    await tester.tap(find.byKey(const ValueKey('cncHandOverSave')));
    await tester.pumpAndSettle();
    expect(repo.calls, [
      'start',
      'ready',
      'pay:18000.0:Наличные',
      'hand_over:Водитель',
    ]);
  });

  testWidgets('the price list is by group; a price is set on a service', (
    tester,
  ) async {
    final repo = await _pump(tester, const CncPricesScreen());
    expect(find.text('Столешницы'), findsOne);
    expect(find.text('by agreement'), findsOne);
    await tester.tap(find.byKey(const ValueKey('cncServiceRow:Еврозапил')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cncServicePrice')),
      '6500',
    );
    await tester.tap(find.byKey(const ValueKey('cncServiceSave')));
    await tester.pumpAndSettle();
    expect(repo.savedServices.single, {
      'title': 'Еврозапил',
      'unit': 'шт',
      'price': 6500.0,
      'id': 's1',
    });
  });

  test('a duration reads in hours and minutes', () {
    expect(cncDuration(70, 'h', 'min'), '1 h 10 min');
    expect(cncDuration(45, 'h', 'min'), '45 min');
    expect(cncDuration(120, 'h', 'min'), '2 h');
  });
}
