import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/api/mutation_outbox_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

class _MemoryOutboxStore implements MutationOutboxStore {
  final values = <String, String>{};
  final writes = <String>[];
  Error? writeError;
  Completer<void>? writeCompleter;

  @override
  Future<String?> read(MutationOutboxScope scope) async =>
      values[scope.storageKey];

  @override
  Future<void> write(MutationOutboxScope scope, String value) async {
    final error = writeError;
    if (error != null) throw error;
    final completer = writeCompleter;
    if (completer != null) return completer.future;
    writes.add(value);
    values[scope.storageKey] = value;
  }
}

void main() {
  late _MockClient client;
  late MutationOutbox outbox;
  var generatedKeys = 0;

  setUp(() {
    client = _MockClient();
    generatedKeys = 0;
    outbox = MutationOutbox(
      keyFactory: () => 'intent-${++generatedKeys}',
    );
  });

  tearDown(() => outbox.dispose());

  Future<Map<String, dynamic>> execute({
    Map<String, dynamic> params = const {'document': 'DOC-1'},
  }) => outbox.execute(client, 'example.mutate', params: params);

  test('the intent key exists on the first network attempt', () async {
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

    await execute();

    final params =
        verify(
              () => client.callMethod(
                'example.mutate',
                params: captureAny(named: 'params'),
                post: true,
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(params['idempotency_key'], 'intent-1');
    expect(generatedKeys, 1);
    expect(outbox.snapshot.pendingCount, 0);
  });

  test('a network failure queues the command, not a new request', () async {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));

    await expectLater(execute(), throwsA(isA<MutationQueued>()));

    expect(outbox.snapshot.pendingCount, 1);
    expect(outbox.snapshot.pending.single.key, 'intent-1');
    expect(generatedKeys, 1);
  });

  test(
    'retry keeps the same key and frozen payload, then removes it',
    () async {
      var attempts = 0;
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw const NetworkFailure('offline');
        return {
          'message': {'status': 'ok'},
        };
      });
      final lines = <Map<String, dynamic>>[
        {'item': 'PANEL', 'qty': 2},
      ];

      await expectLater(
        execute(params: {'document': 'DOC-1', 'lines': lines}),
        throwsA(isA<MutationQueued>()),
      );
      lines.single['qty'] = 99;
      lines.add({'item': 'EDGE', 'qty': 1});
      await outbox.retryPending(client);

      final calls = verify(
        () => client.callMethod(
          'example.mutate',
          params: captureAny(named: 'params'),
          post: true,
        ),
      ).captured.cast<Map<String, dynamic>>();
      expect(calls, hasLength(2));
      expect(calls[0]['idempotency_key'], 'intent-1');
      expect(calls[1]['idempotency_key'], 'intent-1');
      expect(calls[1]['lines'], [
        {'item': 'PANEL', 'qty': 2},
      ]);
      expect(generatedKeys, 1);
      expect(outbox.snapshot.pendingCount, 0);
    },
  );

  test('an immediate server refusal is terminal and is not queued', () async {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const ValidationFailure('invalid state'));

    await expectLater(execute(), throwsA(isA<ValidationFailure>()));

    expect(outbox.snapshot.isEmpty, isTrue);
  });

  test('a refusal keeps its original intent and remains visible', () async {
    var attempts = 0;
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw const NetworkFailure('offline');
      throw const PermissionFailure('warehouse access denied');
    });

    await expectLater(
      execute(
        params: {
          'document': 'DOC-1',
          'lines': [
            {'item': 'PANEL', 'qty': 2},
          ],
        },
      ),
      throwsA(isA<MutationQueued>()),
    );
    await outbox.retryPending(client);

    expect(outbox.snapshot.pendingCount, 0);
    expect(outbox.snapshot.rejectedCount, 1);
    final rejected = outbox.snapshot.rejected.single;
    expect(rejected.key, 'intent-1');
    expect(rejected.path, 'example.mutate');
    expect(rejected.params, {
      'document': 'DOC-1',
      'lines': [
        {'item': 'PANEL', 'qty': 2},
      ],
    });
    expect(rejected.reason, 'warehouse access denied');
  });

  test(
    'a blocked domain answer after reconnect is terminal and visible',
    () async {
      var attempts = 0;
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: true,
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw const NetworkFailure('offline');
        return {
          'message': {'status': 'blocked', 'message': 'No stock'},
        };
      });

      await expectLater(execute(), throwsA(isA<MutationQueued>()));
      await outbox.retryPending(client);

      expect(outbox.snapshot.pendingCount, 0);
      expect(outbox.snapshot.rejected.single.reason, 'No stock');
    },
  );

  test('a person can dismiss one refusal or all refusals', () async {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));
    await expectLater(execute(), throwsA(isA<MutationQueued>()));
    await expectLater(execute(), throwsA(isA<MutationQueued>()));

    reset(client);
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const ValidationFailure('invalid state'));
    await outbox.retryPending(client);

    expect(outbox.snapshot.rejectedCount, 2);
    await outbox.dismissRejected('intent-1');
    expect(outbox.snapshot.rejected.map((item) => item.key), ['intent-2']);

    await outbox.clearRejected();
    expect(outbox.snapshot.isEmpty, isTrue);
  });

  test('only the twenty most recent refusals remain in memory', () async {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));
    for (var index = 0; index <= MutationOutbox.maxRejected; index++) {
      await expectLater(
        execute(params: {'document': 'DOC-$index'}),
        throwsA(isA<MutationQueued>()),
      );
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

    expect(outbox.snapshot.rejectedCount, MutationOutbox.maxRejected);
    expect(outbox.snapshot.rejected.first.key, 'intent-2');
    expect(outbox.snapshot.rejected.last.key, 'intent-21');
  });

  test('clear drops commands belonging to the old session', () async {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));

    await expectLater(execute(), throwsA(isA<MutationQueued>()));
    await outbox.clear();

    expect(outbox.snapshot.isEmpty, isTrue);
  });

  test('writes the intent before its first network attempt', () async {
    final store = _MemoryOutboxStore();
    const scope = MutationOutboxScope(
      serverUrl: 'https://korkem.example.kz',
      user: 'master@korkem.kz',
    );
    final durable = MutationOutbox(
      keyFactory: () => 'durable-key',
      store: store,
    );
    addTearDown(durable.dispose);
    await durable.activate(scope);
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenAnswer((_) async {
      expect(store.writes, hasLength(1));
      expect(store.writes.single, contains('durable-key'));
      return {
        'message': {'status': 'ok'},
      };
    });

    await durable.execute(
      client,
      'example.mutate',
      params: {'document': 'DOC-1'},
    );

    expect(store.writes, hasLength(2));
  });

  test('restores ordered pending commands with their original keys', () async {
    final store = _MemoryOutboxStore();
    const scope = MutationOutboxScope(
      serverUrl: 'https://korkem.example.kz',
      user: 'master@korkem.kz',
    );
    var keys = 0;
    final first = MutationOutbox(
      keyFactory: () => 'persisted-${++keys}',
      store: store,
    );
    await first.activate(scope);
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));

    await expectLater(
      first.execute(client, 'example.first', params: {'document': 'DOC-1'}),
      throwsA(isA<MutationQueued>()),
    );
    await expectLater(
      first.execute(client, 'example.second', params: {'document': 'DOC-2'}),
      throwsA(isA<MutationQueued>()),
    );
    first.dispose();

    final restored = MutationOutbox(store: store);
    addTearDown(restored.dispose);
    await restored.activate(scope);

    expect(restored.snapshot.pending.map((item) => item.path), [
      'example.first',
      'example.second',
    ]);
    expect(restored.snapshot.pending.map((item) => item.key), [
      'persisted-1',
      'persisted-2',
    ]);
  });

  test('never restores commands for another user or server', () async {
    final store = _MemoryOutboxStore();
    const firstScope = MutationOutboxScope(
      serverUrl: 'https://first.example.kz',
      user: 'master@korkem.kz',
    );
    const otherScope = MutationOutboxScope(
      serverUrl: 'https://first.example.kz',
      user: 'other@korkem.kz',
    );
    final durable = MutationOutbox(
      keyFactory: () => 'first-user-key',
      store: store,
    );
    addTearDown(durable.dispose);
    await durable.activate(firstScope);
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));
    await expectLater(
      durable.execute(client, 'example.mutate', params: {'document': 'DOC-1'}),
      throwsA(isA<MutationQueued>()),
    );

    await durable.activate(otherScope);

    expect(durable.snapshot.isEmpty, isTrue);
    await durable.retryPending(client);
    verify(
      () => client.callMethod(
        'example.mutate',
        params: any(named: 'params'),
        post: true,
      ),
    ).called(1);

    await durable.activate(firstScope);
    expect(durable.snapshot.pending.single.key, 'first-user-key');
  });

  test('restores rejected commands and persists their dismissal', () async {
    final store = _MemoryOutboxStore();
    const scope = MutationOutboxScope(
      serverUrl: 'https://korkem.example.kz',
      user: 'master@korkem.kz',
    );
    final durable = MutationOutbox(
      keyFactory: () => 'rejected-key',
      store: store,
    );
    await durable.activate(scope);
    var attempts = 0;
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw const NetworkFailure('offline');
      throw const ValidationFailure('already closed');
    });
    await expectLater(
      durable.execute(client, 'example.mutate', params: {'document': 'DOC-1'}),
      throwsA(isA<MutationQueued>()),
    );
    await durable.retryPending(client);
    durable.dispose();

    final restored = MutationOutbox(store: store);
    addTearDown(restored.dispose);
    await restored.activate(scope);
    expect(restored.snapshot.rejected.single.reason, 'already closed');

    await restored.dismissRejected('rejected-key');
    final afterDismiss = MutationOutbox(store: store);
    addTearDown(afterDismiss.dispose);
    await afterDismiss.activate(scope);
    expect(afterDismiss.snapshot.isEmpty, isTrue);
  });

  test('storage refusal does not prevent the command', () async {
    final store = _MemoryOutboxStore()..writeError = StateError('no keychain');
    final durable = MutationOutbox(store: store);
    addTearDown(durable.dispose);
    await durable.activate(
      const MutationOutboxScope(
        serverUrl: 'https://korkem.example.kz',
        user: 'master@korkem.kz',
      ),
    );

    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));

    await expectLater(
      durable.execute(client, 'example.mutate', params: {'document': 'DOC-1'}),
      throwsA(isA<MutationQueued>()),
    );

    verify(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).called(1);
    expect(durable.snapshot.pendingCount, 1);
  });

  test('a stuck store is bounded and does not prevent the command', () async {
    final store = _MemoryOutboxStore()..writeCompleter = Completer<void>();
    final durable = MutationOutbox(
      store: store,
      storageTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(durable.dispose);
    await durable.activate(
      const MutationOutboxScope(
        serverUrl: 'https://korkem.example.kz',
        user: 'master@korkem.kz',
      ),
    );
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));

    await expectLater(
      durable.execute(client, 'example.mutate', params: {'document': 'DOC-1'}),
      throwsA(isA<MutationQueued>()),
    );

    verify(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).called(1);
    expect(durable.snapshot.pending.single.params['document'], 'DOC-1');
  });
}
