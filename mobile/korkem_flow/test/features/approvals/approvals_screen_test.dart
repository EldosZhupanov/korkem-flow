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
  final Future<void> Function(String id, {String? reason})? rejectHandler;

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
  Future<void> reject(String id, {String? reason}) async {
    if (rejectHandler != null) {
      return rejectHandler!(id, reason: reason);
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
    '3a. Набранная причина доходит до репозитория дословно '
    'при отклонении',
    (tester) async {
      String? rejectedId;
      String? rejectedReason;

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        rejectHandler: (id, {reason}) async {
          rejectedId = id;
          rejectedReason = reason;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      final rejectButton = find.widgetWithText(OutlinedButton, 'Отклонить');
      expect(rejectButton, findsOneWidget);

      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      // Dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Отклонить действие'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('CRM Deal Заказ кухни для Ерлана'),
        ),
        findsOneWidget,
      );

      // Type the exact reason
      const testReason = 'Не тот клиент, дубль сделки из CRM';
      await tester.enterText(find.byType(TextField), testReason);
      await tester.pumpAndSettle();

      // Confirm reject in dialog
      final confirmRejectButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Отклонить'),
      );
      await tester.tap(confirmRejectButton);
      await tester.pumpAndSettle();

      expect(rejectedId, 'PA-001');
      expect(rejectedReason, testReason);
      expect(find.text('Отклонено'), findsOneWidget);
      expect(find.text('crm.create_deal'), findsNothing);
    },
  );

  testWidgets(
    '3b. Отказ без причины вызывает сервер и проходит '
    '(причина null или пустая)',
    (tester) async {
      String? rejectedId;
      String? rejectedReason;
      var rejectCalled = false;

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        rejectHandler: (id, {reason}) async {
          rejectCalled = true;
          rejectedId = id;
          rejectedReason = reason;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Confirm without typing any reason
      final confirmRejectButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Отклонить'),
      );
      await tester.tap(confirmRejectButton);
      await tester.pumpAndSettle();

      expect(rejectCalled, isTrue);
      expect(rejectedId, 'PA-001');
      expect(rejectedReason, isNull);
      expect(find.text('Отклонено'), findsOneWidget);
      expect(find.text('crm.create_deal'), findsNothing);
    },
  );

  testWidgets(
    '3c. Закрытие диалога кнопкой отмены не вызывает reject вообще '
    '(счётчик вызовов ноль)',
    (tester) async {
      var callCount = 0;

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        rejectHandler: (id, {reason}) async {
          callCount++;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap Cancel in dialog
      final cancelButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Отмена'),
      );
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(callCount, 0);
      expect(find.text('crm.create_deal'), findsOneWidget);
    },
  );

  testWidgets(
    '3d. Закрытие диалога тапом мимо не вызывает reject вообще '
    '(счётчик вызовов ноль)',
    (tester) async {
      var callCount = 0;

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        rejectHandler: (id, {reason}) async {
          callCount++;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap outside the dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(callCount, 0);
      expect(find.text('crm.create_deal'), findsOneWidget);
    },
  );

  testWidgets(
    '4a. Отказ сервера на approve показан словами сервера '
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
    '4b. Отказ сервера на reject показан его словами '
    '(например, действие уже отменено)',
    (tester) async {
      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          sampleAction1,
        ],
        rejectHandler: (id, {reason}) async {
          throw const ServerFailure(
            'Действие уже выполнено другим пользователем',
          );
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить'));
      await tester.pumpAndSettle();

      final confirmRejectButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Отклонить'),
      );
      await tester.tap(confirmRejectButton);
      await tester.pumpAndSettle();

      // Verbatim server refusal displayed in SnackBar
      expect(
        find.text('Действие уже выполнено другим пользователем'),
        findsOneWidget,
      );
      // Action remains in the queue
      expect(find.text('crm.create_deal'), findsOneWidget);
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

  group('Предпросмотр действия перед подтверждением', () {
    testWidgets('предпросмотр показан строками, а не одной строкой JSON', (
      tester,
    ) async {
      const actionWithPreview = PendingAction(
        id: 'PA-PREVIEW-UI-1',
        status: PendingActionStatus.pending,
        agentSkill: 'crm.create_invoice',
        entityType: 'Sales Invoice',
        entityName: 'ACC-SINV-2026-00012',
        preview: ActionPreview(
          title: 'Будет создан счёт',
          fields: [
            ActionPreviewField(label: 'Клиент', value: 'Ерлан Сериков'),
            ActionPreviewField(label: 'Заказ', value: 'SAL-ORD-2026-00042'),
            ActionPreviewField(label: 'Сумма', value: '650 000 ₸'),
            ActionPreviewField(label: 'Срок', value: '17 сентября'),
          ],
        ),
      );

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          actionWithPreview,
        ],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Будет создан счёт'), findsOneWidget);
      expect(find.text('Клиент'), findsOneWidget);
      expect(find.text('Ерлан Сериков'), findsOneWidget);
      expect(find.text('Заказ'), findsOneWidget);
      expect(find.text('SAL-ORD-2026-00042'), findsOneWidget);
      expect(find.text('Сумма'), findsOneWidget);
      expect(find.text('650 000 ₸'), findsOneWidget);
      expect(find.text('Срок'), findsOneWidget);
      expect(find.text('17 сентября'), findsOneWidget);

      // Verify discrete table rows are used rather than a raw JSON dump
      expect(find.byType(Table), findsOneWidget);
      expect(tester.widget<Table>(find.byType(Table)).children.length, 4);
      expect(find.textContaining('{"'), findsNothing);
      expect(find.textContaining('fields'), findsNothing);
    });

    testWidgets(
      'действие без предпросмотра выглядит как раньше и кнопки на месте',
      (tester) async {
        final actionWithoutPreview = PendingAction(
          id: 'PA-NO-PREVIEW',
          status: PendingActionStatus.pending,
          agentSkill: 'crm.create_deal',
          entityType: 'CRM Deal',
          entityName: 'Заказ кухни для Ерлана',
          expiresAt: DateTime(2026, 9, 3, 18),
        );

        final repo = _FakePendingActionRepository(
          fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
            actionWithoutPreview,
          ],
        );

        await tester.pumpWidget(buildHarness(tester, repository: repo));
        await tester.pumpAndSettle();

        expect(find.text('crm.create_deal'), findsOneWidget);
        expect(find.text('CRM Deal Заказ кухни для Ерлана'), findsOneWidget);
        expect(find.text('Ожидает'), findsOneWidget);
        expect(find.textContaining('Истекает:'), findsOneWidget);
        expect(find.text('Согласовать'), findsOneWidget);
        expect(find.text('Отклонить'), findsOneWidget);
        expect(find.byType(Table), findsNothing);
      },
    );

    testWidgets('поля с пустым значением не показываются', (tester) async {
      const actionWithEmptyFields = PendingAction(
        id: 'PA-EMPTY-FIELDS',
        status: PendingActionStatus.pending,
        agentSkill: 'inventory.order_material',
        preview: ActionPreview(
          title: 'Будет создан заказ материалов',
          fields: [
            ActionPreviewField(label: 'Поставщик', value: 'Egger KZ'),
            ActionPreviewField(label: 'Сумма', value: ''),
            ActionPreviewField(label: 'Скидка', value: '   '),
            ActionPreviewField(label: '', value: 'Значение без метки'),
            ActionPreviewField(label: 'Срок', value: '25 сентября'),
          ],
        ),
      );

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          actionWithEmptyFields,
        ],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Будет создан заказ материалов'), findsOneWidget);
      expect(find.text('Поставщик'), findsOneWidget);
      expect(find.text('Egger KZ'), findsOneWidget);
      expect(find.text('Срок'), findsOneWidget);
      expect(find.text('25 сентября'), findsOneWidget);

      // Empty or missing fields must NOT be shown and must not have
      // invented placeholders
      expect(find.text('Сумма'), findsNothing);
      expect(find.text('Скидка'), findsNothing);
      expect(find.text('сумма не указана'), findsNothing);
      expect(find.text('Значение без метки'), findsNothing);
      expect(find.byType(Table), findsOneWidget);
      expect(tester.widget<Table>(find.byType(Table)).children.length, 2);
    });

    testWidgets('длинное значение не ломает вёрстку карточки', (tester) async {
      const actionWithLongValues = PendingAction(
        id: 'PA-LONG-VAL',
        status: PendingActionStatus.pending,
        agentSkill: 'logistics.schedule_delivery',
        preview: ActionPreview(
          title: 'Будет запланирована доставка готовой мебели',
          fields: [
            ActionPreviewField(
              label: 'Адрес доставки',
              value:
                  'Республика Казахстан, город Астана, район Есиль, '
                  'проспект Кабанбай батыра, дом 53, корпус 2, блок Б, '
                  'подъезд 3, этаж 14, квартира 182, домофон 182K '
                  '(просьба оставить у консьержа при отсутствии клиента дома)',
            ),
            ActionPreviewField(
              label: 'Специальные инструкции для водителя и грузчиков',
              value:
                  'Крупногабаритные столешницы из массива дуба 3000х600х40 мм. '
                  'Подъём на 14 этаж только грузовым лифтом. При заносе '
                  'не наклонять упаковку фасадов более чем на 45 градусов.',
            ),
          ],
        ),
      );

      final repo = _FakePendingActionRepository(
        fetchPageHandler: ({required pageSize, offset = 0, status}) async => [
          actionWithLongValues,
        ],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Verify no RenderFlex or layout exceptions occurred
      expect(tester.takeException(), isNull);

      expect(find.text('Адрес доставки'), findsOneWidget);
      expect(find.textContaining('Республика Казахстан'), findsOneWidget);
      expect(find.text('Согласовать'), findsOneWidget);
      expect(find.text('Отклонить'), findsOneWidget);
    });
  });
}
