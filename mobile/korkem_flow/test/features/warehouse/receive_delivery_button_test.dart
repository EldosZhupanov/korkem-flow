import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:korkem_flow/features/warehouse/presentation/receive_delivery_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

void main() {
  late _MockReceivingRepository receivingRepo;

  const sampleOrder = ReceivablePurchaseOrder(
    name: 'PUR-ORD-2026-00001',
    supplier: 'WoodGroup',
    expectedOn: '2026-09-05',
    receivedPercent: 25,
    total: 450000,
  );

  setUp(() {
    receivingRepo = _MockReceivingRepository();
    when(
      () => receivingRepo.fetchReceivablePurchaseOrders(),
    ).thenAnswer((_) async => [sampleOrder]);
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    String? initialPurchaseOrder,
    Future<void> Function()? onReceived,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receivingRepositoryProvider.overrideWithValue(receivingRepo),
        ],
        child: harness(
          Scaffold(
            body: Center(
              child: ReceiveDeliveryButton(
                initialPurchaseOrder: initialPurchaseOrder,
                onReceived: onReceived ?? () async {},
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

  testWidgets('renders Receive delivery button', (tester) async {
    await pumpButton(tester);

    expect(find.byType(ReceiveDeliveryButton), findsOneWidget);
    expect(find.text('Receive delivery'), findsOneWidget);
  });

  testWidgets(
    'tapping button opens dialog with orders and submitting calls receive',
    (tester) async {
      var receivedCalled = false;
      when(
        () => receivingRepo.receive('PUR-ORD-2026-00001'),
      ).thenAnswer(
        (_) async => const ReceiptResult(
          status: 'received',
          purchaseReceipt: 'MAT-PRE-2026-00001',
        ),
      );

      await pumpButton(
        tester,
        onReceived: () async {
          receivedCalled = true;
        },
      );

      await tester.tap(find.byType(ReceiveDeliveryButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Receive Delivery'), findsOneWidget);
      expect(find.text('WoodGroup'), findsOneWidget);
      expect(find.textContaining('PUR-ORD-2026-00001'), findsOneWidget);

      await tester.tap(dialogConfirmButton());
      await tester.pumpAndSettle();

      verify(() => receivingRepo.receive('PUR-ORD-2026-00001')).called(1);
      expect(receivedCalled, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Purchase receipt MAT-PRE-2026-00001 booked'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows empty view when no orders are receivable', (tester) async {
    when(
      () => receivingRepo.fetchReceivablePurchaseOrders(),
    ).thenAnswer((_) async => []);

    await pumpButton(tester);

    await tester.tap(find.byType(ReceiveDeliveryButton));
    await tester.pumpAndSettle();

    expect(find.text('No deliveries pending'), findsOneWidget);
    expect(
      find.text(
        'All purchase orders have already been received or none are open.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows notice when nothing outstanding remains', (tester) async {
    var receivedCalled = false;
    when(
      () => receivingRepo.receive('PUR-ORD-2026-00001'),
    ).thenAnswer(
      (_) async => const ReceiptResult(
        status: 'nothing_outstanding',
        message: 'All items on this purchase order are already received',
      ),
    );

    await pumpButton(
      tester,
      onReceived: () async {
        receivedCalled = true;
      },
    );

    await tester.tap(find.byType(ReceiveDeliveryButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(receivedCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('All items on this purchase order are already received'),
      findsOneWidget,
    );
  });

  testWidgets('shows server refusal message', (tester) async {
    when(
      () => receivingRepo.receive('PUR-ORD-2026-00001'),
    ).thenAnswer(
      (_) async => const ReceiptResult(
        status: 'blocked',
        message: 'Заказ ещё не согласован',
      ),
    );

    await pumpButton(tester);

    await tester.tap(find.byType(ReceiveDeliveryButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(find.text('Заказ ещё не согласован'), findsOneWidget);
  });

  testWidgets('handles offline MutationQueued gracefully', (tester) async {
    var receivedCalled = false;
    when(
      () => receivingRepo.receive('PUR-ORD-2026-00001'),
    ).thenThrow(const MutationQueued('cmd-recv-1'));

    await pumpButton(
      tester,
      onReceived: () async {
        receivedCalled = true;
      },
    );

    await tester.tap(find.byType(ReceiveDeliveryButton));
    await tester.pumpAndSettle();

    await tester.tap(dialogConfirmButton());
    await tester.pumpAndSettle();

    expect(receivedCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
