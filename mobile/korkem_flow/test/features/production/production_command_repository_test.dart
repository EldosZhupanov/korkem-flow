import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late ProductionCommandRepository repository;

  setUp(() {
    client = _MockClient();
    repository = ProductionCommandRepository(
      client,
      MutationOutbox(keyFactory: () => 'test-key'),
    );
  });

  void respond(Map<String, dynamic> message) {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: any(named: 'post'),
      ),
    ).thenAnswer((_) async => {'message': message});
  }

  group('starting production reaches the domain service', () {
    test(
      'it calls the published endpoint, not a doctype and not the assistant',
      () async {
        respond({'status': 'nothing_to_start'});

        await repository.start('SAL-ORD-2026-00011');

        final call = verify(
          () => client.callMethod(
            captureAny(),
            params: captureAny(named: 'params'),
            post: any(named: 'post'),
          ),
        ).captured;

        expect(
          call[0],
          'korkem_manufacturing.api.production.start_production',
          reason: 'the same function the AI tool is registered against',
        );
        expect(call[1], {
          'sales_order': 'SAL-ORD-2026-00011',
          'idempotency_key': 'test-key',
        });
      },
    );

    test('it posts, because it moves stock', () async {
      respond({'status': 'nothing_to_start'});

      await repository.start('SAL-ORD-1');

      verify(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).called(1);
    });

    test('it never sends a company', () async {
      // The server decides scope from the session. A client that could name a
      // company could start production in somebody else's factory.
      respond({'status': 'nothing_to_start'});

      await repository.start('SAL-ORD-1');

      final params =
          verify(
                () => client.callMethod(
                  any(),
                  params: captureAny(named: 'params'),
                  post: any(named: 'post'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(params.containsKey('company'), isFalse);
      expect(params.containsKey('organization'), isFalse);
    });

    test('an item code is sent only when one was named', () async {
      respond({'status': 'nothing_to_start'});

      await repository.start('SAL-ORD-1', itemCode: 'Шкаф Астана');

      final params =
          verify(
                () => client.callMethod(
                  any(),
                  params: captureAny(named: 'params'),
                  post: any(named: 'post'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(params['item_code'], 'Шкаф Астана');
    });
  });

  group('the answer is read, not recomputed', () {
    test('a started job carries what actually moved', () async {
      respond({
        'status': 'started',
        'work_order': 'MFG-WO-2026-00007',
        'transferred_for_qty': 5.0,
        'topped_up': false,
      });

      final result = await repository.start('SAL-ORD-1');

      expect(result.started, isTrue);
      expect(result.workOrder, 'MFG-WO-2026-00007');
      expect(result.transferredForQty, 5.0);
      expect(result.toppedUp, isFalse);
    });

    test(
      'topping up an already running job is not the same as starting one',
      () async {
        respond({
          'status': 'started',
          'work_order': 'MFG-WO-2026-00007',
          'transferred_for_qty': 4.0,
          'topped_up': true,
        });

        final result = await repository.start('SAL-ORD-1');

        expect(
          result.toppedUp,
          isTrue,
          reason: 'the screen must not say "производство запущено" for this',
        );
      },
    );

    test('a refusal is an outcome and carries what is missing', () async {
      respond({
        'status': 'blocked',
        'message': 'Not enough material on the shelf: ДСП 16мм short 4 Лист',
        'blocking_materials': [
          {
            'item_code': 'ДСП 16мм',
            'physical_shortage_qty': 4.0,
            'uom': 'Лист',
          },
        ],
      });

      final result = await repository.start('SAL-ORD-1');

      expect(result.blocked, isTrue);
      expect(result.started, isFalse);
      expect(result.blockingMaterials.single.itemCode, 'ДСП 16мм');
      expect(result.blockingMaterials.single.shortageQty, 4.0);
      expect(result.blockingMaterials.single.uom, 'Лист');
    });

    test('a quantity that arrives as a string is still a number', () async {
      // Frappe returns floats as strings through some code paths.
      respond({
        'status': 'started',
        'work_order': 'MFG-WO-1',
        'transferred_for_qty': '5.0',
      });

      expect((await repository.start('SAL-ORD-1')).transferredForQty, 5.0);
    });

    test('an unrecognised shape does not crash the screen', () async {
      respond(const {});
      expect((await repository.start('SAL-ORD-1')).status, 'unknown');
    });
  });

  group('the LLM is not in this path', () {
    test('a dead AI provider does not stop production', () async {
      // The acceptance criterion for Horizon 1. Before it, the only way to
      // start a job was `chat.send`, so this scenario stopped the shop floor.
      // Here the assistant is irrelevant: nothing in this call touches it, and
      // the endpoint answers normally.
      respond({
        'status': 'started',
        'work_order': 'MFG-WO-2026-00007',
        'transferred_for_qty': 5.0,
      });

      final result = await repository.start('SAL-ORD-1');

      expect(result.started, isTrue);
      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                  post: any(named: 'post'),
                ),
              ).captured.single
              as String;
      expect(
        path.contains('chat'),
        isFalse,
        reason: 'starting production must not go through the assistant',
      );
      expect(path.contains('korkem_ai'), isFalse);
    });

    test('a real failure still surfaces as one', () async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: any(named: 'post'),
        ),
      ).thenThrow(const PermissionFailure('You do not have production rights'));

      expect(
        () => repository.start('SAL-ORD-1'),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });

  group('booking a finished stage', () {
    test('it calls the published endpoint, not a doctype', () async {
      respond({'status': 'ok'});

      await repository.completeOperation(workOrder: 'MFG-WO-1', qty: 4);

      final call = verify(
        () => client.callMethod(
          captureAny(),
          params: captureAny(named: 'params'),
          post: true,
        ),
      ).captured;

      expect(
        call[0],
        'korkem_manufacturing.api.production.complete_operation',
        reason: 'the same function the AI tool is registered against',
      );
      expect(call[1], {
        'work_order': 'MFG-WO-1',
        'qty': 4.0,
        'idempotency_key': 'test-key',
      });
    });

    test('the three quantities stay apart', () async {
      // Good output excludes process loss in ERPNext. Folding scrap into qty
      // would let spoiled panels become finished goods.
      respond({'status': 'ok'});

      await repository.completeOperation(
        workOrder: 'MFG-WO-1',
        qty: 4,
        scrapQty: 1,
        reworkQty: 2,
      );

      final params =
          verify(
                () => client.callMethod(
                  any(),
                  params: captureAny(named: 'params'),
                  post: true,
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(params['qty'], 4.0);
      expect(params['scrap_qty'], 1.0);
      expect(params['rework_qty'], 2.0);
    });

    test('an omitted quantity is not sent as zero', () async {
      // Zero means "none were good". Absent means "take everything
      // outstanding". Sending one for the other books the wrong run.
      respond({'status': 'ok'});

      await repository.completeOperation(workOrder: 'MFG-WO-1');

      final params =
          verify(
                () => client.callMethod(
                  any(),
                  params: captureAny(named: 'params'),
                  post: true,
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(params.containsKey('qty'), isFalse);
      expect(params.containsKey('scrap_qty'), isFalse);
      expect(params, {
        'work_order': 'MFG-WO-1',
        'idempotency_key': 'test-key',
      });
    });

    test('saying it twice is reported as such, not as success', () async {
      respond({
        'status': 'already_complete',
        'job_card': 'JOB-1',
        'operation': 'Раскрой',
        'message': 'Раскрой was already finished.',
      });

      final result = await repository.completeOperation(workOrder: 'MFG-WO-1');

      expect(result.alreadyComplete, isTrue);
      expect(result.operation, 'Раскрой');
    });

    test('it never sends a company', () async {
      respond({'status': 'ok'});

      await repository.completeOperation(workOrder: 'MFG-WO-1');

      final params =
          verify(
                () => client.callMethod(
                  any(),
                  params: captureAny(named: 'params'),
                  post: true,
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(params.containsKey('company'), isFalse);
    });
  });
}
