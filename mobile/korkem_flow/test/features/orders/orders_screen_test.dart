import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/orders_screen.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

class _MockProductionCommandRepository extends Mock
    implements ProductionCommandRepository {}

void main() {
  late _MockSalesOrderRepository salesOrderRepo;
  late _MockProductionCommandRepository productionCommandRepo;

  setUp(() {
    salesOrderRepo = _MockSalesOrderRepository();
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
  }) async {
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesOrderRepositoryProvider.overrideWithValue(salesOrderRepo),
          productionCommandRepositoryProvider.overrideWithValue(
            productionCommandRepo,
          ),
        ],
        child: harness(const OrdersScreen()),
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
}
