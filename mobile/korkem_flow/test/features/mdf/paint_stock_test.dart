import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/paint_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/paint_stock.dart';
import 'package:korkem_flow/features/mdf/presentation/paint_stock_view.dart';

import '../../support/widget_harness.dart';

final _stock = PaintStock.fromJson(const {
  'kg_per_m2': 0.3,
  'usage': {
    'days': 30,
    'm2': 100,
    'kg_by_norm': 30,
    'kg_counted': 6,
    'fact_kg_m2': 0.36,
  },
  'paints': [
    {
      'item': 'MAT-P1',
      'title': 'Краска RAL 9016 · Эмаль ПУ матовая',
      'colour': 'RAL 9016',
      'base': 'Эмаль ПУ матовая',
      'on_hand_kg': 2,
      'last': {
        'date': '2026-11-01',
        'kg': 20,
        'price_kg': 4000,
        'supplier': 'SUP-1',
        'supplier_name': 'Колор-Маркет',
        'city': 'Алматы',
      },
    },
  ],
  'queue': [
    {
      'colour': 'RAL 9016',
      'queue_m2': 14,
      'need_kg': 4.2,
      'on_hand_kg': 2,
      'short_kg': 2.2,
    },
  ],
  'owed': [
    {
      'receipt': 'STE-5',
      'date': '2026-11-10',
      'paint': 'Краска RAL 9016',
      'kg': 10,
      'amount': 40000,
      'supplier': 'Колор-Маркет',
      'invoice_no': 'К-7',
      'due_on': '2026-11-12',
      'overdue': true,
    },
  ],
  'suppliers': [
    {'supplier': 'SUP-2', 'name': 'Другой', 'paint': false},
    {'supplier': 'SUP-1', 'name': 'Колор-Маркет', 'city': 'Алматы', 'paint': true},
  ],
});

class _Repo implements PaintStockRepository {
  final received = <Map<String, Object?>>[];
  final paid = <(String, String)>[];

  @override
  Future<PaintStock> stock() async => _stock;

  @override
  Future<PaintStock> receive({
    required String colour,
    required double kg,
    required double priceKg,
    required String supplier,
    String? base,
    Map<String, Object?>? delivery,
    String? receivedBy,
    FilmSupplierPay? supplierPay,
    String? note,
  }) async {
    received.add({
      'colour': colour,
      'kg': kg,
      'price_kg': priceKg,
      'supplier': supplier,
      'base': base,
      'delivery': delivery,
      'pay': supplierPay?.toJson(),
      'note': note,
    });
    return _stock;
  }

  final counted = <(String, double)>[];

  @override
  Future<PaintStock> count(String item, double kg) async {
    counted.add((item, kg));
    return _stock;
  }

  @override
  Future<PaintStock> paySupplier(String receipt, String method) async {
    paid.add((receipt, method));
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
      overrides: [
        paintStockRepositoryProvider.overrideWithValue(repo),
        mdfDictionariesProvider.overrideWith(
          (ref) async => const MdfDictionaries({
            MdfDictKind.paintSystem: [
              MdfDictEntry(id: 's1', value: 'RAL Classic'),
            ],
            MdfDictKind.paint: [
              MdfDictEntry(id: 'c1', value: 'RAL 9016', group: 'RAL Classic'),
              MdfDictEntry(id: 'c2', value: 'RAL 9010', group: 'RAL Classic'),
            ],
          }),
        ),
        filmDeliveryOptionsProvider.overrideWith(
          (ref) async => const FilmDeliveryOptions(
            transports: ['Привёз поставщик', 'Такси'],
            cities: ['Алматы'],
            staff: [(user: 'me@x', name: 'Я')],
            me: 'me@x',
          ),
        ),
      ],
      child: harness(const SingleChildScrollView(child: PaintStockSection())),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('what is short for the queue is said, and bought from there: '
      'supplier as last time, dearer said, paid by invoice, a taxi', (
    tester,
  ) async {
    final repo = await _pump(tester);
    expect(find.byKey(const ValueKey('paintNeed:RAL 9016')), findsOne);
    expect(find.textContaining('2,2 kg short'), findsOne);
    expect(find.byKey(const ValueKey('paintOwed:STE-5')), findsOne);

    await tester.tap(find.byKey(const ValueKey('paintNeedBuy:RAL 9016')));
    await tester.pumpAndSettle();
    // The colour is the short one; the supplier the one it came from last.
    expect(find.byKey(const ValueKey('paintColour:RAL 9016')), findsOne);
    expect(find.byKey(const ValueKey('paintSupplier:SUP-1')), findsOne);
    final save = find.byKey(const ValueKey('paintReceiveSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    // Four cans of five kilos at 4 400 a kilo — dearer than 4 000.
    await tester.tap(find.byKey(const ValueKey('paintByCans')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('paintCans')), '4');
    await tester.enterText(find.byKey(const ValueKey('paintCanKg')), '5');
    await tester.enterText(
      find.byKey(const ValueKey('paintPriceKgValue')),
      '4400',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('10% dearer'), findsOne);

    await tester.tap(find.byKey(const ValueKey('filmSupplierPay:invoice')));
    await tester.pumpAndSettle();
    // No paint department cash to tick.
    expect(find.byKey(const ValueKey('filmSupplierFromDept')), findsNothing);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('filmSupplierInvoiceNo')),
      'К-9',
    );
    await tester.tap(find.byKey(const ValueKey('filmDelivery:transport:Такси')));
    await tester.enterText(find.byKey(const ValueKey('filmDelivery:cost')), '3000');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintSum:delivery')), findsOne);
    expect(find.byKey(const ValueKey('paintSum:landed')), findsOne);

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final got = repo.received.single;
    expect(
      (got['colour'], got['kg'], got['price_kg'], got['supplier']),
      ('RAL 9016', 20.0, 4400.0, 'SUP-1'),
    );
    expect(got['base'], 'Эмаль ПУ матовая');
    expect((got['pay']! as Map)['mode'], 'invoice');
    final delivery = got['delivery']! as Map;
    expect((delivery['transport'], delivery['amount']), ('Такси', 3000.0));
    expect(got['note'], contains('4 × 5'));
  });

  testWidgets('a paint debt is paid off, by the way it was paid', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('paintPay:STE-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paintPayHow:Перевод')).last);
    await tester.pumpAndSettle();
    expect(repo.paid, [('STE-5', 'Перевод')]);
  });

  testWidgets('what a m² really took is said; a weighed paint puts the store '
      'right', (tester) async {
    final repo = await _pump(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('paintUsage'))).data,
      contains('really 0,36 kg/m²'),
    );
    await tester.tap(find.byKey(const ValueKey('paintCount:MAT-P1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paintCountValue')),
      '1,5',
    );
    await tester.tap(find.byKey(const ValueKey('paintCountSave')));
    await tester.pumpAndSettle();
    expect(repo.counted, [('MAT-P1', 1.5)]);
  });
}
