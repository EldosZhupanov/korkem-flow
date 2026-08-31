import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/approvals/application/approvals_controller.dart';
import 'package:korkem_flow/features/approvals/data/pending_action_repository.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/today/application/today_controller.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

class _MockPendingActionRepository extends Mock
    implements PendingActionRepository {}

class _MockStockRepository extends Mock implements StockRepository {}

void main() {
  late _MockSalesOrderRepository salesOrderRepo;
  late _MockWorkOrderRepository workOrderRepo;
  late _MockPendingActionRepository approvalsRepo;
  late _MockStockRepository stockRepo;

  final fixedClock = DateTime(2026, 8, 31, 12);

  setUp(() {
    salesOrderRepo = _MockSalesOrderRepository();
    workOrderRepo = _MockWorkOrderRepository();
    approvalsRepo = _MockPendingActionRepository();
    stockRepo = _MockStockRepository();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        salesOrderRepositoryProvider.overrideWithValue(salesOrderRepo),
        workOrderRepositoryProvider.overrideWithValue(workOrderRepo),
        pendingActionRepositoryProvider.overrideWithValue(approvalsRepo),
        stockRepositoryProvider.overrideWithValue(stockRepo),
        clockProvider.overrideWithValue(() => fixedClock),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('todayOrdersSummaryProvider', () {
    test('calculates active and late orders correctly', () async {
      when(
        () => salesOrderRepo.fetchPage(pageSize: any(named: 'pageSize')),
      ).thenAnswer(
        (_) async => SalesOrdersPage(
          orders: [
            SalesOrder(
              name: 'ORD-1',
              customer: 'Client 1',
              status: SalesOrderStatus.toDeliverAndBill,
              deliveryDate: DateTime(2026, 8, 20), // overdue
            ),
            SalesOrder(
              name: 'ORD-2',
              customer: 'Client 2',
              status: SalesOrderStatus.toDeliver,
              deliveryDate: DateTime(2026, 9, 10), // on track
            ),
            SalesOrder(
              name: 'ORD-3',
              customer: 'Client 3',
              status: SalesOrderStatus.completed, // finished
              deliveryDate: DateTime(2026, 8, 15),
            ),
          ],
          total: 3,
        ),
      );

      final container = createContainer();
      final summary = await container.read(todayOrdersSummaryProvider.future);

      expect(summary.activeCount, 2);
      expect(summary.lateCount, 1);
      expect(summary.totalCount, 3);
      expect(summary.lateOrders.single.name, 'ORD-1');
    });
  });

  group('todayProductionSummaryProvider', () {
    test('calculates in-process and late work orders', () async {
      when(
        () => workOrderRepo.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: WorkOrderStatus.inProcess,
        ),
      ).thenAnswer(
        (_) async => [
          WorkOrder(
            id: 'WO-1',
            status: WorkOrderStatus.inProcess,
            qty: 10,
            plannedEndDate: DateTime(2026, 8, 25), // overdue
          ),
          WorkOrder(
            id: 'WO-2',
            status: WorkOrderStatus.inProcess,
            qty: 5,
            plannedEndDate: DateTime(2026, 9, 5), // on track
          ),
        ],
      );

      final container = createContainer();
      final summary = await container.read(
        todayProductionSummaryProvider.future,
      );

      expect(summary.inProcessCount, 2);
      expect(summary.lateCount, 1);
      expect(summary.lateOrders.single.id, 'WO-1');
    });
  });

  group('todayApprovalsSummaryProvider', () {
    test('counts pending approval actions', () async {
      when(
        () => approvalsRepo.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: PendingActionStatus.pending,
        ),
      ).thenAnswer(
        (_) async => [
          const PendingAction(
            id: 'ACT-1',
            status: PendingActionStatus.pending,
            agentSkill: 'Production',
            actionClass: 'Start',
          ),
        ],
      );

      final container = createContainer();
      final summary = await container.read(
        todayApprovalsSummaryProvider.future,
      );

      expect(summary.pendingCount, 1);
      expect(summary.pendingActions.single.id, 'ACT-1');
    });
  });

  group('todayStockSummaryProvider', () {
    test('detects positions with projected qty below zero', () async {
      when(
        () => stockRepo.fetchStock(pageSize: any(named: 'pageSize')),
      ).thenAnswer(
        (_) async => const StockPage(
          items: [
            StockPosition(
              itemCode: 'MAT-1',
              warehouse: 'Main',
              actualQty: 5,
              projectedQty: -3, // deficit
            ),
            StockPosition(
              itemCode: 'MAT-2',
              warehouse: 'Main',
              actualQty: 10,
              projectedQty: 8, // healthy
            ),
          ],
          total: 2,
        ),
      );

      final container = createContainer();
      final summary = await container.read(todayStockSummaryProvider.future);

      expect(summary.deficitCount, 1);
      expect(summary.deficitPositions.single.itemCode, 'MAT-1');
    });
  });
}
