import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/material_stock/data/material_stock_repository.dart';
import 'package:korkem_flow/features/material_stock/domain/material_stock.dart';
import 'package:korkem_flow/features/material_stock/presentation/material_stock_screen.dart';
import 'package:korkem_flow/features/material_stock/presentation/stock_count_tab.dart';
import 'package:korkem_flow/features/orders/presentation/order_facade_materials_section.dart';

import '../../support/widget_harness.dart';

class _FakeRepository implements MaterialStockRepository {
  _FakeRepository({
    required this.canEdit,
    this.stock = const [
      StockMaterial(
        item: 'MAT-1',
        title: 'МДФ 16 мм Kastamonu',
        kind: StockMaterial.mdf,
        unit: 'лист',
        onHand: 45,
      ),
    ],
    this.need = const FacadeMaterials(
      materials: [],
      unresolved: [],
      fullyHeld: false,
    ),
  });

  final bool canEdit;
  final textured = <(String, bool)>[];

  @override
  Future<void> setFilmTextured(String item, {required bool textured}) async =>
      this.textured.add((item, textured));
  final counts = <Map<String, double>>[];
  @override
  Future<int> recordCount(Map<String, double> counted) async {
    counts.add(counted);
    return counted.length;
  }

  @override
  Future<MonthUsage> monthUsage(String month) async => (
    month: month,
    countedOn: '2026-10-31',
    materials: const [
      MaterialUsage(
        item: 'MAT-1',
        title: 'МДФ 16 мм Kastamonu',
        unit: 'лист',
        start: 0,
        bought: 50,
        end: 2,
        used: 48,
        byOrders: 40,
        unaccounted: 8,
        unaccountedValue: 168000,
      ),
    ],
  );
  final minimums = <(String, double)>[];
  @override
  Future<void> setMinStock(String item, double minimum) async =>
      minimums.add((item, minimum));
  final List<StockMaterial> stock;
  final FacadeMaterials need;
  final defined = <Map<String, String?>>[];
  final received = <(String, double, double, String)>[];
  final deliveries = <ReceiptDelivery?>[];
  final reserved = <String>[];

  @override
  Future<MaterialLists> lists() async => MaterialLists.fromJson({
    ...const {
      'lists': {
        'Толщина МДФ': [
          {'option': 'o1', 'value': '16', 'enabled': true},
        ],
        'Производитель': [
          {'option': 'o2', 'value': 'Kastamonu', 'enabled': true},
        ],
      },
      'suppliers': [
        {'supplier': 'Profi', 'name': 'Profi', 'enabled': true},
      ],
      'units': ['лист', 'м'],
    },
    'can_edit': canEdit,
  });

  @override
  Future<List<StockMaterial>> materials() async => stock;

  @override
  Future<FacadeMaterials> facadeMaterials(String salesOrder) async => need;

  @override
  Future<FacadeMaterials> reserveFacadeMaterials(String salesOrder) async {
    reserved.add(salesOrder);
    return need;
  }

  @override
  Future<StockMaterial> define({
    required String kind,
    required String unit,
    String? thickness,
    String? manufacturer,
    String? color,
    String? width,
    String? filmThickness,
    String? name,
  }) async {
    defined.add({
      'kind': kind,
      'thickness': thickness,
      'manufacturer': manufacturer,
    });
    return const StockMaterial(
      item: 'MAT-1',
      title: 'МДФ 16 мм Kastamonu',
      kind: StockMaterial.mdf,
      unit: 'лист',
      onHand: 45,
    );
  }

  @override
  Future<StockMaterial> receive({
    required String item,
    required double qty,
    required double pricePerUnit,
    required String supplier,
    ReceiptDelivery? delivery,
  }) async {
    received.add((item, qty, pricePerUnit, supplier));
    deliveries.add(delivery);
    return const StockMaterial(
      item: 'MAT-1',
      title: 'МДФ 16 мм Kastamonu',
      kind: StockMaterial.mdf,
      unit: 'лист',
      onHand: 90,
    );
  }

  @override
  Future<MaterialLists> addOption(String list, String value) => lists();

  @override
  Future<MaterialLists> removeOption(String option) => lists();

  @override
  Future<MaterialLists> addSupplier(String name) => lists();

  @override
  Future<MaterialLists> disableSupplier(String supplier) => lists();
}

