import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/glue_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/glue_stock.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/glue_screen.dart';

import '../../support/widget_harness.dart';

/// «Клей для ПВХ» (owner, 17.11.2026): a glue apart from who sells it; the
/// one in work is taken; bought by the bucket, the litre or the kilo.
final _stock = GlueStock.fromJson(const {
  'in_work': 'GL-A',
  'can_edit': true,
  'prices_visible': true,
  'edge_coats': 2,
  'queue': {'kg': 12.5, 'm2': 100, 'orders': 4, 'on_hand_kg': 10, 'short_kg': 2.5},
  'milling': [
    {'name': 'Классика', 'factor': 1},
    {'name': 'Рифлёный', 'factor': 1.3},
  ],
  'glues': [
    {
      'item': 'GL-A',
      'title': 'Клей А',
      'origin': 'Китай',
      'bucket_kg': 20,
      'kg_per_litre': 1.04,
      'norm_g_m2': 100,
      'in_work': true,
      'on_hand_kg': 10,
      'cost_kg': 2100,
      'cost_m2': 210,
      'sell': {'bucket': 50400, 'litre': 3276},
      'fact': {'m2': 100, 'kg_by_norm': 10, 'kg_counted': 3, 'fact_g_m2': 130},
    },
    {
      'item': 'GL-B',
      'title': 'Клей Б',
      'bucket_kg': null,
      'kg_per_litre': 1,
      'norm_g_m2': 130,
      'on_hand_kg': 5,
    },
  ],
  'suppliers': [
    {
      'supplier': 'SUP-JS',
      'name': 'JS Group',
      'city': 'Алматы',
      'bought': [
        {
          'item': 'GL-A',
          'title': 'Клей А',
          'date': '2026-11-10',
          'price_kg': 2000,
          'delivery_kg': 100,
          'landed_kg': 2100,
          'cheapest': true,
        },
      ],
    },
    {'supplier': 'SUP-DM', 'name': 'Delta Machines', 'city': 'Астана'},
  ],
});

class _Repo implements GlueStockRepository {
  final inWork = <String>[];
  final received = <Map<String, Object?>>[];
  final added = <GlueCard>[];

  @override
  Future<GlueStock> stock() async => _stock;

  @override
  Future<GlueStock> setInWork(String item) async {
    inWork.add(item);
    return _stock;
  }

  @override
  Future<GlueStock> addGlue(GlueCard card) async {
    added.add(card);
    return _stock;
  }

  @override
  Future<GlueStock> receive({
    required String item,
    required double qty,
    required GlueUnit unit,
    required double price,
    required GlueUnit pricePer,
    required String supplier,
    Map<String, Object?>? delivery,
    String? receivedBy,
    FilmSupplierPay? supplierPay,
  }) async {
    received.add({
      'item': item,
      'qty': qty,
      'unit': unit,
      'price': price,
      'per': pricePer,
      'supplier': supplier,
    });
    return _stock;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Repo> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1400, 2600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        glueStockRepositoryProvider.overrideWithValue(repo),
        filmDeliveryOptionsProvider.overrideWith(
          (ref) async => const FilmDeliveryOptions(
            transports: ['Привёз поставщик', 'Такси'],
            cities: ['Алматы'],
            staff: [(user: 'me@x', name: 'Я')],
            me: 'me@x',
          ),
        ),
      ],
      child: harness(const GlueScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('each glue with its norm, cost a m², sale prices and month; '
      'who sells it, the cheapest marked; the queue short', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('glueInWork:GL-A')), findsOne);
    expect(find.byKey(const ValueKey('glueTake:GL-B')), findsOne);
    expect(find.byKey(const ValueKey('glueCostM2:GL-A')), findsOne);
    expect(find.byKey(const ValueKey('glueFact:GL-A')), findsOne);
    expect(find.byKey(const ValueKey('glueQueueShort')), findsOne);
    expect(find.byKey(const ValueKey('glueBought:SUP-JS:GL-A')), findsOne);
    expect(find.textContaining('cheaper'), findsOne);
    expect(find.byKey(const ValueKey('glueSupplier:SUP-DM')), findsOne);
    expect(find.byKey(const ValueKey('glueMilling:Рифлёный')), findsOne);
  });

  testWidgets('a new barrel: «Взять в работу»', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('glueTake:GL-B')));
    await tester.pumpAndSettle();
    expect(repo.inWork, ['GL-B']);
  });

  testWidgets('two buckets at so much a bucket: the price a kilo is shown '
      'and the receipt goes as buckets', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('glueReceive')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('glueReceiveSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('glueReceiveQty')), '2');
    await tester.enterText(
      find.byKey(const ValueKey('glueReceivePrice')),
      '40000',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('glueReceiveSum')), findsOne);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.received.single, {
      'item': 'GL-A',
      'qty': 2.0,
      'unit': GlueUnit.bucket,
      'price': 40000.0,
      'per': GlueUnit.bucket,
      'supplier': 'SUP-JS',
    });
  });

  testWidgets('a new glue with its norm', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('glueAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('glueCard:name')),
      'Клей В',
    );
    await tester.enterText(find.byKey(const ValueKey('glueCard:norm')), '120');
    await tester.enterText(find.byKey(const ValueKey('glueCard:bucket')), '18');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('glueCard:save')));
    await tester.pumpAndSettle();
    final card = repo.added.single;
    expect((card.name, card.normGM2, card.bucketKg), ('Клей В', 120.0, 18.0));
  });

  test('an order says its glue, and each PVC position its own', () {
    final line = MdfLine.fromJson(const {
      'height_mm': 718,
      'width_mm': 500,
      'qty': 4,
      'area_m2': 1.44,
      'rate_m2': 0,
      'amount': 0,
      'glue_kg': 0.175,
    });
    expect(line.glueKg, 0.175);
    final glue = OrderGlue.fromJson(const {
      'kg': 0.71,
      'm2': 5.99,
      'norm_g_m2': 100,
      'title': 'Клей А',
    });
    expect((glue.kg, glue.title), (0.71, 'Клей А'));
  });
}
