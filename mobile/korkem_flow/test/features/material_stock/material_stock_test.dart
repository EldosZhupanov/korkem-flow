import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/material_stock/data/material_stock_repository.dart';
import 'package:korkem_flow/features/material_stock/domain/material_stock.dart';
import 'package:korkem_flow/features/material_stock/presentation/material_stock_screen.dart';

import '../../support/widget_harness.dart';

class _FakeRepository implements MaterialStockRepository {
  _FakeRepository({required this.canEdit});

  final bool canEdit;
  final defined = <Map<String, String?>>[];
  final received = <(String, double, double, String)>[];

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
  Future<List<StockMaterial>> materials() async => const [
    StockMaterial(
      item: 'MAT-1',
      title: 'МДФ 16 мм Kastamonu',
      kind: StockMaterial.mdf,
      unit: 'лист',
      onHand: 45,
    ),
  ];

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
  }) async {
    received.add((item, qty, pricePerUnit, supplier));
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
    await tester.ensureVisible(find.byKey(const ValueKey('receiveSubmit')));
    await tester.tap(find.byKey(const ValueKey('receiveSubmit')));
    await tester.pumpAndSettle();

    expect(repo.defined.single['thickness'], '16');
    expect(repo.received.single, ('MAT-1', 45.0, 21000.0, 'Profi'));
  });
}
