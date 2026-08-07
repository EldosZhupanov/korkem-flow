import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/assistant/data/assistant_channel.dart';
import 'package:korkem_flow/features/assistant/data/remote_assistant.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';

/// What the client makes of what the gateway publishes.
///
/// The socket is faked. These are about decoding and stream lifecycle — the
/// transport itself was verified against the running bench by hand, and a test
/// with a real socket in it would be testing the bench.
void main() {
  ChatMessage message(ChatRole role, String body) => ChatMessage(
    id: '$role-$body',
    role: role,
    body: body,
    sentAt: DateTime(2026, 8, 6),
  );

  test('deltas arrive in order and the turn ends on done', () async {
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(
      client: _client(turnId: 't1'),
      channel: channel,
    );

    final events = assistant.send(prompt: 'hi', history: const []).toList();
    await channel.ready;

    channel
      ..emit({'turn_id': 't1', 'type': 'started'})
      ..emit({'turn_id': 't1', 'type': 'delta', 'text': 'Noth'})
      ..emit({'turn_id': 't1', 'type': 'delta', 'text': 'ing.'})
      ..emit({'turn_id': 't1', 'type': 'done', 'text': 'Nothing.'});

    expect(
      (await events).map((e) => e.runtimeType.toString()),
      // 'started' is ignored rather than surfaced: it is not something the
      // user needs told.
      ['AssistantDelta', 'AssistantDelta', 'AssistantDone'],
    );
  });

  test('events for another turn are ignored', () async {
    // Two questions in flight on one socket is not hypothetical: the channel is
    // shared, and a slow first turn can still be running when a second starts.
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(
      client: _client(turnId: 't1'),
      channel: channel,
    );

    final events = assistant.send(prompt: 'hi', history: const []).toList();
    await channel.ready;

    channel
      ..emit({'turn_id': 'SOMEONE-ELSE', 'type': 'delta', 'text': 'not mine'})
      ..emit({'turn_id': 't1', 'type': 'delta', 'text': 'mine'})
      ..emit({'turn_id': 't1', 'type': 'done'});

    final texts = (await events).whereType<AssistantDelta>().map((e) => e.text);
    expect(texts, ['mine']);
  });

  test('tool activity is surfaced so the screen can show it', () async {
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(
      client: _client(turnId: 't1'),
      channel: channel,
    );

    final events = assistant.send(prompt: 'deals?', history: const []).toList();
    await channel.ready;

    channel
      ..emit({
        'turn_id': 't1',
        'type': 'tool',
        'tool': 'crm.search_deals',
        'ok': true,
      })
      ..emit({'turn_id': 't1', 'type': 'done', 'text': '12 deals.'});

    final activity = (await events).whereType<AssistantToolActivity>().single;
    expect(activity.tool, 'crm.search_deals');
    expect(activity.ok, isTrue);
  });

  test(
    'a pause for confirmation ends the turn with the pending calls',
    () async {
      final channel = _FakeChannel();
      final assistant = RemoteAssistant(
        client: _client(turnId: 't1'),
        channel: channel,
      );

      final events = assistant
          .send(prompt: 'do it', history: const [])
          .toList();
      await channel.ready;

      channel.emit({
        'turn_id': 't1',
        'type': 'needs_confirmation',
        'text': 'I can create that task.',
        'calls': [
          {
            'id': 'w1',
            'tool': 'tasks.create',
            'arguments': {'title': 'Call Ivanov'},
          },
        ],
      });

      final pause = (await events)
          .whereType<AssistantNeedsConfirmation>()
          .single;
      expect(pause.calls.single.id, 'w1');
      expect(pause.calls.single.arguments['title'], 'Call Ivanov');
    },
  );

  test('an unknown event type is ignored, not treated as a failure', () async {
    // An older client meeting a newer server should degrade quietly.
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(
      client: _client(turnId: 't1'),
      channel: channel,
    );

    final events = assistant.send(prompt: 'hi', history: const []).toList();
    await channel.ready;

    channel
      ..emit({'turn_id': 't1', 'type': 'something_new', 'payload': 42})
      ..emit({'turn_id': 't1', 'type': 'done', 'text': 'ok'});

    expect((await events).whereType<AssistantFailed>(), isEmpty);
  });

  test('a server error ends the turn', () async {
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(
      client: _client(turnId: 't1'),
      channel: channel,
    );

    final events = assistant.send(prompt: 'hi', history: const []).toList();
    await channel.ready;

    channel.emit({'turn_id': 't1', 'type': 'error', 'message': 'nope'});

    expect((await events).single, isA<AssistantFailed>());
  });

  test('the reason on an error event decides what the screen says', () async {
    // Every one of these sends the user somewhere different: an administrator,
    // a retry in a minute, or nowhere. Collapsing them into one "something went
    // wrong" is what this mapping exists to prevent.
    const expected = {
      'AI_NOT_CONFIGURED': AssistantFailure.notConfigured,
      'PROVIDER_UNAVAILABLE': AssistantFailure.providerUnavailable,
      'AUTH_ERROR': AssistantFailure.refused,
      'RATE_LIMITED': AssistantFailure.rateLimited,
      'TOOL_ERROR': AssistantFailure.toolError,
      'UNKNOWN': AssistantFailure.unknown,
      // A code from a newer server an older client has never heard of.
      'SOMETHING_NEW': AssistantFailure.unknown,
    };

    for (final MapEntry(key: code, value: reason) in expected.entries) {
      final channel = _FakeChannel();
      final assistant = RemoteAssistant(
        client: _client(turnId: 't1'),
        channel: channel,
      );

      final events = assistant.send(prompt: 'hi', history: const []).toList();
      await channel.ready;
      channel.emit({'turn_id': 't1', 'type': 'error', 'reason': code});

      expect(
        ((await events).single as AssistantFailed).reason,
        reason,
        reason: 'code $code',
      );
    }
  });

  test('an unconfigured gateway is refused before the queue', () async {
    // The failure that matters most, because it is the state of every fresh
    // install. It used to arrive seconds later on the socket as a generic
    // error; the gateway now checks its configuration before enqueuing, so it
    // comes back on the HTTP response with a code.
    final assistant = RemoteAssistant(
      client: _failingClient(
        FrappeException.fromDio(
          DioException(
            requestOptions: RequestOptions(),
            response: Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(),
              statusCode: 417,
              // The shape a live bench actually returns — verified by curl
              // against the running site, not invented for this test.
              data: const {
                'ai_error_code': 'AI_NOT_CONFIGURED',
                'exc_type': 'AINotConfigured',
              },
            ),
          ),
        ),
      ),
      channel: _FakeChannel(),
    );

    final events = await assistant
        .send(prompt: 'hi', history: const [])
        .toList();

    expect(
      (events.single as AssistantFailed).reason,
      AssistantFailure.notConfigured,
    );
  });

  test('a validation error with no code is not read as unconfigured', () async {
    // The old mapping assumed every 417 meant "no provider". Any other
    // rejected request would then have told the user to call an administrator
    // about a setting that was perfectly fine.
    final assistant = RemoteAssistant(
      client: _failingClient(const ValidationFailure('Message is empty')),
      channel: _FakeChannel(),
    );

    final events = await assistant
        .send(prompt: 'hi', history: const [])
        .toList();

    expect(
      (events.single as AssistantFailed).reason,
      AssistantFailure.unknown,
    );
  });

  test('a confirmation carries the turn it belongs to', () async {
    // Without it the screen cannot resume the turn the user just approved.
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(
      client: _client(turnId: 't7'),
      channel: channel,
    );

    final events = assistant.send(prompt: 'do it', history: const []).toList();
    await channel.ready;
    channel.emit({
      'turn_id': 't7',
      'type': 'needs_confirmation',
      'calls': [
        {
          'id': 'PA-xyz',
          'tool': 'tasks.create',
          'arguments': <String, Object>{},
        },
      ],
    });

    final pause = (await events).whereType<AssistantNeedsConfirmation>().single;
    expect(pause.turnId, 't7');
    expect(pause.calls.single.id, 'PA-xyz');
  });

  test('a refused request is reported as a reason, not a raw error', () async {
    // Which reason decides what the screen advises — "ask an administrator" is
    // right for an unconfigured gateway and wrong for a dropped connection.
    final assistant = RemoteAssistant(
      client: _failingClient(
        FrappeException.fromDio(
          DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
      channel: _FakeChannel(),
    );

    final events = await assistant
        .send(prompt: 'hi', history: const [])
        .toList();

    expect(
      (events.single as AssistantFailed).reason,
      AssistantFailure.offline,
    );
  });

  test(
    'a socket that never delivers ends the turn instead of hanging',
    () async {
      // Seen on a device: the gateway queued the turn and published its answer,
      // the socket delivered nothing, and the app span forever. A spinner with
      // no end tells the user nothing and offers them nothing to do.
      final assistant = RemoteAssistant(
        client: _client(turnId: 't1'),
        channel: _FakeChannel(),
        firstEventTimeout: const Duration(milliseconds: 60),
      );

      final events = await assistant
          .send(prompt: 'hi', history: const [])
          .toList();

      expect(
        (events.single as AssistantFailed).reason,
        AssistantFailure.offline,
      );
    },
  );

  test('the timeout does not fire once events are arriving', () async {
    // A long answer streaming in for minutes is a working turn, not a stuck
    // one — only the wait before the *first* event is bounded.
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(
      client: _client(turnId: 't1'),
      channel: channel,
      firstEventTimeout: const Duration(milliseconds: 60),
    );

    final events = assistant.send(prompt: 'hi', history: const []).toList();
    await channel.ready;
    channel.emit({'turn_id': 't1', 'type': 'delta', 'text': 'thinking'});

    // Well past the timeout: it was disarmed by that first delta.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    channel.emit({'turn_id': 't1', 'type': 'done', 'text': 'Done.'});

    final kinds = (await events).map((e) => e.runtimeType.toString());
    expect(kinds, ['AssistantDelta', 'AssistantDone']);
  });

  test('only prose is sent back as history', () async {
    // The server refuses to rebuild tool results from client input, so sending
    // them would be pointless — and being able to would let a client fabricate
    // the model's evidence.
    final client = _RecordingClient(turnId: 't1');
    final channel = _FakeChannel();
    final assistant = RemoteAssistant(client: client, channel: channel);

    final events = assistant
        .send(
          prompt: 'and then?',
          history: [
            message(ChatRole.user, 'what is overdue?'),
            message(ChatRole.assistant, '3 tasks.'),
            message(ChatRole.assistant, '   '),
          ],
        )
        .toList();
    await channel.ready;
    channel.emit({'turn_id': 't1', 'type': 'done'});
    await events;

    final sent = client.lastParams!['history'] as List;
    expect(sent, hasLength(2), reason: 'the blank message is dropped');
    expect(sent.first, {'role': 'user', 'text': 'what is overdue?'});
    expect(sent.last, {'role': 'assistant', 'text': '3 tasks.'});
  });
}

FrappeClient _client({required String turnId}) =>
    _RecordingClient(turnId: turnId);

FrappeClient _failingClient(Exception error) => _ThrowingClient(error);

/// A client that answers `chat.send` with a turn id and remembers the call.
class _RecordingClient implements FrappeClient {
  _RecordingClient({required this.turnId});

  final String turnId;
  Map<String, dynamic>? lastParams;

  @override
  Future<Map<String, dynamic>> callMethod(
    String path, {
    Map<String, dynamic>? params,
    bool post = false,
  }) async {
    lastParams = params;
    return {
      'message': {'turn_id': turnId, 'event': 'korkem_ai_chat'},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingClient implements FrappeClient {
  _ThrowingClient(this.error);

  final Exception error;

  @override
  Future<Map<String, dynamic>> callMethod(
    String path, {
    Map<String, dynamic>? params,
    bool post = false,
  }) async => throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A socket that never touches a network.
class _FakeChannel implements AssistantChannel {
  _FakeChannel() {
    // Completed from `onListen`, not from `events()`. A broadcast controller
    // *drops* events published while nobody is listening, and completing on
    // the call would let a test emit into that gap — every assertion would
    // then fail on timing rather than on behaviour. This cost an afternoon
    // once; it is worth the four lines.
    _controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        if (!_subscribed.isCompleted) _subscribed.complete();
      },
    );
  }

  late final StreamController<Map<String, dynamic>> _controller;
  final _subscribed = Completer<void>();

  /// Resolves once the repository is actually listening.
  Future<void> get ready => _subscribed.future;

  void emit(Map<String, dynamic> payload) => _controller.add(payload);

  @override
  Future<Stream<Map<String, dynamic>>> events() async => _controller.stream;

  @override
  Future<void> dispose() async => _controller.close();
}
