import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/enquiry_flow/application/image_picker_service.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/crew.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order_operation.dart';
import 'package:korkem_flow/features/production/presentation/complete_operation_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockProductionCommandRepository extends Mock
    implements ProductionCommandRepository {}

class _FakeCamera implements ImagePickerService {
  @override
  Future<XFile?> pickImageFromCamera() async =>
      XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'IMG_1.jpg');

  @override
  Future<List<XFile>> pickMultiImage() async => const [];
}

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

  setUpAll(() => registerFallbackValue(XFile('')));

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
          imagePickerServiceProvider.overrideWithValue(_FakeCamera()),
          pieceRatesProvider.overrideWith(
            (ref) async => const PieceRates(
              rates: [
                PieceRate(
                  operation: 'Распил ДСП',
                  rateType: PieceRate.perPart,
                  rate: 200,
                ),
              ],
              canEdit: false,
            ),
          ),
          workersProvider.overrideWith(
            (ref) async => const [
              Worker(user: 'anna@example.com', name: 'Анна'),
              Worker(user: 'boris@example.com', name: 'Борис'),
            ],
          ),
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

  group('optional defect photo', () {
    final addPhoto = find.byKey(const ValueKey('defectPhotoAdd'));

    Future<void> enterScrap(WidgetTester tester, String value) async {
      await tester.tap(find.byType(CompleteOperationButton));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(1), value);
      await tester.pumpAndSettle();
    }

    testWidgets('is not offered when nothing was scrapped', (tester) async {
      await pumpButton(tester);
      await enterScrap(tester, '0');
      expect(addPhoto, findsNothing);
    });

    testWidgets('is sent to the job card the server booked', (tester) async {
      when(
        () => commandRepo.completeOperation(
          workOrder: any(named: 'workOrder'),
          operation: any(named: 'operation'),
          qty: any(named: 'qty'),
          scrapQty: any(named: 'scrapQty'),
        ),
      ).thenAnswer(
        (_) async =>
            const CompleteOperationResult(status: 'completed', jobCard: 'JC-7'),
      );
      when(
        () => commandRepo.attachDefectPhoto(
          jobCard: any(named: 'jobCard'),
          photo: any(named: 'photo'),
        ),
      ).thenAnswer((_) async {});

      await pumpButton(tester);
      await enterScrap(tester, '1');
      await tester.tap(addPhoto);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('defectPhotoRemove')), findsOneWidget);

      await tester.tap(dialogConfirmButton());
      await tester.pumpAndSettle();

      verify(
        () => commandRepo.attachDefectPhoto(
          jobCard: 'JC-7',
          photo: any(named: 'photo'),
        ),
      ).called(1);
    });

    testWidgets('a stage booked without a photo sends none', (tester) async {
      when(
        () => commandRepo.completeOperation(
          workOrder: any(named: 'workOrder'),
          operation: any(named: 'operation'),
          qty: any(named: 'qty'),
          scrapQty: any(named: 'scrapQty'),
        ),
      ).thenAnswer(
        (_) async =>
            const CompleteOperationResult(status: 'completed', jobCard: 'JC-7'),
      );

      await pumpButton(tester);
      await enterScrap(tester, '1');
      await tester.tap(dialogConfirmButton());
      await tester.pumpAndSettle();

      verifyNever(
        () => commandRepo.attachDefectPhoto(
          jobCard: any(named: 'jobCard'),
          photo: any(named: 'photo'),
        ),
      );
    });
  });

  testWidgets(
    'the piece-rate estimate is the real rate, never an invented one',
    (
      tester,
    ) async {
      await pumpButton(tester);
      await tester.tap(find.byType(CompleteOperationButton));
      await tester.pumpAndSettle();
      // 6 remaining pieces × 200 ₸ from the server's rate for this operation.
      expect(find.textContaining('1,200'), findsOneWidget);
      expect(find.textContaining('900'), findsNothing);
    },
  );

  testWidgets('a stage done together sends the crew and what each made', (
    tester,
  ) async {
    when(
      () => commandRepo.completeOperation(
        workOrder: any(named: 'workOrder'),
        operation: any(named: 'operation'),
        qty: any(named: 'qty'),
        scrapQty: any(named: 'scrapQty'),
        crew: any(named: 'crew'),
      ),
    ).thenAnswer(
      (_) async => const CompleteOperationResult(status: 'completed'),
    );
    await pumpButton(tester);

    await tester.tap(find.byType(CompleteOperationButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stageCrewPick')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Who made how much, pcs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('crew:anna@example.com')));
    await tester.tap(find.byKey(const ValueKey('crew:boris@example.com')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('crewShare:anna@example.com')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('crewShare:boris@example.com')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('crewDone')));
    await tester.pumpAndSettle();
    expect(find.text('Crew: 2 people'), findsOneWidget);

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    final sent =
        verify(
              () => commandRepo.completeOperation(
                workOrder: 'MFG-WO-2026-00001',
                operation: 'Распил ДСП',
                qty: 6,
                scrapQty: 0,
                crew: captureAny(named: 'crew'),
              ),
            ).captured.single
            as List<CrewShare>;
    expect(sent, [
      (user: 'anna@example.com', share: null, qty: 4.0),
      (user: 'boris@example.com', share: null, qty: 2.0),
    ]);
  });
}
