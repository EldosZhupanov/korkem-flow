import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/search/presentation/search_screen.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

class _MockStockRepository extends Mock implements StockRepository {}

void main() {
  late _MockSalesOrderRepository orders;
  late _MockWorkOrderRepository workOrders;
  late _MockStockRepository stock;

  setUp(() {
    orders = _MockSalesOrderRepository();
    workOrders = _MockWorkOrderRepository();
    stock = _MockStockRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    final testApp = ProviderScope(
      retry: (_, _) => null,
      overrides: [
        salesOrderRepositoryProvider.overrideWithValue(orders),
        workOrderRepositoryProvider.overrideWithValue(workOrders),
        stockRepositoryProvider.overrideWithValue(stock),
      ],
      child: harness(const SearchScreen()),
    );

    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
  }

  testWidgets('shows initial empty state with search prompt', (tester) async {
    await pump(tester);

    expect(find.text('Search across everything'), findsOneWidget);
    expect(
      find.text(
        'Enter an order number, customer name, work order, or item code.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('typing query debounces and renders grouped results', (
    tester,
  ) async {
    when(
      () => orders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer(
      (_) async => const SalesOrdersPage(
        orders: [
          SalesOrder(
            name: 'SAL-ORD-00001',
            customer: 'Мебель Астана',
            status: SalesOrderStatus.draft,
            grandTotal: 500000,
          ),
        ],
        total: 1,
      ),
    );

    when(
      () => workOrders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer(
      (_) async => const [
        WorkOrder(
          id: 'MFG-WO-0001',
          status: WorkOrderStatus.inProcess,
          qty: 10,
          producedQty: 3,
          itemName: 'Шкаф-купе',
        ),
      ],
    );

    when(
      () => stock.fetchStock(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer(
      (_) async => const StockPage(
        items: [
          StockPosition(
            itemCode: 'MDF-716-396-WG',
            itemName: 'Фасад МДФ Белый',
            warehouse: 'Склад материалов',
            actualQty: 100,
            stockUom: 'Шт',
          ),
        ],
        total: 1,
      ),
    );

    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Мебель');
    // Before debounce duration finishes, no results yet
    await tester.pump(const Duration(milliseconds: 100));
    verifyZeroInteractions(orders);

    // Advance beyond debounce duration
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('ORDERS (1)'), findsOneWidget);
    expect(find.text('Мебель Астана'), findsOneWidget);
    expect(find.text('SAL-ORD-00001'), findsOneWidget);

    expect(find.text('WORK ORDERS (1)'), findsOneWidget);
    expect(find.text('Шкаф-купе'), findsOneWidget);
    expect(find.text('MFG-WO-0001'), findsOneWidget);

    expect(find.text('STOCK (1)'), findsOneWidget);
    expect(find.text('Фасад МДФ Белый'), findsOneWidget);
    expect(find.text('MDF-716-396-WG'), findsOneWidget);
  });

  testWidgets('shows no-results empty view when all sections return 0 items', (
    tester,
  ) async {
    when(
      () => orders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer((_) async => const SalesOrdersPage(orders: [], total: 0));

    when(
      () => workOrders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer((_) async => const []);

    when(
      () => stock.fetchStock(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer((_) async => const StockPage(items: [], total: 0));

    await pump(tester);

    await tester.enterText(find.byType(TextField), 'несуществующий');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Nothing found'), findsOneWidget);
    expect(
      find.textContaining('«несуществующий»'),
      findsOneWidget,
    );
  });

  testWidgets('shows section error card when one query fails', (tester) async {
    when(
      () => orders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenThrow(const ServerFailure('Failed'));

    when(
      () => workOrders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer(
      (_) async => const [
        WorkOrder(
          id: 'MFG-WO-0001',
          status: WorkOrderStatus.inProcess,
          qty: 10,
          itemName: 'Шкаф-купе',
        ),
      ],
    );

    when(
      () => stock.fetchStock(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer((_) async => const StockPage(items: [], total: 0));

    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Шкаф');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load Sales Orders'), findsOneWidget);
    expect(find.text('WORK ORDERS (1)'), findsOneWidget);
    expect(find.text('Шкаф-купе'), findsOneWidget);
  });
}
