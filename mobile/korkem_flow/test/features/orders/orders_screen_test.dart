import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/delivery_note.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/order_detail_screen.dart';
import 'package:korkem_flow/features/orders/presentation/orders_screen.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

class _MockProductionCommandRepository extends Mock
    implements ProductionCommandRepository {}

void main() {
  late _MockSalesOrderRepository salesOrderRepo;
  late _MockWorkOrderRepository workOrderRepo;
  late _MockProductionCommandRepository productionCommandRepo;

  setUp(() {
    salesOrderRepo = _MockSalesOrderRepository();
    workOrderRepo = _MockWorkOrderRepository();
    productionCommandRepo = _MockProductionCommandRepository();
  });

  SalesOrder createOrder({
    String name = 'SAL-ORD-2026-00001',
    String customer = 'ТОО Мебель Групп',
    SalesOrderStatus status = SalesOrderStatus.toDeliverAndBill,
    double grandTotal = 1500000.0,
    double perDelivered = 0.0,
  }) {
    return SalesOrder(
      name: name,
      customer: customer,
      status: status,
      grandTotal: grandTotal,
      perDelivered: perDelivered,
      transactionDate: DateTime(2026, 8, 31),
      deliveryDate: DateTime(2026, 9, 15),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<SalesOrder> orders = const [],
    List<WorkOrder> workOrders = const [],
    List<SalesOrderDelivery> deliveries = const [],
    Size? size,
    String? selectedName,
  }) async {
    if (size != null) {
      tester.view
        ..physicalSize = size * 2
        ..devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    when(
      () => salesOrderRepo.fetchPage(
        pageSize: any(named: 'pageSize'),
        offset: any(named: 'offset'),
        status: any(named: 'status'),
        search: any(named: 'search'),
      ),
    ).thenAnswer(
      (_) async => SalesOrdersPage(orders: orders, total: orders.length),
    );
    when(
      () => salesOrderRepo.fetchDeliveries(any()),
    ).thenAnswer((_) async => deliveries);
    when(
      () => workOrderRepo.fetchForDeal(any()),
    ).thenAnswer((_) async => workOrders);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesOrderRepositoryProvider.overrideWithValue(salesOrderRepo),
          workOrderRepositoryProvider.overrideWithValue(workOrderRepo),
          productionCommandRepositoryProvider.overrideWithValue(
            productionCommandRepo,
          ),
        ],
        child: harness(OrdersScreen(selectedName: selectedName)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders sales order details in card', (tester) async {
    final order = createOrder();
    await pumpScreen(tester, orders: [order]);

    expect(find.text('ТОО Мебель Групп'), findsOneWidget);
    expect(find.text('SAL-ORD-2026-00001'), findsOneWidget);
    expect(find.byType(SalesOrderCard), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('tapping start button triggers production command', (
    tester,
  ) async {
    final order = createOrder();
    when(
      () => productionCommandRepo.start('SAL-ORD-2026-00001'),
    ).thenAnswer((_) async => const StartProductionResult(status: 'started'));

    await pumpScreen(tester, orders: [order]);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    verify(() => productionCommandRepo.start('SAL-ORD-2026-00001')).called(1);
  });

  testWidgets('shows shortage dialog when production is blocked', (
    tester,
  ) async {
    final order = createOrder();
    when(
      () => productionCommandRepo.start('SAL-ORD-2026-00001'),
    ).thenAnswer(
      (_) async => const StartProductionResult(
        status: 'blocked',
        message: 'Недостаточно материалов на складе',
        blockingMaterials: [
          BlockingMaterial(
            itemCode: 'ДСП 16мм',
            shortageQty: 4,
            uom: 'Лист',
          ),
        ],
      ),
    );

    await pumpScreen(tester, orders: [order]);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('ДСП 16мм'), findsOneWidget);
    expect(find.textContaining('Лист'), findsOneWidget);

    // Dialog can be dismissed
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('narrow screen shows single-column list without master-detail', (
    tester,
  ) async {
    final order = createOrder();
    await pumpScreen(
      tester,
      orders: [order],
      size: const Size(390, 844),
    );

    expect(find.byType(SalesOrderCard), findsOneWidget);
    expect(find.byType(OrderDetailView), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets(
    'wide screen shows master-detail layout with auto-selected first order',
    (tester) async {
      final order1 = createOrder(
        name: 'SAL-ORD-2026-00010',
        customer: 'Клиент Первый',
      );
      final order2 = createOrder(
        name: 'SAL-ORD-2026-00020',
        customer: 'Клиент Второй',
      );

      await pumpScreen(
        tester,
        orders: [order1, order2],
        size: const Size(1024, 768),
      );

      // Both cards rendered in the master list
      expect(find.text('Клиент Первый'), findsWidgets);
      expect(find.text('Клиент Второй'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Detail view is mounted in the right pane for the first order
      expect(find.byType(OrderDetailView), findsOneWidget);

      // Tapping second order card updates the right detail pane
      await tester.tap(find.text('Клиент Второй'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
      expect(find.text('SAL-ORD-2026-00020'), findsWidgets);
    },
  );
}
