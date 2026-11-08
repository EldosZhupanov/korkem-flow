import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_order_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';

import '../../support/widget_harness.dart';

/// The owner's №1129 of 27.10.2026, as the server answers it.
Map<String, Object?> _card({
  String status = 'accepted',
  Map<String, String?> stages = const {},
}) => {
  'name': 'SAL-ORD-1129',
  'status': status,
  'overdue': false,
  'customer': 'Арман Қалдыбаев',
  'customer_name': 'Арман Қалдыбаев',
  'phone': '8 (777) 177-66-36',
  'created_on': '2026-10-27',
  'delivery_date': '2026-11-10',
  'head': {
    'thickness_mm': 16,
    'finish': 'ПВХ плёнка',
    'decor_top': 'Венге (Korkem)',
    'edge_profile': 'R3',
  },
  'lines': [
    {
      'height_mm': 130,
      'width_mm': 1040,
      'qty': 1,
      'milling': 'Тегіс 90°',
      'area_m2': 0.14,
      'rate_m2': 17000,
      'amount': 2380,
    },
    {
      'height_mm': 1577,
      'width_mm': 517,
      'qty': 2,
      'milling': 'Суреттегі үлгі',
      'area_m2': 1.63,
      'rate_m2': 19500,
      'amount': 31785,
    },
  ],
  'pieces': 3,
  'area_m2': 1.77,
  'total': 34165,
  'paid': 0,
  'debt': 34165,
  'payments': <Object>[],
  'stages': [
    for (final s in ['cut', 'mill', 'sand', 'vacuum'])
      {'stage': s, 'done_on': stages[s]},
  ],
};

class _FakeRepository implements MdfOrderRepository {
  final ticked = <(MdfStage, bool)>[];
  Map<String, String?> stages = {};

  @override
  Future<List<MdfOrderRow>> listing(MdfListQuery query) async => [
    MdfOrderRow.fromJson(const {
      'name': 'SAL-ORD-1129',
      'status': 'in_shop',
      'overdue': true,
      'created_on': '2026-10-27',
      'delivery_date': '2026-10-30',
      'customer_name': 'Арман Қалдыбаев',
      'phone': '8 (777) 177-66-36',
      'decor_top': 'Венге (Korkem)',
      'area_m2': 3.04,
      'total': 58680,
      'paid': 0,
      'debt': 58680,
      'stage': 'mill',
    }),
  ];

  @override
  Future<MdfOrder> card(String name) async =>
      MdfOrder.fromJson(_card(stages: stages));

  @override
  Future<MdfOrder> setStage(
    String order,
    MdfStage stage, {
    required bool done,
    String? worker,
  }) async {
    ticked.add((stage, done));
    stages = {...stages, stage.name: done ? '2026-11-05' : null};
    return card(order);
  }

