import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:korkem_flow/features/warehouse/presentation/create_purchase_order_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

void main() {
  late _MockReceivingRepository receivingRepo;

  const sampleRequest = OrderableMaterialRequest(
    name: 'MAT-MR-2026-00001',
    requestedOn: '2026-09-01',
    neededOn: '2026-09-10',
  );

  setUp(() {
    receivingRepo = _MockReceivingRepository();
    when(
      () => receivingRepo.fetchOrderableMaterialRequests(),
    ).thenAnswer((_) async => [sampleRequest]);
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    String? initialMaterialRequest,
    Future<void> Function()? onOrdered,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receivingRepositoryProvider.overrideWithValue(receivingRepo),
        ],
        child: harness(
          Scaffold(
            body: Center(
              child: CreatePurchaseOrderButton(
                initialMaterialRequest: initialMaterialRequest,
                onOrdered: onOrdered ?? () async {},
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

  testWidgets('renders Create purchase order button', (tester) async {
    await pumpButton(tester);

    expect(find.byType(CreatePurchaseOrderButton), findsOneWidget);
    expect(find.text('Create purchase order'), findsOneWidget);
  });

  testWidgets(
    'tapping button opens dialog with requests and submitting calls order',
    (tester) async {
      var orderedCalled = false;
      when(
        () => receivingRepo.order(
          'MAT-MR-2026-00001',
          supplier: any(named: 'supplier'),
        ),
      ).thenAnswer(
        (_) async => const PurchaseOrderResult(
          status: 'ordered',
          purchaseOrder: 'PUR-ORD-2026-00005',
        ),
      );

      await pumpButton(
        tester,
        onOrdered: () async {
          orderedCalled = true;
        },
      );

      await tester.tap(find.byType(CreatePurchaseOrderButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Create Purchase Order'), findsOneWidget);
      expect(find.text('Needed by: 2026-09-10'), findsOneWidget);
      expect(find.textContaining('MAT-MR-2026-00001'), findsOneWidget);

      await tester.tap(dialogConfirmButton());
      await tester.pumpAndSettle();

      verify(
        () => receivingRepo.order('MAT-MR-2026-00001'),
      ).called(1);
      expect(orderedCalled, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Purchase order PUR-ORD-2026-00005 created'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows empty view when no material requests exist', (
    tester,
  ) async {
    when(
      () => receivingRepo.fetchOrderableMaterialRequests(),
    ).thenAnswer((_) async => []);

    await pumpButton(tester);

    await tester.tap(find.byType(CreatePurchaseOrderButton));
    await tester.pumpAndSettle();

    expect(find.text('No material requests'), findsOneWidget);
    expect(
      find.text('All material purchase requests have already been ordered.'),
      findsOneWidget,
    );
  });

  testWidgets('shows server refusal message', (tester) async {
    when(
      () => receivingRepo.order(
        'MAT-MR-2026-00001',
        supplier: any(named: 'supplier'),
      ),
    ).thenAnswer(
      (_) async => const PurchaseOrderResult(
        status: 'blocked',
        message: 'Заявка ещё не утверждена',
      ),
    );

    await pumpButton(tester);

    await tester.tap(find.byType(CreatePurchaseOrderButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(find.text('Заявка ещё не утверждена'), findsOneWidget);
  });

  testWidgets('handles offline MutationQueued gracefully', (tester) async {
    var orderedCalled = false;
    when(
      () => receivingRepo.order(
        'MAT-MR-2026-00001',
        supplier: any(named: 'supplier'),
      ),
    ).thenThrow(const MutationQueued('cmd-po-1'));

    await pumpButton(
      tester,
      onOrdered: () async {
        orderedCalled = true;
      },
    );

    await tester.tap(find.byType(CreatePurchaseOrderButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(orderedCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
