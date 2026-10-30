import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/outbox/presentation/outbox_command_formatter.dart';
import 'package:korkem_flow/features/outbox/presentation/outbox_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late MutationOutbox outbox;

  setUp(() {
    client = _MockClient();
    var counter = 0;
    outbox = MutationOutbox(keyFactory: () => 'key-${++counter}');
  });

  tearDown(() => outbox.dispose());

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        mutationOutboxProvider.overrideWithValue(outbox),
        frappeClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OutboxScreen(),
      ),
    ),
  );

  group('describePendingMutation formatter', () {
    test(
      'formats start_production command with human-readable title',
      () async {
        const mutation = PendingMutation(
          key: 'k1',
          path: OutboxEndpoints.startProduction,
          params: {
            'sales_order': 'SAL-ORD-2026-00003',
            'item_code': 'MDF-716-396-WG',
          },
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final info = describePendingMutation(mutation, l10n);

        expect(info.title, 'Start production for SAL-ORD-2026-00003');
        expect(info.icon, AppIcons.workOrder);
        expect(info.details, contains('Item: MDF-716-396-WG'));
      },
    );

    test('formats complete_operation command with operation details', () async {
      const mutation = PendingMutation(
        key: 'k2',
        path: OutboxEndpoints.completeOperation,
        params: {
          'operation': 'Раскрой листового материала',
          'work_order': 'MFG-WO-2026-00012',
          'completed_qty': 8,
          'scrap_qty': 1,
        },
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final info = describePendingMutation(mutation, l10n);

      expect(info.title, 'Operation: Раскрой листового материала');
      expect(info.icon, AppIcons.workOrder);
      expect(info.details, contains('Work order: MFG-WO-2026-00012'));
      expect(info.details, contains('Completed: 8'));
      expect(info.details, contains('Scrap: 1'));
    });

    test(
      'formats receive_purchase_receipt and create_purchase_order',
      () async {
        const receiveMutation = PendingMutation(
          key: 'k3',
          path: 'korkem_manufacturing.api.purchasing.receive_purchase_order',
          params: {'purchase_order': 'PUR-ORD-2026-00045'},
        );

        const orderMutation = PendingMutation(
          key: 'k4',
          path: OutboxEndpoints.createPurchaseOrder,
          params: {
            'material_request': 'MAT-REQ-2026-00010',
            'supplier': 'ТОО Крона KZ',
          },
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final receiveInfo = describePendingMutation(receiveMutation, l10n);
        final orderInfo = describePendingMutation(orderMutation, l10n);

        expect(receiveInfo.title, 'Receive for PUR-ORD-2026-00045');
        expect(receiveInfo.icon, AppIcons.warehouse);

        expect(orderInfo.title, 'Purchase order for MAT-REQ-2026-00010');
        expect(orderInfo.icon, AppIcons.warehouse);
        expect(orderInfo.details, contains('Supplier: ТОО Крона KZ'));
      },
    );

    test('formats create_delivery and generic fallback', () async {
      const shipMutation = PendingMutation(
        key: 'k5',
        path: OutboxEndpoints.createDelivery,
        params: {'sales_order': 'SAL-ORD-2026-00007'},
      );

      const genericMutation = PendingMutation(
        key: 'k6',
        path: 'custom.api.custom_action',
        params: {},
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final shipInfo = describePendingMutation(shipMutation, l10n);
      final genericInfo = describePendingMutation(genericMutation, l10n);

      expect(shipInfo.title, 'Delivery for SAL-ORD-2026-00007');
      expect(shipInfo.icon, AppIcons.deal);

      expect(genericInfo.title, 'Command: custom.api.custom_action');
      expect(genericInfo.icon, AppIcons.refresh);
    });
  });

  group('OutboxScreen UI', () {
    testWidgets('shows empty state when no pending mutations', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.text('All commands sent'), findsOneWidget);
      expect(find.text('Send now'), findsNothing);
    });

    testWidgets('shows queued commands in ordered sequence', (tester) async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenThrow(const NetworkFailure('offline'));

      try {
        await outbox.execute(
          client,
          OutboxEndpoints.startProduction,
          params: {'sales_order': 'SAL-ORD-2026-00001'},
        );
      } on Object catch (_) {}

      try {
        await outbox.execute(
          client,
          OutboxEndpoints.receiveReceipt,
          params: {'purchase_order': 'PUR-ORD-2026-00002'},
        );
      } on Object catch (_) {}

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Command Queue'), findsOneWidget);
      expect(find.text('Send now'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(
        find.text('Start production for SAL-ORD-2026-00001'),
        findsOneWidget,
      );
      expect(find.text('Receive for PUR-ORD-2026-00002'), findsOneWidget);
    });

    testWidgets('tapping Send now triggers outbox retry', (tester) async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenThrow(const NetworkFailure('offline'));

      try {
        await outbox.execute(
          client,
          OutboxEndpoints.startProduction,
          params: {'sales_order': 'SAL-ORD-2026-00001'},
        );
      } on Object catch (_) {}

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      reset(client);
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenAnswer(
        (_) async => {
          'message': {'status': 'ok'},
        },
      );

      await tester.tap(find.text('Send now'));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.text('All commands sent'), findsOneWidget);
    });

    testWidgets('shows a refusal on its own command card', (tester) async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenThrow(const NetworkFailure('offline'));

      try {
        await outbox.execute(
          client,
          OutboxEndpoints.startProduction,
          params: {'sales_order': 'SAL-ORD-2026-00001'},
        );
      } on Object catch (_) {}

      reset(client);
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenAnswer(
        (_) async => {
          'message': {'status': 'blocked', 'message': 'Out of stock'},
        },
      );

      await outbox.retryPending(client);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('A queued command was refused: Out of stock'),
        findsOneWidget,
      );
      expect(
        find.text('Start production for SAL-ORD-2026-00001'),
        findsOneWidget,
      );
      expect(find.text('Refused (1)'), findsOneWidget);
      expect(find.text('Got it, remove'), findsOneWidget);

      await tester.tap(find.text('Got it, remove'));
      await tester.pumpAndSettle();

      expect(
        find.text('A queued command was refused: Out of stock'),
        findsNothing,
      );
      expect(find.byType(EmptyView), findsOneWidget);
    });

    testWidgets('separates commands waiting to send from refused ones', (
      tester,
    ) async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenThrow(const NetworkFailure('offline'));
      for (final order in ['SAL-ORD-1', 'SAL-ORD-2']) {
        try {
          await outbox.execute(
            client,
            OutboxEndpoints.startProduction,
            params: {'sales_order': order},
          );
        } on Object catch (_) {}
      }

      reset(client);
      var replayed = 0;
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenAnswer((_) async {
        replayed++;
        if (replayed == 1) {
          return {
            'message': {'status': 'blocked', 'message': 'No stock'},
          };
        }
        throw const NetworkFailure('offline again');
      });
      await outbox.retryPending(client);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Waiting to send (1)'), findsOneWidget);
      expect(find.text('Refused (1)'), findsOneWidget);
      expect(find.text('Start production for SAL-ORD-1'), findsOneWidget);
      expect(find.text('Start production for SAL-ORD-2'), findsOneWidget);
    });

    testWidgets('removes all refused cards only after a visible action', (
      tester,
    ) async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenThrow(const NetworkFailure('offline'));
      for (final order in ['SAL-ORD-1', 'SAL-ORD-2']) {
        try {
          await outbox.execute(
            client,
            OutboxEndpoints.startProduction,
            params: {'sales_order': order},
          );
        } on Object catch (_) {}
      }

      reset(client);
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenThrow(const PermissionFailure('denied'));
      await outbox.retryPending(client);
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Refused (2)'), findsOneWidget);
      expect(find.text('Remove all'), findsOneWidget);

      await tester.tap(find.text('Remove all'));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyView), findsOneWidget);
    });
  });
}