void main() {
  Future<_FakeRepository> pump(
    WidgetTester tester, {
    required bool canEdit,
  }) async {
    final repo = _FakeRepository(canEdit: canEdit);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [materialStockRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MaterialStockScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('the shop floor sees what is on hand and nothing else', (
    tester,
  ) async {
    await pump(tester, canEdit: false);
    expect(find.textContaining('МДФ 16 мм Kastamonu'), findsOneWidget);
    expect(find.textContaining('45'), findsOneWidget);
    expect(find.text('Receive'), findsNothing);
  });

  testWidgets('a manager receives sheets bought from a supplier', (
    tester,
  ) async {
    final repo = await pump(tester, canEdit: true);
    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pick:Толщина МДФ')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick:Производитель')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kastamonu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pickSupplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profi').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('receiveQty')), '45');
    await tester.enterText(find.byKey(const ValueKey('receivePrice')), '21000');
    // Let the focused field scroll its caret into view first; otherwise it
    // scrolls back over the button after ensureVisible.
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('receiveSubmit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receiveSubmit')));
    await tester.pumpAndSettle();

    expect(repo.defined.single['thickness'], '16');
    expect(repo.received.single, ('MAT-1', 45.0, 21000.0, 'Profi'));
    // No delivery typed: none is written, and the reminder will ask later.
    expect(repo.deliveries.single, isNull);
  });

  testWidgets(
    'the delivery is written with the receipt, apart from the price',
    (
      tester,
    ) async {
      final repo = await pump(tester, canEdit: true);
      await tester.tap(find.text('Receive'));
      await tester.pumpAndSettle();
      for (final (key, value) in [
        ('pick:Толщина МДФ', '16'),
        ('pick:Производитель', 'Kastamonu'),
        ('pickSupplier', 'Profi'),
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byKey(const ValueKey('receiveQty')), '30');
      await tester.enterText(
        find.byKey(const ValueKey('receivePrice')),
        '21000',
      );
      for (final (key, value) in [
        ('receiveDeliveryAmount', '10000'),
        ('receiveDeliveryFrom', 'Астана'),
        ('receiveDeliveryTransport', 'Газель'),
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.enterText(find.byKey(ValueKey(key)), value);
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('receiveSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('receiveSubmit')));
      await tester.pumpAndSettle();

      expect(repo.received.single, ('MAT-1', 30.0, 21000.0, 'Profi'));
      final delivery = repo.deliveries.single!;
      expect(
        (delivery.amount, delivery.fromCity, delivery.transport),
        (10000.0, 'Астана', 'Газель'),
      );
    },
  );

  testWidgets('a manager sets the minimum on the material card', (
    tester,
  ) async {
    final repo = await pump(tester, canEdit: true);
    await tester.tap(find.byKey(const ValueKey('material:MAT-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('materialMin')), '10');
    await tester.tap(find.byKey(const ValueKey('materialSave')));
    await tester.pumpAndSettle();

    expect(repo.minimums.single, ('MAT-1', 10.0));
    // The floor sees no card to open: the minimum is the warehouse's to keep.
    expect(repo.textured, isEmpty);
  });

  testWidgets('the month-end count: typed, saved, and the loss shown', (
    tester,
  ) async {
    final repo = await pump(tester, canEdit: true);
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('countQty:MAT-1')), '2');
    await tester.ensureVisible(find.byKey(const ValueKey('countSave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('countSave')));
    await tester.pumpAndSettle();

    expect(repo.counts.single, {'MAT-1': 2.0});
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('usageLoss:MAT-1')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(StockCountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Unaccounted: 8 лист'), findsOneWidget);
  });

  testWidgets('a material below its minimum says so', (tester) async {
    final repo = _FakeRepository(
      canEdit: false,
      stock: const [
        StockMaterial(
          item: 'MAT-3',
          title: 'МДФ 16 мм Kastamonu',
          kind: StockMaterial.mdf,
          unit: 'лист',
          onHand: 3,
          minStock: 10,
          low: true,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [materialStockRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MaterialStockScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Low — minimum 10 лист'), findsOneWidget);
  });

  testWidgets('what is promised to orders is shown apart from what is free', (
    tester,
  ) async {
    final repo = _FakeRepository(
      canEdit: false,
      stock: const [
        StockMaterial(
          item: 'MAT-2',
          title: 'МДФ 18 мм Kastamonu',
          kind: StockMaterial.mdf,
          unit: 'лист',
          onHand: 10,
          reserved: 3,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [materialStockRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MaterialStockScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('materialQty:MAT-2'))).data,
      contains('7'),
    );
    expect(find.textContaining('10 лист'), findsOneWidget);
    expect(find.textContaining('3 лист'), findsOneWidget);
  });

  testWidgets('a facade order says what is short and the warehouse holds it', (
    tester,
  ) async {
    final repo = _FakeRepository(
      canEdit: true,
      need: FacadeMaterials.fromJson(const {
        'materials': [
          {
            'kind': 'МДФ',
            'key': '18',
            'area_m2': 2.3,
            'item': 'MAT-2',
            'title': 'МДФ 18 мм Kastamonu',
            'unit': 'лист',
            'needed': 2,
            'held': 1,
            'issued': 0,
            'free': 1,
            'short': 1,
          },
        ],
        'unresolved': ['Позиция 2: не выбран декор плёнки.'],
        'fully_held': false,
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [materialStockRepositoryProvider.overrideWithValue(repo)],
        child: harness(
          const Scaffold(
            body: SingleChildScrollView(
              child: OrderFacadeMaterialsSection(salesOrder: 'SO-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('МДФ 18 мм Kastamonu'), findsOneWidget);
    expect(find.textContaining('short 1'), findsOneWidget);
    expect(find.textContaining('не выбран декор'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('facadeMaterialsReserve')));
    await tester.pumpAndSettle();
    expect(repo.reserved, ['SO-1']);
  });
}
