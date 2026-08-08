import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/assistant/data/assistant_channel.dart';
import 'package:korkem_flow/features/assistant/data/assistant_repository.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';

/// The assistant, answered by KORKEM's AI gateway.
///
/// Two halves, and they are deliberately separate. The question goes out over
/// HTTP and returns immediately with a turn id — the server queues the model
/// call rather than holding a worker for the length of somebody's thinking
/// time. The answer comes back on a realtime channel, keyed by that turn id.
///
/// **No provider is named here and no API key exists on the device.** Which
/// model answered is server-side configuration; this class would not change if
/// the operator switched from Claude to a local Ollama. That is the point of
/// the gateway, and `docs/ai_workspace_architecture.md` §2 is why.
class RemoteAssistant extends AssistantRepository {
  const RemoteAssistant({
    required this.client,
    required this.channel,
    this.firstEventTimeout = defaultFirstEventTimeout,
  });

  static const _sendMethod = 'korkem_ai.korkem_ai.chat.send';
  static const _confirmMethod = 'korkem_ai.korkem_ai.chat.confirm';
  static const _rejectMethod = 'korkem_ai.korkem_ai.chat.reject';

  /// How long to wait for the *first* sign of life before giving up.
  ///
  /// The answer arrives on a socket rather than on the HTTP response, so if
  /// that socket is not delivering — wrong namespace, a proxy eating the
  /// upgrade, a network that blocks websockets — the turn has nothing to fail
  /// on and would spin forever. It has been seen doing exactly that on an
  /// emulator. A spinner with no end is worse than an error: it tells the user
  /// nothing and offers them nothing to do.
  ///
  /// Generous, because a queued turn behind a slow model legitimately takes
  /// time, and only the wait *before the first event* is bounded — once deltas
  /// are arriving, the turn runs as long as it needs.
  static const defaultFirstEventTimeout = Duration(seconds: 45);

  /// Overridable so a test does not have to wait three quarters of a minute,
  /// and so a deployment on a slower link can widen it without a code change.
  final Duration firstEventTimeout;

  final FrappeClient client;
  final AssistantChannel channel;

  @override
  Stream<AssistantEvent> send({
    required String prompt,
    required List<ChatMessage> history,
  }) => _run(
    () => client.callMethod(
      _sendMethod,
      post: true,
      params: {'message': prompt, 'history': _history(history)},
    ),
  );

  @override
  Stream<AssistantEvent> confirm({
    required String turnId,
    required List<String> callIds,
    required String prompt,
    required List<ChatMessage> history,
  }) => _run(
    () => client.callMethod(
      _confirmMethod,
      post: true,
      params: {
        'turn_id': turnId,
        'call_ids': callIds,
        'message': prompt,
        'history': _history(history),
      },
    ),
  );

  @override
  Future<void> reject({required List<String> callIds}) async {
    await client.callMethod(
      _rejectMethod,
      post: true,
      params: {'call_ids': callIds},
    );
  }

