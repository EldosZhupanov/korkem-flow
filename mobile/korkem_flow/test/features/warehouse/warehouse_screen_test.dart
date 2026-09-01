import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:korkem_flow/features/warehouse/domain/stock_item.dart';
import 'package:korkem_flow/features/warehouse/presentation/warehouse_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockStockRepository extends Mock implements StockRepository {}

const _item = StockItem(
  id: 'ITEM-WOOD-001',
  name: 'ЛДСП Дуб Сонома 16мм',
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

void main() {
  late _MockStockRepository stockRepo;

  setUp(() {
    stockRepo = _MockStockRepository();
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
}
