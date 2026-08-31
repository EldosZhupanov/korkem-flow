import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/approvals/application/approvals_controller.dart';
import 'package:korkem_flow/features/approvals/data/pending_action_repository.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/today/presentation/today_screen.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

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

  void mockDefaults({
    List<SalesOrder> orders = const [],
    List<WorkOrder> workOrders = const [],
    List<PendingAction> approvals = const [],
    List<StockPosition> stock = const [],
  }) {
    when(
      () => salesOrderRepo.fetchPage(pageSize: any(named: 'pageSize')),
    ).thenAnswer(
      (_) async => SalesOrdersPage(orders: orders, total: orders.length),
    );

    when(
      () => workOrderRepo.fetchPage(
        pageSize: any(named: 'pageSize'),
        status: WorkOrderStatus.inProcess,
      ),
    ).thenAnswer((_) async => workOrders);

    when(
      () => approvalsRepo.fetchPage(
        pageSize: any(named: 'pageSize'),
        status: PendingActionStatus.pending,
      ),
    ).thenAnswer((_) async => approvals);

    when(
      () => stockRepo.fetchStock(pageSize: any(named: 'pageSize')),
    ).thenAnswer(
      (_) async => StockPage(items: stock, total: stock.length),
    );
  }

  Future<void> pumpTodayScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesOrderRepositoryProvider.overrideWithValue(salesOrderRepo),
          workOrderRepositoryProvider.overrideWithValue(workOrderRepo),
          pendingActionRepositoryProvider.overrideWithValue(approvalsRepo),
          stockRepositoryProvider.overrideWithValue(stockRepo),
          clockProvider.overrideWithValue(() => fixedClock),
        ],
        retry: (_, _) => null,
        child: harness(const TodayScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders all 4 operational tiles with numbers', (tester) async {
    mockDefaults(
      orders: [
        SalesOrder(
          name: 'ORD-1',
          customer: 'Customer 1',
          status: SalesOrderStatus.toDeliverAndBill,
          deliveryDate: DateTime(2026, 9, 10),
        ),
      ],
      workOrders: [
        WorkOrder(
          id: 'WO-1',
          status: WorkOrderStatus.inProcess,
          qty: 10,
          plannedEndDate: DateTime(2026, 9, 15),
        ),
      ],
      stock: [
        const StockPosition(
          itemCode: 'MAT-1',
          warehouse: 'Main',
          actualQty: 10,
          projectedQty: 5,
        ),
      ],
    );

    await pumpTodayScreen(tester);

    expect(find.text('Active Orders'), findsOneWidget);
    expect(find.text('In Production'), findsOneWidget);
    expect(find.text('Pending Approvals'), findsOneWidget);
    expect(find.text('Stock Shortage'), findsOneWidget);

    // All clear because 0 overdue, 0 pending, 0 deficit
    expect(find.text('All Clear', skipOffstage: false), findsOneWidget);
  });

  testWidgets('single tile failure does not crash the other tiles', (
    tester,
  ) async {
    mockDefaults(
      orders: const [
        SalesOrder(
          name: 'ORD-1',
          customer: 'Customer 1',
          status: SalesOrderStatus.toDeliverAndBill,
        ),
      ],
    );

    // Stock repository fails
    when(
      () => stockRepo.fetchStock(pageSize: any(named: 'pageSize')),
    ).thenThrow(const ServerFailure('Stock service unreachable'));

    await pumpTodayScreen(tester);

    // Active orders tile is still healthy and rendered
    expect(find.text('Active Orders'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Stock tile shows localized error message instead of crashing
    expect(find.text('Failed to load'), findsOneWidget);
  });

  testWidgets('shows attention section when overdue or deficit exists', (
    tester,
  ) async {
    mockDefaults(
      orders: [
        SalesOrder(
          name: 'ORD-LATE',
          customer: 'Customer 1',
          status: SalesOrderStatus.toDeliverAndBill,
          deliveryDate: DateTime(2026, 8, 20), // overdue against fixedClock
        ),
      ],
      stock: [
        const StockPosition(
          itemCode: 'MAT-DEFICIT',
          warehouse: 'Main',
          actualQty: 0,
          projectedQty: -5, // deficit
        ),
      ],
    );

    await pumpTodayScreen(tester);

    expect(
      find.text('NEEDS ATTENTION', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('1 overdue', skipOffstage: false), findsWidgets);
    expect(find.text('1 item in deficit', skipOffstage: false), findsWidgets);
  });
}
