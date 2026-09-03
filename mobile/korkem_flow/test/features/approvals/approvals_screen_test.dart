import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/approvals/application/approvals_controller.dart';
import 'package:korkem_flow/features/approvals/data/pending_action_repository.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/approvals/presentation/approvals_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakePendingActionRepository extends PendingActionRepository {
  _FakePendingActionRepository({
    this.fetchPageHandler,
    this.approveHandler,
    this.rejectHandler,
  }) : super(dummyClient);

  static final FrappeClient dummyClient = FrappeClient(Dio());

  final Future<List<PendingAction>> Function({
    required int pageSize,
    int offset,
    PendingActionStatus? status,
  })?
  fetchPageHandler;

  final Future<void> Function(String id)? approveHandler;
  final Future<void> Function(String id)? rejectHandler;

  @override
  Future<List<PendingAction>> fetchPage({
    required int pageSize,
    int offset = 0,
    PendingActionStatus? status,
  }) async {
    if (fetchPageHandler != null) {
      return fetchPageHandler!(
        pageSize: pageSize,
        offset: offset,
        status: status,
      );
    }
    return const [];
  }

  @override
  Future<void> approve(String id) async {
    if (approveHandler != null) {
      return approveHandler!(id);
    }
  }

  @override
  Future<void> reject(String id) async {
    if (rejectHandler != null) {
      return rejectHandler!(id);
    }
  }
}

