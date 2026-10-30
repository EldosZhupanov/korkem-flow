import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:korkem_flow/features/warehouse/domain/stock_item.dart';
import 'package:korkem_flow/features/warehouse/presentation/stock_detail_screen.dart';
import 'package:korkem_flow/features/warehouse/presentation/warehouse_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockStockRepository extends Mock implements StockRepository {}

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

const _item = StockItem(
  id: 'ITEM-WOOD-001',
  name: 'ЛДСП Дуб Сонома 16мм',
  itemGroup: 'Плитные материалы',
  stockUom: 'Лист',
);

const _item2 = StockItem(
  id: 'ITEM-WOOD-002',
  name: 'МДФ Шлифованный 18мм',
  itemGroup: 'Плитные материалы',
  stockUom: 'Лист',
);

const _balances = [
  StockBalance(
    warehouse: 'Склад сырья и материалов',
    actualQty: 100,
    reservedQty: 30,
    projectedQty: 70,
    stockUom: 'Лист',
  ),
];

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
    itemCode: 'ITEM-WOOD-002',
    itemName: 'МДФ Шлифованный 18мм',
    warehouse: 'Основной склад',
    actualQty: 50,
    reservedQty: 10,
    projectedQty: 40,
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

  testWidgets(
    'expanding StockItemCard and tapping Open button navigates to /warehouse/:itemCode',
    (tester) async {
      when(
        () => stockRepo.fetchItems(
          pageSize: any(named: 'pageSize'),
          offset: any(named: 'offset'),
          search: any(named: 'search'),
          includeDisabled: any(named: 'includeDisabled'),
        ),
      ).thenAnswer((_) async => [_item]);

      when(
        () => stockRepo.fetchBalances('ITEM-WOOD-001'),
      ).thenAnswer((_) async => _balances);

      var navigatedPath = '';

      final router = GoRouter(
        initialLocation: '/warehouse',
        routes: [
          GoRoute(
            path: '/warehouse',
            builder: (context, state) => const Scaffold(
              body: WarehouseScreen(),
            ),
          ),
          GoRoute(
            path: '/warehouse/:itemCode',
            builder: (context, state) {
              navigatedPath = state.uri.path;
              return Scaffold(
                body: Text('Detail: ${state.pathParameters['itemCode']}'),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockRepositoryProvider.overrideWithValue(stockRepo),
            receivingRepositoryProvider.overrideWithValue(receivingRepo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card is displayed in collapsed state
      expect(find.text('ЛДСП Дуб Сонома 16мм'), findsOneWidget);
      expect(find.text('Склад сырья и материалов'), findsNothing);

      // Tap card to expand inline balances
      await tester.tap(find.text('ЛДСП Дуб Сонома 16мм'));
      await tester.pumpAndSettle();

      // Balances and Open button are now visible
      expect(find.text('Склад сырья и материалов'), findsOneWidget);
      final openButton = find.widgetWithText(TextButton, 'Open');
      expect(openButton, findsOneWidget);

      // Tap Open button to navigate to stock detail screen
      await tester.tap(openButton);
      await tester.pumpAndSettle();

      expect(navigatedPath, Routes.stockItem('ITEM-WOOD-001'));
      expect(find.text('Detail: ITEM-WOOD-001'), findsOneWidget);
    },
  );

  testWidgets('narrow screen shows single-column list without master-detail', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 2
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    when(
      () => stockRepo.fetchItems(
        pageSize: any(named: 'pageSize'),
        offset: any(named: 'offset'),
        search: any(named: 'search'),
        includeDisabled: any(named: 'includeDisabled'),
      ),
    ).thenAnswer((_) async => [_item, _item2]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockRepositoryProvider.overrideWithValue(stockRepo),
          receivingRepositoryProvider.overrideWithValue(receivingRepo),
        ],
        child: harness(const WarehouseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StockItemCard), findsNWidgets(2));
    expect(find.byType(StockDetailView), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets(
    'wide screen shows master-detail layout with auto-selected first item',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1024, 768) * 2
        ..devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      when(
        () => stockRepo.fetchItems(
          pageSize: any(named: 'pageSize'),
          offset: any(named: 'offset'),
          search: any(named: 'search'),
          includeDisabled: any(named: 'includeDisabled'),
        ),
      ).thenAnswer((_) async => [_item, _item2]);

      when(
        () => stockRepo.fetchStock(
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((invocation) async {
        final search = invocation.namedArguments[#search] as String?;
        final items = _positions
            .where((p) => search == null || p.itemCode == search)
            .toList();
        return StockPage(items: items, total: items.length);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockRepositoryProvider.overrideWithValue(stockRepo),
            receivingRepositoryProvider.overrideWithValue(receivingRepo),
          ],
          child: harness(const WarehouseScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Both cards in master list
      expect(find.text('ЛДСП Дуб Сонома 16мм'), findsWidgets);
      expect(find.text('МДФ Шлифованный 18мм'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Detail view is mounted in the right pane for the first item
      expect(find.byType(StockDetailView), findsOneWidget);
      expect(find.text('Склад сырья и материалов'), findsOneWidget);

      // Tapping second item card updates the right detail pane
      await tester.tap(find.text('МДФ Шлифованный 18мм'));
      await tester.pumpAndSettle();

      expect(find.byType(StockDetailView), findsOneWidget);
      expect(find.text('Основной склад'), findsOneWidget);
    },
  );
}
