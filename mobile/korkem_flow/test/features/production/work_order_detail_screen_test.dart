import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/presentation/work_order_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

const _workOrder = WorkOrder(
  id: 'MFG-WO-00001',
  itemName: 'Шкаф-купе 3-дверный',
  productionItem: 'ITEM-WARDROBE-001',
  status: WorkOrderStatus.inProcess,
  qty: 10,
  producedQty: 4,
  salesOrder: 'SAL-ORD-00001',
  bomNo: 'BOM-WARDROBE-001',
  wipWarehouse: 'Work in Progress - K',
  fgWarehouse: 'Finished Goods - K',
);

void main() {
  late _MockWorkOrderRepository workOrders;

  setUp(() {
    workOrders = _MockWorkOrderRepository();
  });

  void stubWorkOrder({List<WorkOrder> found = const [_workOrder]}) {
    when(
      () => workOrders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer((_) async => found);
  }

  Future<void> pump(
    WidgetTester tester, {
    DateTime? now,
    String id = 'MFG-WO-00001',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          workOrderRepositoryProvider.overrideWithValue(workOrders),
          clockProvider.overrideWithValue(
            () => now ?? DateTime(2026, 9, 1, 12),
          ),
        ],
        child: harness(WorkOrderDetailScreen(id: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the work order header, status, and details', (
    tester,
  ) async {
    stubWorkOrder();
    await pump(tester);

    expect(find.text('MFG-WO-00001'), findsOneWidget);
    expect(find.text('Шкаф-купе 3-дверный'), findsWidgets);
    expect(find.text('ITEM-WARDROBE-001'), findsOneWidget);
    expect(find.textContaining('4 / 10'), findsOneWidget);
    expect(find.text('SAL-ORD-00001'), findsOneWidget);
    expect(find.text('Linked Sales Order'), findsOneWidget);
    expect(find.text('BOM: BOM-WARDROBE-001'), findsOneWidget);
    expect(find.text('WIP warehouse: Work in Progress - K'), findsOneWidget);
    expect(
      find.text('Finished goods warehouse: Finished Goods - K'),
      findsOneWidget,
    );
  });

  testWidgets('hides linked sales order section when salesOrder is absent', (
    tester,
  ) async {
    stubWorkOrder(
      found: const [
        WorkOrder(
          id: 'MFG-WO-00001',
          itemName: 'Тумба прикроватная',
          status: WorkOrderStatus.inProcess,
          qty: 5,
          producedQty: 2,
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Тумба прикроватная'), findsWidgets);
    expect(find.text('Linked Sales Order'), findsNothing);
  });

  testWidgets('a near-miss id is not shown as the work order', (
    tester,
  ) async {
    // A search for MFG-WO-00001 also matches MFG-WO-000011. Showing the
    // wrong work order confidently is worse than saying it was not found.
    stubWorkOrder(
      found: const [
        WorkOrder(
          id: 'MFG-WO-000011',
          itemName: 'Чужой заказ',
          status: WorkOrderStatus.inProcess,
          qty: 1,
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Чужой заказ'), findsNothing);
    expect(find.byType(ErrorView), findsOneWidget);
  });

  testWidgets('shows overdue notice when planned end date has passed', (
    tester,
  ) async {
    stubWorkOrder(
      found: [
        WorkOrder(
          id: 'MFG-WO-00001',
          itemName: 'Стол обеденный',
          status: WorkOrderStatus.inProcess,
          qty: 2,
          plannedEndDate: DateTime(2026, 8, 25),
        ),
      ],
    );
    await pump(tester, now: DateTime(2026, 9, 1, 12));

    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('shows error view and retry button when order is not found', (
    tester,
  ) async {
    stubWorkOrder(found: const []);
    await pump(tester);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
