import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:korkem_flow/features/warehouse/presentation/stock_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockStockRepository extends Mock implements StockRepository {}

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

const _positions = [
  StockPosition(
    itemCode: 'ITEM-WOOD-001',
    itemName: 'ЛДСП Дуб Сонома 16мм',
    warehouse: 'Склад сырья и материалов',
    actualQty: 100,
    reservedQty: 30,
    projectedQty: 70,
    stockUom: 'Лист',
  ),
  StockPosition(
    itemCode: 'ITEM-WOOD-001',
    itemName: 'ЛДСП Дуб Сонома 16мм',
    warehouse: 'Цех распила',
    actualQty: 20,
    reservedQty: 10,
    projectedQty: 10,
    stockUom: 'Лист',
  ),
];

void main() {
  late _MockStockRepository stockRepo;
  late _MockReceivingRepository receivingRepo;

  setUp(() {
    stockRepo = _MockStockRepository();
    receivingRepo = _MockReceivingRepository();
  });

  void stubStock({List<StockPosition> items = _positions}) {
    when(
      () => stockRepo.fetchStock(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer(
      (_) async => StockPage(items: items, total: items.length),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    String itemCode = 'ITEM-WOOD-001',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          stockRepositoryProvider.overrideWithValue(stockRepo),
          receivingRepositoryProvider.overrideWithValue(receivingRepo),
        ],
        child: harness(StockDetailScreen(itemCode: itemCode)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows item header, total summary, and warehouse balances', (
    tester,
  ) async {
    stubStock();
    await pump(tester);

    expect(find.text('ITEM-WOOD-001'), findsWidgets);
    expect(find.text('ЛДСП Дуб Сонома 16мм'), findsWidgets);
    expect(find.text('Лист'), findsOneWidget);

    // Totals across warehouses (100 + 20 = 120, 30 + 10 = 40, 70 + 10 = 80)
    expect(find.text('120'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);

    // Warehouse list
    expect(find.text('Склад сырья и материалов'), findsOneWidget);
    expect(find.text('Цех распила'), findsOneWidget);
    expect(find.text('100 Лист'), findsOneWidget);
    expect(find.text('20 Лист'), findsOneWidget);
  });

  testWidgets('deficit (negative projected qty) shows alert badge', (
    tester,
  ) async {
    stubStock(
      items: const [
        StockPosition(
          itemCode: 'ITEM-WOOD-001',
          itemName: 'ЛДСП Дуб Сонома 16мм',
          warehouse: 'Склад сырья',
          actualQty: 10,
          reservedQty: 50,
          projectedQty: -40,
          stockUom: 'Лист',
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Stock Deficit'), findsWidgets);
    expect(find.text('-40 Лист'), findsOneWidget);
  });

  testWidgets('a near-miss itemCode is not shown as the item', (
    tester,
  ) async {
    stubStock(
      items: const [
        StockPosition(
          itemCode: 'ITEM-WOOD-0011',
          itemName: 'Чужой материал',
          warehouse: 'Склад',
          actualQty: 10,
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Чужой материал'), findsNothing);
    expect(find.byType(ErrorView), findsOneWidget);
  });

  testWidgets('shows error view and retry button when item is not found', (
    tester,
  ) async {
    stubStock(items: const []);
    await pump(tester);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
