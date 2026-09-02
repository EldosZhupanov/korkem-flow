import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/features/production/presentation/complete_operation_button.dart';
import 'package:korkem_flow/features/workstations/data/workstation_repository.dart';
import 'package:korkem_flow/features/workstations/domain/station_operation.dart';
import 'package:korkem_flow/features/workstations/domain/workstation_item.dart';
import 'package:korkem_flow/features/workstations/presentation/workstations_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockWorkstationRepository extends Mock
    implements WorkstationRepository {}

class _MockProductionCommandRepository extends Mock
    implements ProductionCommandRepository {}

const _sampleStations = [
  WorkstationItem(name: 'Edge 1', waiting: 3),
  WorkstationItem(name: 'Распил 1', waiting: 5),
];

const _sampleQueue = [
  StationOperation(
    name: 'OP-0001',
    workOrder: 'MFG-WO-2026-00001',
    operation: 'Edge Banding',
    status: 'Pending',
    plannedMinutes: 45,
    sequence: 1,
    item: 'ITEM-DESK-01',
    itemName: 'Стол Офисный',
    orderQty: 10,
    dueOn: '2026-09-10',
  ),
];

void main() {
  late _MockWorkstationRepository workstationRepo;
  late _MockProductionCommandRepository commandRepo;

  setUp(() {
    workstationRepo = _MockWorkstationRepository();
    commandRepo = _MockProductionCommandRepository();

    when(
      () => workstationRepo.fetchWorkstations(),
    ).thenAnswer((_) async => _sampleStations);

    when(
      () => workstationRepo.fetchStationQueue(any()),
    ).thenAnswer((_) async => _sampleQueue);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? selectedWorkstation,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workstationRepositoryProvider.overrideWithValue(workstationRepo),
          productionCommandRepositoryProvider.overrideWithValue(commandRepo),
        ],
        child: harness(
          WorkstationsScreen(selectedWorkstation: selectedWorkstation),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders list of active workstations with waiting counts', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Workstations'), findsOneWidget);
    expect(find.text('Edge 1'), findsOneWidget);
    expect(find.text('Распил 1'), findsOneWidget);
    expect(find.text('3 operations'), findsOneWidget);
    expect(find.text('5 operations'), findsOneWidget);
  });

  testWidgets('shows empty state when no active workstations exist', (
    tester,
  ) async {
    when(
      () => workstationRepo.fetchWorkstations(),
    ).thenAnswer((_) async => []);

    await pumpScreen(tester);

    expect(find.text('No active jobs'), findsOneWidget);
    expect(
      find.text('All workstations are idle, no unfinished operations.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping workstation opens its queue with operations', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Edge 1'));
    await tester.pumpAndSettle();

    expect(find.text('Edge 1'), findsOneWidget);
    expect(find.text('Edge Banding'), findsOneWidget);
    expect(find.text('Стол Офисный'), findsOneWidget);
    expect(find.text('Quantity: 10 шт'), findsOneWidget);
    expect(find.text('Due: 2026-09-10'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('MFG-WO-2026-00001'), findsOneWidget);
    expect(find.byType(CompleteOperationButton), findsOneWidget);
  });

  testWidgets('shows empty queue state when all done at workstation', (
    tester,
  ) async {
    when(
      () => workstationRepo.fetchStationQueue('Edge 1'),
    ).thenAnswer((_) async => []);

    await pumpScreen(tester, selectedWorkstation: 'Edge 1');

    expect(find.text('All done at this workstation'), findsOneWidget);
    expect(
      find.text('No pending operations waiting at this station.'),
      findsOneWidget,
    );
  });

  testWidgets('wide screen displays master-detail layout', (tester) async {
    await pumpScreen(
      tester,
      size: const Size(AppBreakpoints.medium + 100, 800),
    );

    // Both master list and detail queue visible side-by-side
    expect(find.text('Workstations'), findsOneWidget);
    expect(find.text('Edge 1'), findsWidgets);
    expect(find.text('Распил 1'), findsOneWidget);
    expect(find.text('Edge Banding'), findsOneWidget);
    expect(find.text('Стол Офисный'), findsOneWidget);
  });

  testWidgets(
    'tapping Complete operation button in queue completes operation',
    (tester) async {
      when(
        () => commandRepo.completeOperation(
          workOrder: any(named: 'workOrder'),
          operation: any(named: 'operation'),
          qty: any(named: 'qty'),
          scrapQty: any(named: 'scrapQty'),
        ),
      ).thenAnswer(
        (_) async => const CompleteOperationResult(
          status: 'completed',
          operation: 'OP-0001',
        ),
      );

      await pumpScreen(tester, selectedWorkstation: 'Edge 1');

      expect(find.byType(CompleteOperationButton), findsOneWidget);
      await tester.tap(find.byType(CompleteOperationButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Complete Operation'), findsOneWidget);

      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      verify(
        () => commandRepo.completeOperation(
          workOrder: 'MFG-WO-2026-00001',
          operation: 'Edge Banding',
          qty: 10,
          scrapQty: 0,
        ),
      ).called(1);
    },
  );
}
