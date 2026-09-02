import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/domain/work_order_operation.dart';
import 'package:korkem_flow/features/production/presentation/production_screen.dart';
import 'package:korkem_flow/features/production/presentation/work_order_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

const _wo1 = WorkOrder(
  id: 'MFG-WO-2026-00001',
  itemName: 'Шкаф-купе 3-дверный',
  productionItem: 'ITEM-WARDROBE-001',
  status: WorkOrderStatus.inProcess,
  qty: 10,
  producedQty: 4,
  salesOrder: 'SAL-ORD-00001',
  bomNo: 'BOM-WARDROBE-001',
);

const _wo2 = WorkOrder(
  id: 'MFG-WO-2026-00002',
  itemName: 'Стол Обеденный',
  productionItem: 'ITEM-TABLE-001',
  status: WorkOrderStatus.notStarted,
  qty: 5,
);

const _operations1 = [
  WorkOrderOperation(
    name: 'WO-OP-00001',
    sequence: 1,
    operation: 'Распил ДСП',
    workstation: 'Форматно-раскроечный станок',
    status: 'Work in Progress',
    completedQty: 4,
    plannedMinutes: 60,
  ),
];

const _operations2 = [
  WorkOrderOperation(
    name: 'WO-OP-00002',
    sequence: 1,
    operation: 'Фрезеровка',
    workstation: 'ЧПУ станок',
    status: 'Pending',
    plannedMinutes: 45,
  ),
];

void main() {
  late _MockWorkOrderRepository workOrders;

  setUp(() {
    workOrders = _MockWorkOrderRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<WorkOrder> orders = const [_wo1, _wo2],
    Size? size,
    String? selectedId,
  }) async {
    if (size != null) {
      tester.view
        ..physicalSize = size * 2
        ..devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    when(
      () => workOrders.fetchPage(
        pageSize: any(named: 'pageSize'),
        offset: any(named: 'offset'),
        status: any(named: 'status'),
        search: any(named: 'search'),
      ),
    ).thenAnswer((_) async => orders);

    when(
      () => workOrders.fetchOperations('MFG-WO-2026-00001'),
    ).thenAnswer((_) async => _operations1);

    when(
      () => workOrders.fetchOperations('MFG-WO-2026-00002'),
    ).thenAnswer((_) async => _operations2);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workOrderRepositoryProvider.overrideWithValue(workOrders),
          clockProvider.overrideWithValue(
            () => DateTime(2026, 9, 1, 12),
          ),
        ],
        child: harness(ProductionScreen(selectedId: selectedId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('narrow screen shows single-column list without master-detail', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      size: const Size(390, 844),
    );

    expect(find.byType(WorkOrderCard), findsNWidgets(2));
    expect(find.byType(WorkOrderDetailView), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets(
    'wide screen shows master-detail layout with auto-selected '
    'first work order',
    (tester) async {
      await pumpScreen(
        tester,
        size: const Size(1024, 768),
      );

      // Both cards in master list
      expect(find.text('Шкаф-купе 3-дверный'), findsWidgets);
      expect(find.text('Стол Обеденный'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Detail view is mounted in the right pane for the first order
      expect(find.byType(WorkOrderDetailView), findsOneWidget);
      expect(find.text('Распил ДСП'), findsOneWidget);

      // Tapping second order updates detail pane
      await tester.tap(find.text('Стол Обеденный'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkOrderDetailView), findsOneWidget);
      expect(find.text('Фрезеровка'), findsOneWidget);
    },
  );
}
