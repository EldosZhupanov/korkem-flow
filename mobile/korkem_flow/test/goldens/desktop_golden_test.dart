import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/orders_screen.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../support/widget_harness.dart';

/// What a desktop window gets.
///
/// Every other golden in this suite is a 390dp phone, and the tablet one is a
/// hand-composed list rather than a real screen. So the layout that Windows
/// actually shows — list on the left, the selected order on the right — had no
/// golden at all, which meant a change could collapse it back to a phone column
/// and nothing would notice until somebody opened the .exe.
///
/// 1440x900 is the smallest laptop screen worth designing for, and comfortably
/// past the medium breakpoint, so this is the layout in its ordinary state
/// rather than at its threshold.
class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

class _MockProductionCommandRepository extends Mock
    implements ProductionCommandRepository {}

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

void main() {
  const desktop = Size(1440, 900);

  late _MockSalesOrderRepository salesOrderRepo;
  late _MockWorkOrderRepository workOrderRepo;
  late _MockProductionCommandRepository productionCommandRepo;
  late _MockReceivingRepository receivingRepo;

  setUp(() {
    salesOrderRepo = _MockSalesOrderRepository();
    workOrderRepo = _MockWorkOrderRepository();
    productionCommandRepo = _MockProductionCommandRepository();
    receivingRepo = _MockReceivingRepository();
  });

  // Real furniture, real Kazakh customers, real money. A golden full of
  // "Test Item 1" proves the pixels and teaches nothing about the product.
  final orders = <SalesOrder>[
    SalesOrder(
      name: 'SAL-ORD-2026-00001',
      customer: 'Мебель Астана',
      status: SalesOrderStatus.toDeliverAndBill,
      grandTotal: 1200000,
      perDelivered: 60,
      transactionDate: DateTime(2026, 8, 24),
      deliveryDate: DateTime(2026, 9, 12),
    ),
    SalesOrder(
      name: 'SAL-ORD-2026-00002',
      customer: 'ЖК «Есиль Парк»',
      status: SalesOrderStatus.toDeliverAndBill,
      grandTotal: 4350000,
      transactionDate: DateTime(2026, 8, 28),
      deliveryDate: DateTime(2026, 9, 20),
    ),
    SalesOrder(
      name: 'SAL-ORD-2026-00003',
      customer: 'Қарағанды Интерьер',
      status: SalesOrderStatus.completed,
      grandTotal: 890000,
      perDelivered: 100,
      transactionDate: DateTime(2026, 8, 12),
      deliveryDate: DateTime(2026, 8, 30),
    ),
  ];

  testWidgets('a desktop window shows the list and the order together', (
    tester,
  ) async {
    tester.view
      ..physicalSize = desktop * 2
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

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
    ).thenAnswer((_) async => const []);
    when(() => workOrderRepo.fetchForDeal(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesOrderRepositoryProvider.overrideWithValue(salesOrderRepo),
          workOrderRepositoryProvider.overrideWithValue(workOrderRepo),
          productionCommandRepositoryProvider.overrideWithValue(
            productionCommandRepo,
          ),
          receivingRepositoryProvider.overrideWithValue(receivingRepo),
        ],
        child: harness(const OrdersScreen(), locale: const Locale('ru')),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OrdersScreen),
      matchesGoldenFile('desktop_orders_light.png'),
    );
  });
}