  /// Subscribes *before* asking.
  ///
  /// The turn is queued the moment the request lands, and a fast one can be
  /// finished before the reply to that request has been parsed. Subscribing
  /// afterwards would lose those turns — which is the kind of race that shows
  /// up only under a fast model or a quiet server, i.e. in production.
  Stream<AssistantEvent> _run(
    Future<Map<String, dynamic>> Function() start,
  ) async* {
    final controller = StreamController<AssistantEvent>();
    StreamSubscription<Map<String, dynamic>>? subscription;
    String? expectedTurn;

    // Events that arrived before the turn id did.
    //
    // Subscribing first is what stops a fast turn being missed, but it opens a
    // window in which we cannot yet tell our events from another turn's — and
    // the room is per *user*, so a second question in flight publishes here
    // too. Holding them until the id is known keeps both properties; letting
    // them through unfiltered would mix two conversations together.
    final pending = <Map<String, dynamic>>[];

    // Fires if nothing at all arrives. Cancelled by the first event, so a turn
    // that is genuinely working is never cut off.
    Timer? silence;
    void giveUp() {
      if (controller.isClosed) return;
      controller.add(const AssistantFailed(AssistantFailure.offline));
      unawaited(controller.close());
    }

    void handle(Map<String, dynamic> payload) {
      silence?.cancel();
      final event = _decode(payload);
      if (event != null) controller.add(event);
      if (_terminal(payload)) unawaited(controller.close());
    }

    try {
      subscription = (await channel.events()).listen(
        (payload) {
          if (expectedTurn == null) {
            pending.add(payload);
            return;
          }
          if (payload['turn_id'] != expectedTurn) return;
          handle(payload);
        },
        onError: (Object error) {
          // Logged, not swallowed. The user still sees only "offline" — a
          // transport error is not something they can act on — but this used
          // to be `onError: (_)`, which discarded the one string that says
          // *why*. Diagnosing the emulator failure needed a temporary patch to
          // this exact line, which is a bad way to learn something the app
          // already knew.
          //
          // Transport-level only: this carries a connection error, never a
          // payload, so there is nothing here to leak.
          debugPrint('Assistant channel failed: $error');
          controller.add(const AssistantFailed(AssistantFailure.offline));
          unawaited(controller.close());
        },
      );

      final response = await start();
      expectedTurn = (response['message'] as Map?)?['turn_id'] as String?;

      // Drain the window now that ours can be told apart.
      for (final payload in pending) {
        if (payload['turn_id'] == expectedTurn) handle(payload);
      }
      pending.clear();

      // Started only once the turn is actually queued — timing the HTTP call
      // as well would punish a slow request for the socket's sins.
      if (!controller.isClosed) {
        silence = Timer(firstEventTimeout, giveUp);
      }

      yield* controller.stream;
    } on FrappeException catch (error) {
      yield AssistantFailed(_failureOf(error));
    } finally {
      silence?.cancel();
      await subscription?.cancel();
      // Not awaited, deliberately. `close()` completes only once the stream has
      // been consumed, so on the path where sending threw before anything
      // listened, awaiting it waits forever — the turn would hang instead of
      // reporting the failure it already has in hand.
      if (!controller.isClosed) unawaited(controller.close());
    }
  }

  static bool _terminal(Map<String, dynamic> payload) =>
      const {'done', 'error', 'needs_confirmation'}.contains(payload['type']);

  static AssistantEvent? _decode(Map<String, dynamic> payload) {
    switch (payload['type']) {
      case 'delta':
        final text = payload['text'] as String?;
        return text == null || text.isEmpty ? null : AssistantDelta(text);

      case 'tool':
        return AssistantToolActivity(
          tool: payload['tool'] as String? ?? '',
          ok: payload['ok'] as bool? ?? false,
        );

      case 'needs_confirmation':
        return AssistantNeedsConfirmation(
          text: payload['text'] as String?,
          // Server-issued ids. Never the model's own — those change on every
          // response from Anthropic and OpenAI, so an approval keyed to one
          // would match nothing when the turn resumed.
          turnId: payload['turn_id'] as String? ?? '',
          calls: [
            for (final raw in (payload['calls'] as List? ?? const []))
              PendingToolCall.fromJson(Map<String, dynamic>.from(raw as Map)),
          ],
        );

      case 'done':
        return AssistantDone(text: payload['text'] as String?);

      case 'error':
        // The server sends a code, not just a sentence. The sentence it also
        // sends is English and is deliberately ignored: only the UI can word
        // this in the user's language, and only the code says which of the
        // several quite different problems this is.
        return AssistantFailed(
          AssistantFailure.fromCode(payload['reason'] as String?),
        );

      // 'started', and anything a newer server adds. Ignored rather than
      // treated as an error: an older client meeting a newer server should
      // degrade quietly, not break.
      default:
        return null;
    }
  }

  /// The failure behind a refused `chat.send`.
  ///
  /// The gateway checks its configuration *before* queuing, so the commonest
  /// problem on a fresh install — no provider yet — arrives here as a code on
  /// the response rather than as a generic error minutes later on the socket.
  /// The code is preferred whenever there is one; the transport-level shapes
  /// below only cover failures that never reached the endpoint at all.
  static AssistantFailure _failureOf(FrappeException error) {
    if (error.code != null) return AssistantFailure.fromCode(error.code);

    return switch (error) {
      NetworkFailure() => AssistantFailure.offline,
      AuthFailure() || PermissionFailure() => AssistantFailure.refused,
      _ => AssistantFailure.unknown,
    };
  }

  /// Only prose, and only recent turns.
  ///
  /// Tool calls and their results are deliberately not sent back: the server
  /// refuses to rebuild them from client input, because a client that could
  /// assert "you already ran this and it returned X" could fabricate the
  /// model's evidence.
  static List<Map<String, String>> _history(List<ChatMessage> history) => [
    for (final message in history)
      if (message.body.trim().isNotEmpty)
        {
          'role': message.role == ChatRole.user ? 'user' : 'assistant',
          'text': message.body,
        },
  ];
}