void main() {
  final testClock = DateTime(2026, 9, 3, 10);

  Widget buildHarness(
    WidgetTester tester, {
    required PendingActionRepository repository,
    DateTime? now,
  }) {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        pendingActionRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => now ?? testClock),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ApprovalsScreen(),
      ),
    );
  }

  final sampleAction1 = PendingAction(
    id: 'PA-001',
    status: PendingActionStatus.pending,
    agentSkill: 'crm.create_deal',
    entityType: 'CRM Deal',
    entityName: 'Заказ кухни для Ерлана',
    expiresAt: DateTime(2026, 9, 3, 18),
  );

  final sampleAction2 = PendingAction(
    id: 'PA-002',
    status: PendingActionStatus.pending,
    agentSkill: 'inventory.create_material_request',
    entityType: 'Material Request',
    entityName: 'Закуп ЛДСП Дуб Сонома',
    expiresAt: DateTime(2026, 9, 4, 12),
  );

  testWidgets(
    '1. Список показывает то, что ждёт: '
    'навык, целевую сущность, статус и кнопки',
    (tester) async {
      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Согласования'), findsOneWidget);
      expect(find.text('crm.create_deal'), findsOneWidget);
      expect(find.text('CRM Deal Заказ кухни для Ерлана'), findsOneWidget);
      expect(find.text('Ожидает'), findsOneWidget);
      expect(find.textContaining('Истекает:'), findsOneWidget);
      expect(find.text('Согласовать'), findsOneWidget);
      expect(find.text('Отклонить'), findsOneWidget);
    },
  );

  testWidgets(
    '1. Пустой список: показывает ListEmptyView с пояснением, '
    'а не пустой экран',
    (tester) async {
      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Решений не требуется'), findsOneWidget);
      expect(
        find.text('Здесь появятся решения, которых ждёт агент.'),
        findsOneWidget,
      );
      expect(find.text('Согласовать'), findsNothing);
      expect(find.text('Отклонить'), findsNothing);
    },
  );

  testWidgets(
    '1. Истёкшее действие: показывает статус «Истекло» и '
    'скрывает кнопки решения',
    (tester) async {
      final expiredAction = PendingAction(
        id: 'PA-EXP-1',
        status: PendingActionStatus.pending,
        agentSkill: 'crm.create_quote',
        entityType: 'Quotation',
        entityName: 'КП №42',
        expiresAt: DateTime(2026, 9, 3, 9), // Already past relative to 10:00
      );

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          expiredAction,
        ],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('crm.create_quote'), findsOneWidget);
      expect(find.text('Истекло'), findsWidgets);
      // Action buttons must NOT be offered for expired actions
      expect(find.text('Согласовать'), findsNothing);
      expect(find.text('Отклонить'), findsNothing);
    },
  );

  testWidgets(
    '2. «Согласен» действительно вызывает сервер (approve) '
    'и выводит подтверждение',
    (tester) async {
      String? approvedId;

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        approveHandler: (id) async {
          approvedId = id;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      final approveButton = find.widgetWithText(FilledButton, 'Согласовать');
      expect(approveButton, findsOneWidget);

      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      expect(approvedId, 'PA-001');
      expect(find.text('Согласовано'), findsOneWidget);
    },
  );

  testWidgets(
    '3. «Отклонить» действительно вызывает сервер (reject) '
    'и выводит подтверждение',
    (tester) async {
      String? rejectedId;

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        rejectHandler: (id) async {
          rejectedId = id;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      final rejectButton = find.widgetWithText(OutlinedButton, 'Отклонить');
      expect(rejectButton, findsOneWidget);

      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      expect(rejectedId, 'PA-001');
      expect(find.text('Отклонено'), findsOneWidget);
    },
  );

  testWidgets(
    '4. Отказ сервера показан словами сервера '
    '(например, действие устарело/отменено)',
    (tester) async {
      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        approveHandler: (id) async {
          throw const ValidationFailure(
            'Сделка уже закрыта другим менеджером в ERPNext',
          );
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Согласовать'));
      await tester.pumpAndSettle();

      // Verbatim server refusal displayed in SnackBar
      expect(
        find.text('Сделка уже закрыта другим менеджером в ERPNext'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '5. После согласия список обновляется: '
    'согласованное действие уходит из списка',
    (tester) async {
      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
          sampleAction2,
        ],
        approveHandler: (id) async {},
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Initially both actions are present
      expect(find.text('crm.create_deal'), findsOneWidget);
      expect(find.text('inventory.create_material_request'), findsOneWidget);

      // Approve the first action (crm.create_deal)
      final approveButtons = find.widgetWithText(FilledButton, 'Согласовать');
      await tester.tap(approveButtons.first);
      await tester.pumpAndSettle();

      // The approved action must be gone from the list
      expect(find.text('crm.create_deal'), findsNothing);
      // The other action must remain visible
      expect(find.text('inventory.create_material_request'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Согласовать'), findsOneWidget);

      // Now approve the second action
      await tester.tap(find.widgetWithText(FilledButton, 'Согласовать'));
      await tester.pumpAndSettle();

      // Queue is now completely empty -> ListEmptyView appears
      expect(find.text('inventory.create_material_request'), findsNothing);
      expect(find.text('Решений не требуется'), findsOneWidget);
    },
  );

  testWidgets(
    '6. Ошибка сети не съедает действие: '
    'оно остаётся в списке и доступно для повтора',
    (tester) async {
      var callCount = 0;

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        approveHandler: (id) async {
          callCount++;
          if (callCount == 1) {
            throw const NetworkFailure('Сетевое соединение прервано');
          }
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('crm.create_deal'), findsOneWidget);

      // Tap approve -> fails with network error
      await tester.tap(find.widgetWithText(FilledButton, 'Согласовать'));
      await tester.pumpAndSettle();

      // Error message is shown
      expect(find.text('Сетевое соединение прервано'), findsOneWidget);

      // Action is NOT lost! It remains in the list.
      expect(find.text('crm.create_deal'), findsOneWidget);
      final approveButton = find.widgetWithText(FilledButton, 'Согласовать');
      expect(approveButton, findsOneWidget);

      // Retry succeeds on second tap
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.text('Согласовано'), findsOneWidget);
      expect(find.text('crm.create_deal'), findsNothing);
      expect(find.text('Решений не требуется'), findsOneWidget);
    },
  );
}
