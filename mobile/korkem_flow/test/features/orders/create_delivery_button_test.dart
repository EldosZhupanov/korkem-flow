import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/orders/presentation/create_delivery_button.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

void main() {
  late _MockReceivingRepository receivingRepo;

  setUp(() {
    receivingRepo = _MockReceivingRepository();
  });

  Future<void> pumpButton(
    WidgetTester tester, {
    String salesOrder = 'SAL-ORD-2026-00001',
    Future<void> Function()? onDelivered,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receivingRepositoryProvider.overrideWithValue(receivingRepo),
        ],
        child: harness(
          Scaffold(
            body: Center(
              child: CreateDeliveryButton(
                salesOrder: salesOrder,
                onDelivered: onDelivered ?? () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders Create delivery button', (tester) async {
    await pumpButton(tester);

    expect(find.byType(CreateDeliveryButton), findsOneWidget);
    expect(find.text('Create delivery'), findsOneWidget);
  });

  testWidgets(
    'tapping button calls ship and shows success on dispatched delivery',
    (tester) async {
      var deliveredCalled = false;
      when(
        () => receivingRepo.ship('SAL-ORD-2026-00001'),
      ).thenAnswer(
        (_) async => const DeliveryResult(
          status: 'delivered',
          deliveryNote: 'MAT-DN-2026-00001',
        ),
      );

      await pumpButton(
        tester,
        onDelivered: () async {
          deliveredCalled = true;
        },
      );

      await tester.tap(find.byType(CreateDeliveryButton));
      await tester.pumpAndSettle();

      verify(() => receivingRepo.ship('SAL-ORD-2026-00001')).called(1);
      expect(deliveredCalled, isTrue);
      expect(
        find.text('Delivery note MAT-DN-2026-00001 created'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows adjusted notice when server reports trimmed quantity due to '
    'shelf availability',
    (tester) async {
      var deliveredCalled = false;
      when(
        () => receivingRepo.ship('SAL-ORD-2026-00001'),
      ).thenAnswer(
        (_) async => const DeliveryResult(
          status: 'delivered',
          deliveryNote: 'MAT-DN-2026-00002',
          adjusted: true,
        ),
      );

      await pumpButton(
        tester,
        onDelivered: () async {
          deliveredCalled = true;
        },
      );

      await tester.tap(find.byType(CreateDeliveryButton));
      await tester.pumpAndSettle();

      expect(deliveredCalled, isTrue);
      expect(
        find.text(
          'Partial delivery MAT-DN-2026-00002 created for available stock',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows already delivered notice when order is already fulfilled',
    (tester) async {
      var deliveredCalled = false;
      when(
        () => receivingRepo.ship('SAL-ORD-2026-00001'),
      ).thenAnswer(
        (_) async => const DeliveryResult(
          status: 'already_delivered',
          message: 'Everything on this order has already been delivered.',
        ),
      );

      await pumpButton(
        tester,
        onDelivered: () async {
          deliveredCalled = true;
        },
      );

      await tester.tap(find.byType(CreateDeliveryButton));
      await tester.pumpAndSettle();

      expect(deliveredCalled, isTrue);
      expect(
        find.text('Everything on this order has already been delivered.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows server refusal dialog and message when nothing is on shelf',
    (tester) async {
      when(
        () => receivingRepo.ship('SAL-ORD-2026-00001'),
      ).thenAnswer(
        (_) async => const DeliveryResult(
          status: 'nothing_shippable',
          message:
              'Nothing is on the shelf to send: ITEM-WARDROBE-001 short 10 Nos',
        ),
      );

      await pumpButton(tester);

      await tester.tap(find.byType(CreateDeliveryButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(
          'Nothing is on the shelf to send: ITEM-WARDROBE-001 short 10 Nos',
        ),
        findsWidgets,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cannot Create Delivery'), findsOneWidget);
    },
  );

  testWidgets('handles offline MutationQueued gracefully', (tester) async {
    var deliveredCalled = false;
    when(
      () => receivingRepo.ship('SAL-ORD-2026-00001'),
    ).thenThrow(const MutationQueued('cmd-deliv-1'));

    await pumpButton(
      tester,
      onDelivered: () async {
        deliveredCalled = true;
      },
    );

    await tester.tap(find.byType(CreateDeliveryButton));
    await tester.pumpAndSettle();

    expect(deliveredCalled, isTrue);
  });
}
