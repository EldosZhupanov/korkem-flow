import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order_operation.dart';
import 'package:korkem_flow/features/production/presentation/complete_operation_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockProductionCommandRepository extends Mock
    implements ProductionCommandRepository {}

const _operation = WorkOrderOperation(
  name: 'WO-OP-00001',
  sequence: 1,
  operation: 'Распил ДСП',
  workstation: 'Форматно-раскроечный станок',
  status: 'Work in Progress',
  completedQty: 4,
  plannedMinutes: 60,
);

void main() {
  late _MockProductionCommandRepository commandRepo;

  setUp(() {
    commandRepo = _MockProductionCommandRepository();
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    WorkOrderOperation operation = _operation,
    double orderQty = 10,
    Future<void> Function()? onCompleted,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productionCommandRepositoryProvider.overrideWithValue(commandRepo),
        ],
        child: harness(
          Scaffold(
            body: Center(
              child: CompleteOperationButton(
                workOrder: 'MFG-WO-2026-00001',
                operation: operation,
                orderQty: orderQty,
                onCompleted: onCompleted ?? () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder dialogConfirmButton() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(FilledButton),
  );

  testWidgets('tapping button opens complete operation dialog', (
    tester,
  ) async {
    await pumpButton(tester);

    expect(find.byType(CompleteOperationButton), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);

    await tester.tap(find.byType(CompleteOperationButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Complete Operation'), findsOneWidget);
    expect(find.text('Распил ДСП'), findsOneWidget);
    // Prefilled remaining qty: 10 - 4 = 6
    expect(find.text('6'), findsOneWidget);
    // Scrap prefilled with 0
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets(
    'submitting dialog calls completeOperation with entered quantities',
    (tester) async {
      var completedCalled = false;
      when(
        () => commandRepo.completeOperation(
          workOrder: any(named: 'workOrder'),
          operation: any(named: 'operation'),
          qty: any(named: 'qty'),
          scrapQty: any(named: 'scrapQty'),
        ),
      ).thenAnswer(
        (_) async => const CompleteOperationResult(status: 'completed'),
      );

      await pumpButton(
        tester,
        onCompleted: () async {
          completedCalled = true;
        },
      );

      await tester.tap(find.byType(CompleteOperationButton));
      await tester.pumpAndSettle();

      // Tap confirm action in dialog
      await tester.tap(dialogConfirmButton());
      await tester.pumpAndSettle();

      verify(
        () => commandRepo.completeOperation(
          workOrder: 'MFG-WO-2026-00001',
          operation: 'Распил ДСП',
          qty: 6,
          scrapQty: 0,
        ),
      ).called(1);

      expect(completedCalled, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('handles offline MutationQueued gracefully', (tester) async {
    var completedCalled = false;
    when(
      () => commandRepo.completeOperation(
        workOrder: any(named: 'workOrder'),
        operation: any(named: 'operation'),
        qty: any(named: 'qty'),
        scrapQty: any(named: 'scrapQty'),
      ),
    ).thenThrow(const MutationQueued('cmd-1'));

    await pumpButton(
      tester,
      onCompleted: () async {
        completedCalled = true;
      },
    );

    await tester.tap(find.byType(CompleteOperationButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(completedCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('handles already_complete status outcome', (tester) async {
    var completedCalled = false;
    when(
      () => commandRepo.completeOperation(
        workOrder: any(named: 'workOrder'),
        operation: any(named: 'operation'),
        qty: any(named: 'qty'),
        scrapQty: any(named: 'scrapQty'),
      ),
    ).thenAnswer(
      (_) async => const CompleteOperationResult(status: 'already_complete'),
    );

    await pumpButton(
      tester,
      onCompleted: () async {
        completedCalled = true;
      },
    );

    await tester.tap(find.byType(CompleteOperationButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(completedCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('shows server refusal message when operation cannot be closed', (
    tester,
  ) async {
    when(
      () => commandRepo.completeOperation(
        workOrder: any(named: 'workOrder'),
        operation: any(named: 'operation'),
        qty: any(named: 'qty'),
        scrapQty: any(named: 'scrapQty'),
      ),
    ).thenAnswer(
      (_) async => const CompleteOperationResult(
        status: 'blocked',
        message: 'Предыдущая операция ещё не завершена',
      ),
    );

    await pumpButton(tester);

    await tester.tap(find.byType(CompleteOperationButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(find.text('Предыдущая операция ещё не завершена'), findsOneWidget);
  });
}
