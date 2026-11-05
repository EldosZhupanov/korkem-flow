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
  }) async {
    ticked.add((stage, done));
    stages = {...stages, stage.name: done ? '2026-11-05' : null};
    return card(order);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
