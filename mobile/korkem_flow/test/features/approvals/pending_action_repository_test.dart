import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/approvals/data/pending_action_repository.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:mocktail/mocktail.dart';

class _MockFrappeClient extends Mock implements FrappeClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FrappeQuery());
  });

  group('PendingAction domain model', () {
    test('parses full JSON into PendingAction model', () {
      final json = {
        'name': 'PA-2026-00001',
        'status': 'Pending',
        'agent_skill': 'crm.create_deal',
        'entity_type': 'CRM Deal',
        'entity_name': 'DEAL-101',
        'action_class': 'QuoteProposal',
        'expires_at': '2026-09-10T15:00:00.000',
        'resolved_by': 'supervisor@korkem.kz',
        'resolved_at': '2026-09-03T12:00:00.000',
      };

      final action = PendingActionRepository.fromJson(json);

      expect(action.id, 'PA-2026-00001');
      expect(action.status, PendingActionStatus.pending);
      expect(action.isPending, isTrue);
      expect(action.agentSkill, 'crm.create_deal');
      expect(action.entityType, 'CRM Deal');
      expect(action.entityName, 'DEAL-101');
      expect(action.actionClass, 'QuoteProposal');
      expect(action.expiresAt, DateTime.parse('2026-09-10T15:00:00.000'));
      expect(action.resolvedBy, 'supervisor@korkem.kz');
      expect(action.resolvedAt, DateTime.parse('2026-09-03T12:00:00.000'));
    });

    test('trims whitespace and treats empty strings as null', () {
      final json = {
        'name': 'PA-2026-00002',
        'status': 'Approved',
        'agent_skill': '  inventory.order_material  ',
        'entity_type': '   ',
        'entity_name': null,
      };

      final action = PendingActionRepository.fromJson(json);

      expect(action.id, 'PA-2026-00002');
      expect(action.status, PendingActionStatus.approved);
      expect(action.isPending, isFalse);
      expect(action.agentSkill, 'inventory.order_material');
      expect(action.entityType, isNull);
      expect(action.entityName, isNull);
      expect(action.expiresAt, isNull);
    });

    test('falls back to Pending for unknown status wire value', () {
      final action = PendingActionRepository.fromJson(const {
        'name': 'PA-2026-00003',
        'status': 'ArchivedOrFutureState',
        'agent_skill': 'test.skill',
      });

      expect(action.status, PendingActionStatus.pending);
    });

    test('isExpiredAt correctly checks current timestamp', () {
      final action = PendingAction(
        id: 'PA-EXP',
        status: PendingActionStatus.pending,
        agentSkill: 'test',
        expiresAt: DateTime(2026, 9, 3, 12),
      );

      expect(action.isExpiredAt(DateTime(2026, 9, 3, 11, 59)), isFalse);
      expect(action.isExpiredAt(DateTime(2026, 9, 3, 12)), isFalse);
      expect(action.isExpiredAt(DateTime(2026, 9, 3, 12, 1)), isTrue);
    });

    test('equality and hash code are identity based on id', () {
      const a1 = PendingAction(
        id: 'PA-SAME',
        status: PendingActionStatus.pending,
        agentSkill: 'skill1',
      );
      const a2 = PendingAction(
        id: 'PA-SAME',
        status: PendingActionStatus.approved,
        agentSkill: 'skill2',
      );
      const b = PendingAction(
        id: 'PA-DIFF',
        status: PendingActionStatus.pending,
        agentSkill: 'skill1',
      );

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1, isNot(equals(b)));
    });

    test('parses action preview from preview object with title and fields', () {
      final json = {
        'name': 'PA-PREVIEW-1',
        'status': 'Pending',
        'agent_skill': 'crm.create_invoice',
        'preview': {
          'title': 'Будет создан счёт',
          'fields': [
            {'label': 'Клиент', 'value': 'Ерлан Сериков'},
            {'label': 'Заказ', 'value': 'SAL-ORD-2026-00042'},
            {'label': 'Сумма', 'value': '650 000 ₸'},
            {'label': 'Срок', 'value': '17 сентября'},
          ],
        },
      };

      final action = PendingActionRepository.fromJson(json);

      expect(action.preview, isNotNull);
      expect(action.preview!.title, 'Будет создан счёт');
      expect(action.preview!.fields.length, 4);
      expect(
        action.preview!.fields[0],
        const ActionPreviewField(label: 'Клиент', value: 'Ерлан Сериков'),
      );
      expect(
        action.preview!.fields[1],
        const ActionPreviewField(label: 'Заказ', value: 'SAL-ORD-2026-00042'),
      );
      expect(
        action.preview!.fields[2],
        const ActionPreviewField(label: 'Сумма', value: '650 000 ₸'),
      );
      expect(
        action.preview!.fields[3],
        const ActionPreviewField(label: 'Срок', value: '17 сентября'),
      );
    });

    test(
      'parses preview from display_data JSON string with summary and changes',
      () {
        final json = {
          'name': 'PA-PREVIEW-2',
          'status': 'Pending',
          'agent_skill': 'production.create_work_order',
          'display_data': jsonEncode({
            'summary': 'Запуск распила ЛДСП',
            'changes': [
              {'field': 'Цех', 'new': 'Цех 1'},
              {'field': 'Количество', 'new': '12 шт'},
            ],
          }),
        };

        final action = PendingActionRepository.fromJson(json);

        expect(action.preview, isNotNull);
        expect(action.preview!.title, 'Запуск распила ЛДСП');
        expect(action.preview!.fields.length, 2);
        expect(
          action.preview!.fields[0],
          const ActionPreviewField(label: 'Цех', value: 'Цех 1'),
        );
        expect(
          action.preview!.fields[1],
          const ActionPreviewField(label: 'Количество', value: '12 шт'),
        );
      },
    );

    test(
      'filters out fields with empty or whitespace-only labels and values',
      () {
        final json = {
          'name': 'PA-PREVIEW-3',
          'status': 'Pending',
          'agent_skill': 'test.filter',
          'preview': {
            'title': 'Предпросмотр',
            'fields': [
              {'label': 'Клиент', 'value': 'Айдос'},
              {'label': 'Сумма', 'value': ''},
              {'label': 'Скидка', 'value': '   '},
              {'label': '', 'value': 'Без метки'},
              {'label': '   ', 'value': 'Тоже без метки'},
              {'label': 'Срок', 'value': 'Завтра'},
            ],
          },
        };

        final action = PendingActionRepository.fromJson(json);

        expect(action.preview, isNotNull);
        expect(action.preview!.fields.length, 2);
        expect(action.preview!.fields[0].label, 'Клиент');
        expect(action.preview!.fields[0].value, 'Айдос');
        expect(action.preview!.fields[1].label, 'Срок');
        expect(action.preview!.fields[1].value, 'Завтра');
      },
    );

    test('returns null preview when string is malformed or data is empty', () {
      final malformed = PendingActionRepository.fromJson(const {
        'name': 'PA-MALFORMED',
        'status': 'Pending',
        'agent_skill': 'test.bad',
        'display_data': '{broken json :::',
      });
      expect(malformed.preview, isNull);

      final emptyPreview = PendingActionRepository.fromJson(const {
        'name': 'PA-EMPTY',
        'status': 'Pending',
        'agent_skill': 'test.empty',
        'preview': {
          'title': '',
          'fields': <Map<String, dynamic>>[],
        },
      });
      expect(emptyPreview.preview, isNull);
    });
  });

  group('PendingActionRepository', () {
    late _MockFrappeClient client;
    late PendingActionRepository repository;

    setUp(() {
      client = _MockFrappeClient();
      repository = PendingActionRepository(client);
    });

    test(
      'fetchPage requests Pending Action doctype ordered by creation asc',
      () async {
        when(
          () => client.getList(
            'Pending Action',
            any(),
          ),
        ).thenAnswer((invocation) async {
          final query = invocation.positionalArguments[1] as FrappeQuery;
          expect(query.orderBy, 'creation asc');
          expect(query.limitStart, 0);
          expect(query.limitPageLength, 20);
          expect(query.fields, PendingActionRepository.listFields);
          expect(
            query.filters,
            contains(const FrappeFilter.equals('status', 'Pending')),
          );
          return [
            {
              'name': 'PA-1',
              'status': 'Pending',
              'agent_skill': 'create_task',
            },
          ];
        });

        final actions = await repository.fetchPage(
          pageSize: 20,
          status: PendingActionStatus.pending,
        );

        expect(actions.length, 1);
        expect(actions.first.id, 'PA-1');
        expect(actions.first.agentSkill, 'create_task');
        verify(() => client.getList('Pending Action', any())).called(1);
      },
    );

    test('approve calls runDocMethod with approve', () async {
      when(
        () => client.runDocMethod('Pending Action', 'PA-123', 'approve'),
      ).thenAnswer((_) async => {'message': 'ok'});

      await repository.approve('PA-123');

      verify(
        () => client.runDocMethod('Pending Action', 'PA-123', 'approve'),
      ).called(1);
    });

    test(
      'reject calls runDocMethod with reject without args when reason is null',
      () async {
        when(
          () => client.runDocMethod('Pending Action', 'PA-456', 'reject'),
        ).thenAnswer((_) async => {'message': 'rejected'});

        await repository.reject('PA-456');

        verify(
          () => client.runDocMethod('Pending Action', 'PA-456', 'reject'),
        ).called(1);
      },
    );

    test(
      'reject calls runDocMethod with args containing reason when provided',
      () async {
        when(
          () => client.runDocMethod(
            'Pending Action',
            'PA-456',
            'reject',
            args: {'reason': 'Не тот клиент'},
          ),
        ).thenAnswer((_) async => {'message': 'rejected'});

        await repository.reject('PA-456', reason: 'Не тот клиент');

        verify(
          () => client.runDocMethod(
            'Pending Action',
            'PA-456',
            'reject',
            args: {'reason': 'Не тот клиент'},
          ),
        ).called(1);
      },
    );

    test('reject ignores whitespace-only reason and passes no args', () async {
      when(
        () => client.runDocMethod('Pending Action', 'PA-456', 'reject'),
      ).thenAnswer((_) async => {'message': 'rejected'});

      await repository.reject('PA-456', reason: '   ');

      verify(
        () => client.runDocMethod('Pending Action', 'PA-456', 'reject'),
      ).called(1);
    });
  });
}