  /// The server's arithmetic, in short: the area rounded, times the price
  /// typed or the film's.
  @override
  Future<MdfPricing> price({
    required List<MdfLineInput> lines,
    String? finish,
    double? defaultRate,
    Map<String, double> filmRates = const {},
  }) async {
    final priced = [
      for (final l in lines)
        () {
          final area = double.parse(
            (l.heightMm * l.widthMm * l.qty / 1e6).toStringAsFixed(2),
          );
          final rate = l.rate ?? filmRates[l.film] ?? 0;
          return MdfLine(
            heightMm: l.heightMm,
            widthMm: l.widthMm,
            qty: l.qty,
            areaM2: area,
            rateM2: rate,
            amount: (area * rate).roundToDouble(),
            film: l.film,
          );
        }(),
    ];
    return MdfPricing(
      lines: priced,
      pieces: priced.fold(0, (s, l) => s + l.qty),
      areaM2: priced.fold<double>(0, (s, l) => s + l.areaM2),
      total: priced.fold<double>(0, (s, l) => s + l.amount),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A draft of two films, as Олжас Мухаметхан brought it (08.11.2026).
Map<String, Object?> _twoFilms() => {
  ..._card(status: 'draft'),
  'head': {
    'material': '16 мм МДФ',
    'film_rates': {'Белый Матовый': 17000, 'Палома': 18000},
  },
  'lines': [
    {
      'height_mm': 718,
      'width_mm': 500,
      'qty': 2,
      'area_m2': 0.72,
      'rate_m2': 17000,
      'amount': 12240,
      'film': 'Белый Матовый',
      'material': '16 мм МДФ',
    },
    {
      'height_mm': 300,
      'width_mm': 400,
      'qty': 2,
      'area_m2': 0.24,
      'rate_m2': 21000,
      'amount': 5040,
      'manual_rate': true,
      'film': 'Палома',
      'film_back': 'Графит',
      'material': '10 мм МДФ',
    },
    {
      'height_mm': 500,
      'width_mm': 498,
      'qty': 5,
      'area_m2': 1.25,
      'rate_m2': 18000,
      'amount': 22500,
      'film': 'Палома',
      'material': '16 мм МДФ',
    },
  ],
};

class _TwoFilms extends _FakeRepository {
  @override
  Future<MdfOrder> card(String name) async => MdfOrder.fromJson(_twoFilms());
}

void main() {
  testWidgets('a draft of two films shows a group for each, with its totals', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_TwoFilms())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfFilm:Белый Матовый')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfFilm:Палома')), findsOneWidget);
    // The film's price in the header; a price typed on a line stays its own.
    final rate = tester.widget<TextField>(
      find.byKey(const ValueKey('mdfFilmRate:1')),
    );
    expect(rate.controller!.text, '18000');
    final own = tester.widget<TextField>(
      find.byKey(const ValueKey('mdfRate:1')),
    );
    expect(own.controller!.text, '21000');
    final group = tester.widget<TextField>(
      find.byKey(const ValueKey('mdfRate:2')),
    );
    expect(group.controller!.text, isEmpty);
    // Positions keep one numbering through the groups; Палома: 2 + 5 pieces.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mdfFilmTotals:1'))).data,
      contains('7'),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mdfFilmTotals:1'))).data,
      contains('1.49'),
    );
  });

  test('the positions fall into film groups in the order films appear', () {
    final order = MdfOrder.fromJson(_twoFilms());
    final groups = mdfFilmGroups(order.lines);
    expect([for (final g in groups) g.film], ['Белый Матовый', 'Палома']);
    expect([for (final (n, _) in groups.last.lines) n], [2, 3]);
    expect(groups.last.pieces, 7);
    expect(groups.last.areaM2, 1.49);
    expect(groups.last.amount, 27540);
    expect(order.head.filmRates['Палома'], 18000);
    expect(order.lines[1].filmBack, 'Графит');
  });

  test('a card reads the stages its finish has, in order', () {
    final order = MdfOrder.fromJson(_card(stages: {'cut': '2026-11-01'}));
    expect(order.stages.keys, [
      MdfStage.cut,
      MdfStage.mill,
      MdfStage.sand,
      MdfStage.vacuum,
    ]);
    expect(order.stages[MdfStage.cut], '2026-11-01');
    expect(order.stages[MdfStage.mill], isNull);
  });

  test('the head sends only what was filled in', () {
    expect(const MdfHead(finish: 'ПВХ плёнка', thicknessMm: 16).toJson(), {
      'thickness_mm': 16,
      'finish': 'ПВХ плёнка',
    });
  });

  testWidgets('the list shows an overdue order and its debt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: harness(const MdfOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfRow:SAL-ORD-1129')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mdfOverdue:SAL-ORD-1129')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mdfDebt:SAL-ORD-1129')), findsOneWidget);
  });

  testWidgets('the manager ticks a stage on the card', (tester) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfStage:paint')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfStage:cut')));
    await tester.pumpAndSettle();
    expect(repo.ticked, [(MdfStage.cut, true)]);
    expect(find.textContaining('2026-11-05'), findsOneWidget);
  });
}
