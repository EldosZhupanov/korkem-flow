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
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';

import '../../support/widget_harness.dart';

final _stock = PaintStock.fromJson(const {
  'kg_per_m2': 0.3,
  'recipe': {
    'layers': [
      {
        'name': 'Грунт',
        'g_m2': 150,
        'coats': 1,
        'parts': [
          {'name': 'Отвердитель', 'per_kg': 0.5},
        ],
      },
      {'name': 'Эмаль', 'colour': true, 'g_m2': 120, 'coats': 2},
    ],
  },
  'materials': [
    {'name': 'Грунт', 'need_kg': 2.1, 'on_hand_kg': 0, 'short_kg': 2.1},
    {'name': 'Отвердитель', 'need_kg': 1.05, 'on_hand_kg': 5, 'short_kg': 0},
  ],
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
        'note': '4 × 5 кг',
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
  'delivery_owed': [
    {
      'receipt': 'STE-8',
      'date': '2026-11-14',
      'amount': 2500,
      'employee': 'Асет',
      'transport': 'Такси',
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
    {
      'supplier': 'SUP-1',
      'name': 'Колор-Маркет',
      'city': 'Алматы',
      'paint': true,
    },
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
    return PaintStock(
      paints: _stock.paints,
      queue: _stock.queue,
      suppliers: _stock.suppliers,
      recipe: _stock.recipe,
      materials: _stock.materials,
      receipt: 'STE-${received.length + 10}',
    );
  }

  final photos = <(String, String)>[];

  @override
  Future<void> attachPhoto(
    String receipt,
    String fileName,
    List<int> bytes,
  ) async => photos.add((receipt, fileName));

  @override
  Future<List<PaintReceipt>> history(String item) async => [
    PaintReceipt.fromJson(const {
      'receipt': 'STE-3',
      'date': '2026-11-01',
      'kg': 20,
      'price_kg': 4000,
      'supplier': 'Колор-Маркет',
    }),
  ];

  final counted = <(String, double)>[];
  final settled = <(String, String)>[];

  @override
  Future<PaintStock> settleDelivery(
    String receipt,
    String method, {
    String? bank,
  }) async {
    settled.add((receipt, [method, ?bank].join(' · ')));
    return _stock;
  }

  @override
  Future<PaintStock> count(String item, double kg) async {
    counted.add((item, kg));
    return _stock;
  }

  @override
  Future<PaintStock> paySupplier(
    String receipt,
    String method, {
    String? bank,
  }) async {
    paid.add((receipt, [method, ?bank].join(' · ')));
    return _stock;
  }

  final recipes = <Map<String, Object?>>[];
  final cards = <(String?, String, String?)>[];

  @override
  Future<PaintStock> addSupplier(PaintSupplierCard card) async {
    cards.add((null, card.name, card.minOrder));
    return _stock;
  }

  @override
  Future<PaintStock> setSupplier(String id, PaintSupplierCard card) async {
    cards.add((id, card.name, card.minOrder));
    return _stock;
  }

  @override
  Future<PaintStock> setRecipe(PaintRecipe recipe) async {
    recipes.add(recipe.toJson());
    return _stock;
  }

  final plans = <(double, String?)>[];

  @override
  Future<PaintPlan> plan(double m2, {String? colour}) async {
    plans.add((m2, colour));
    return PaintPlan.fromJson({
      'm2': m2,
      'colour': colour,
      'lines': [
        const {'name': 'Грунт', 'kg': 2.1, 'price_kg': 2000, 'cost': 4200},
        {'name': 'Эмаль', 'colour': colour, 'kg': 3.36, 'cost': null},
      ],
      'kg': 5.46,
      'cost': 4200,
      'cost_m2': 300,
      'priced': false,
      'text': 'RAL 9016 — 14 м²: Грунт 2,1 кг; Эмаль 3,36 кг',
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The colours' window, behind the receipt's colour tile.
class _Colours implements PaintCatalogueRepository {
  @override
  Future<PaintCatalogue> catalogue({String? customer}) async =>
      PaintCatalogue.fromJson({
        'systems': const [
          {'name': 'RAL Classic', 'count': 2},
        ],
        'families': const ['Белые и чёрные'],
        'colours': [
          for (final (code, name, hex) in const [
            ('RAL 9016', 'Транспортный белый', '#F4F4ED'),
            ('RAL 9010', 'Чисто-белый', '#F1ECE1'),
          ])
            {
              'key': 'ral${code.substring(4)}',
              'code': code,
              'name': name,
              'value': code,
              'system': 'RAL Classic',
              'hex': hex,
              'family': 'Белые и чёрные',
              'on_list': true,
            },
        ],
      });

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
        paintCatalogueRepositoryProvider.overrideWithValue(_Colours()),
        mdfDictionariesProvider.overrideWith(
          (ref) async => const MdfDictionaries({
            MdfDictKind.bank: [MdfDictEntry(id: 'b1', value: 'Kaspi')],
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

    // Four cans of five kilos at 4 400 a kilo — dearer than 4 000. In cans
    // as last time: the five kilos are there already (owner, 20.11.2026).
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('paintCanKg')))
          .controller!
          .text,
      '5',
    );
    expect(find.byKey(const ValueKey('paintPriceHistory')), findsOne);
    await tester.enterText(find.byKey(const ValueKey('paintCans')), '4');
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
    await tester.tap(
      find.byKey(const ValueKey('filmDelivery:transport:Такси')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmDelivery:cost')),
      '3000',
    );
    await tester.pumpAndSettle();
    // The taxi paid by card, through a bank (owner, 15.11.2026).
    final card = find.byKey(const ValueKey('filmDelivery:method:Карта'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmDelivery:bank:Kaspi')));
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
    expect((delivery['method'], delivery['bank']), ('Карта', 'Kaspi'));
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
    // A transfer asks through which bank (owner, 15.11.2026).
    await tester.tap(find.byKey(const ValueKey('filmAskBank:Kaspi')));
    await tester.pumpAndSettle();
    expect(repo.paid, [('STE-5', 'Перевод · Kaspi')]);
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

  testWidgets('a taxi an employee paid for is owed to him, and given back', (
    tester,
  ) async {
    final repo = await _pump(tester);
    expect(find.text('Асет paid · Такси'), findsOne);
    await tester.tap(find.byKey(const ValueKey('paintDeliverySettle:STE-8')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('paintDeliveryHow:Наличные')).last,
    );
    await tester.pumpAndSettle();
    expect(repo.settled, [('STE-8', 'Наличные')]);
  });

  testWidgets('the recipe is the shop’s own: a coat more, a thinner into '
      'the enamel', (tester) async {
    final repo = await _pump(tester);
    expect(find.textContaining('Recipe: 0,3 kg/m²'), findsOne);
    await tester.tap(find.byKey(const ValueKey('paintRecipe')));
    await tester.pumpAndSettle();
    // Two coats of primer, and a thinner into the enamel.
    await tester.enterText(
      find.byKey(const ValueKey('paintLayerCoats:0')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('paintPartAdd:1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paintPartName:1:0')),
      'Разбавитель',
    );
    // As painters say it: 20 % of the weight.
    await tester.enterText(
      find.byKey(const ValueKey('paintPartPerKg:1:0')),
      '20',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paintRecipeSave')));
    await tester.pumpAndSettle();
    final layers = repo.recipes.single['layers']! as List;
    final primer = layers.first as Map;
    final enamel = layers.last as Map;
    expect(primer['coats'], 2);
    expect(enamel['colour'], true);
    expect(enamel['parts'], [
      {'name': 'Разбавитель', 'per_kg': 0.2, 'price_kg': 0.0},
    ]);
  });

  testWidgets('a colour of the queue says what it takes and what it costs, '
      'ready to send', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('paintNeed:RAL 9016')));
    await tester.pumpAndSettle();
    expect(repo.plans.single, (14.0, 'RAL 9016'));
    expect(find.byKey(const ValueKey('paintPlanLine:Грунт')), findsOne);
    expect(find.byKey(const ValueKey('paintPlanUnpriced')), findsOne);
    expect(find.byKey(const ValueKey('paintShare:wa')), findsOne);
    // The shop's price a m² beside the cost: what is left, and remembered.
    expect(find.byKey(const ValueKey('paintPlanLeftM2')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('paintPlanPriceM2')),
      '1000',
    );
    await tester.enterText(find.byKey(const ValueKey('paintPlanMarkup')), '50');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintPlanLeftM2')), findsOne);
    expect(find.byKey(const ValueKey('paintPlanByMarkup')), findsOne);
    await tester.tap(find.byKey(const ValueKey('paintPlanRemember')));
    await tester.pumpAndSettle();
    final saved = repo.recipes.single;
    expect((saved['price_m2'], saved['markup_pct']), (1000.0, 50.0));
  });

  testWidgets('a paint supplier is a card of its own: who, the number, the '
      'smallest batch; more than the queue needs is said', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('paintNeedBuy:RAL 9016')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paintSupplierAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paintSupplierCard:name')),
      'Ерлан краски',
    );
    await tester.enterText(
      find.byKey(const ValueKey('paintSupplierCard:min')),
      '5 кг',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paintSupplierCard:save')));
    await tester.pumpAndSettle();
    expect(repo.cards.single, (null, 'Ерлан краски', '5 кг'));
    // 5 kg of a batch for 4,2 kg of queue: the rest goes on the shelf.
    await tester.tap(find.byKey(const ValueKey('paintByCans')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('paintKgValue')), '5');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintBatchLeft')), findsOne);
  });

  testWidgets('primer for the queue is bought with no colour', (tester) async {
    final repo = await _pump(tester);
    expect(find.byKey(const ValueKey('paintMaterial:Грунт')), findsOne);
    await tester.tap(find.byKey(const ValueKey('paintMaterialBuy:Грунт')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintColourDict')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('paintKgValue')), '20');
    await tester.enterText(
      find.byKey(const ValueKey('paintPriceKgValue')),
      '2000',
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('paintReceiveSave'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final got = repo.received.single;
    expect((got['colour'], got['base'], got['kg']), ('', 'Грунт', 20.0));
  });

  testWidgets('a receipt in its order: what came, the colour from the '
      "colours' window — what the queue waits for first — or a material's "
      'kind', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('paintReceive')));
    await tester.pumpAndSettle();
    for (var n = 1; n <= 5; n++) {
      expect(find.byKey(ValueKey('paintStep:$n')), findsOne);
    }
    // No colour yet: the tile opens the window, the queue's colours first.
    await tester.tap(find.byKey(const ValueKey('paintColour:null')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ppPinned:queue')), findsOne);
    expect(find.textContaining('2,2 kg short'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('ppColour:queue:ral9016')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintColour:RAL 9016')), findsOne);
    // A colourless material: its kinds instead of a colour.
    await tester.tap(find.byKey(const ValueKey('paintKind:Грунт')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintColour:RAL 9016')), findsNothing);
    expect(find.byKey(const ValueKey('paintVariant:Грунт')), findsOne);
    await tester.tap(find.byKey(const ValueKey('paintVariantNew')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('paintBase')))
          .controller!
          .text,
      'Грунт ',
    );
    await tester.tap(find.byKey(const ValueKey('paintKind:paint')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintColour:RAL 9016')), findsOne);
  });

  testWidgets('one receipt, several positions: the delivery shared by the '
      "kilo, the invoice's photo on each", (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('paintMaterialBuy:Грунт')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('paintKgValue')), '10');
    await tester.enterText(
      find.byKey(const ValueKey('paintPriceKgValue')),
      '2000',
    );
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('paintLineMore'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintLine:0')), findsOne);
    // The next: hardener, 30 kg.
    await tester.tap(find.byKey(const ValueKey('paintKind:Отвердитель')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('paintKgValue')), '30');
    await tester.enterText(
      find.byKey(const ValueKey('paintPriceKgValue')),
      '1000',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('filmDelivery:transport:Такси')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmDelivery:cost')),
      '4000',
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('paintReceiveSave'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      [for (final r in repo.received) (r['base'], r['kg'])],
      [('Грунт', 10.0), ('Отвердитель', 30.0)],
    );
    // 4 000 of a taxi over 40 kg: 1 000 and 3 000.
    expect(
      [
        for (final r in repo.received)
          (r['delivery']! as Map<String, Object?>)['amount'],
      ],
      [1000.0, 3000.0],
    );
  });
}
