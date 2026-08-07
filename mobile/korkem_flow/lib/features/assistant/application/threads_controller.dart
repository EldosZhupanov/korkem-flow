import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/assistant/data/assistant_channel.dart';
import 'package:korkem_flow/features/assistant/data/assistant_repository.dart';
import 'package:korkem_flow/features/assistant/data/local_assistant.dart';
import 'package:korkem_flow/features/assistant/data/remote_assistant.dart';
import 'package:korkem_flow/features/assistant/data/thread_store.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';

final threadStoreProvider = Provider<ThreadStore>(
  (ref) => ThreadStore(ref.watch(sharedPreferencesProvider)),
);

/// What the gateway says about itself: which site to open a channel on, and
/// which event the answers arrive as.
///
/// Asked rather than derived. Frappe's socket.io requires the namespace to
/// equal the *site* name, and the host the app dials is not always that — an
/// emulator reaches the bench at `10.0.2.2` while the site is
/// `korkem.localhost`, so guessing from the base URL connects to a namespace
/// that does not exist and is refused with no useful error on the device.
/// Found exactly that way, on a device.
final assistantInfoProvider = FutureProvider<AssistantInfo?>((ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session?.credentials == null) return null;

  final response = await ref
      .watch(frappeClientProvider)
      .callMethod('korkem_ai.korkem_ai.chat.info');
  final message = response['message'] as Map?;
  if (message == null) return null;

  return AssistantInfo(
    site: message['site'] as String? ?? '',
    event: message['event'] as String? ?? FrappeSocketChannel.defaultEvent,
  );
});

/// The socket the assistant's answers arrive on.
///
/// Null until there is a signed-in session to authenticate it with — the
/// middleware accepts the same API key pair the REST client uses, so there is
/// no second login, but there is also nothing to connect with before one.
final assistantChannelProvider = Provider<AssistantChannel?>((ref) {
  final session = ref.watch(sessionProvider).value;
  final credentials = session?.credentials;
  final info = ref.watch(assistantInfoProvider).value;
  if (session == null || credentials == null || info == null) return null;
  if (info.site.isEmpty) return null;

  final channel = FrappeSocketChannel(
    baseUrl: session.serverUrl,
    siteName: info.site,
    credentials: credentials,
    event: info.event,
  );
  ref.onDispose(() => unawaited(channel.dispose()));
  return channel;
});

/// The assistant behind the chat.
///
/// The gateway when there is a session to reach it with, the local keyword
/// matcher otherwise. Both are honest about what they are: the remote one
/// reports that no provider is configured rather than improvising, and the
/// local one attaches a data card and writes no prose at all.
///
/// Which *model* answers is not decided here and cannot be — it is server-side
/// configuration, which is the whole reason no API key exists on the device.
final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  final channel = ref.watch(assistantChannelProvider);
  if (channel == null) return const LocalAssistant();

  return RemoteAssistant(
    client: ref.watch(frappeClientProvider),
    channel: channel,
  );
});

/// Past conversations, newest first.
final threadsControllerProvider =
    NotifierProvider<ThreadsController, List<ChatThread>>(
      ThreadsController.new,
    );

/// The conversation on screen, or null for a fresh one nobody has spoken in.
final activeThreadProvider = NotifierProvider<ActiveThread, ChatThread?>(
  ActiveThread.new,
);

/// True while a reply is being prepared.
final assistantBusyProvider = NotifierProvider<AssistantBusy, bool>(
  AssistantBusy.new,
);

/// The tool the assistant is running right now, if any.
///
/// Held apart from the transcript on purpose: what the assistant did while
/// thinking is worth showing *live* and not worth keeping in a conversation
/// somebody reopens next week.
final assistantActivityProvider = NotifierProvider<AssistantActivity, String?>(
  AssistantActivity.new,
);

class AssistantActivity extends Notifier<String?> {
  @override
  String? build() => null;

  /// A method, not a setter, for the same reason `ActiveThread.replace` is:
  /// a notifier's mutation surface reads as a list of events, and
  /// `running(tool)` is an event where `running = tool` would read as state
  /// the caller owns.
  // ignore: use_setters_to_change_properties
  void running(String tool) => state = tool;

  void idle() => state = null;
}

class ThreadsController extends Notifier<List<ChatThread>> {
  @override
  List<ChatThread> build() => ref.watch(threadStoreProvider).read();

  /// Files a conversation, replacing any earlier version of it.
  void save(ChatThread thread) {
    if (thread.isEmpty) return;

    final next = [
      thread,
      ...state.where((existing) => existing.id != thread.id),
    ];
    state = next;
    unawaited(ref.read(threadStoreProvider).write(next));
  }

  /// Clears the screen without discarding what is already filed.
  void startNew() => ref.read(activeThreadProvider.notifier).clear();

  void open(String id) {
    final thread = state.where((t) => t.id == id).firstOrNull;
    if (thread != null) {
      ref.read(activeThreadProvider.notifier).replace(thread);
    }
  }

  /// Gives a conversation a name of the user's choosing.
  ///
  /// An empty name clears it rather than storing a blank, so the row goes back
  /// to following the opening question instead of rendering as an empty line.
  void rename(String id, String name) {
    final trimmed = name.trim();
    _replaceWhere(
      id,
      (thread) => ChatThread(
        id: thread.id,
        messages: thread.messages,
        updatedAt: thread.updatedAt,
        name: trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  /// Forgets a conversation. If it is the one on screen, the screen is cleared
  /// too — leaving a deleted conversation open is how a user deletes something
  /// and then watches it come back on the next save.
  void delete(String id) {
    final next = state.where((thread) => thread.id != id).toList();
    if (next.length == state.length) return;

    state = next;
    if (ref.read(activeThreadProvider)?.id == id) {
      ref.read(activeThreadProvider.notifier).clear();
    }
    unawaited(ref.read(threadStoreProvider).write(next));
  }

  void _replaceWhere(String id, ChatThread Function(ChatThread) update) {
    final index = state.indexWhere((thread) => thread.id == id);
    if (index < 0) return;

    final updated = update(state[index]);
    final next = [...state]..[index] = updated;
    state = next;
    if (ref.read(activeThreadProvider)?.id == id) {
      ref.read(activeThreadProvider.notifier).replace(updated);
    }
    unawaited(ref.read(threadStoreProvider).write(next));
  }
}

class ActiveThread extends Notifier<ChatThread?> {
  @override
  ChatThread? build() => null;

  void clear() => state = null;

  /// Puts a filed conversation back on screen.
  ///
  /// A method rather than the setter the linter suggests: a notifier's mutation
  /// surface is a list of events, and `replace(thread)` reads as one where
  /// `thread = x` would read as state the caller owns.
  // ignore: use_setters_to_change_properties
  void replace(ChatThread thread) => state = thread;

  /// Rewrites the last message in place, for a reply that is still arriving.
  void replaceMessage(ChatMessage message) {
    final thread = state;
    if (thread == null) return;

    final index = thread.messages.indexWhere((m) => m.id == message.id);
    if (index < 0) return append(message);

    final messages = [...thread.messages]..[index] = message;
    state = thread.copyWith(messages: messages);
  }

  void append(ChatMessage message) {
    final now = ref.read(clockProvider)();
    final current = state;

    state = current == null
        ? ChatThread(
            // The moment it started, which is unique per conversation and
            // sorts correctly without pulling in a UUID package for something
            // that never leaves the device.
            id: now.microsecondsSinceEpoch.toString(),
            messages: [message],
            updatedAt: now,
          )
        : current.copyWith(
            messages: [...current.messages, message],
            updatedAt: now,
          );
  }
}

class AssistantBusy extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;
  void finish() => state = false;
}

/// Sends what the user typed and files the exchange.
///
/// Lives here rather than in the widget so the screen holds no logic worth
/// testing, and so a real assistant changes one provider override.
Future<void> sendMessage(WidgetRef ref, String text) async {
  final prompt = text.trim();
  if (prompt.isEmpty) return;

  final now = ref.read(clockProvider);

  ref
      .read(activeThreadProvider.notifier)
      .append(
        ChatMessage(
          id: now().microsecondsSinceEpoch.toString(),
          role: ChatRole.user,
          body: prompt,
          sentAt: now(),
        ),
      );

  final active = ref.read(activeThreadProvider.notifier);
  ref.read(assistantBusyProvider.notifier).start();

  // Settle which assistant is answering *before* asking it.
  //
  // The channel needs the site name, which comes from the server, so on a cold
  // start the info is still in flight when the first message is sent — and a
  // synchronous read then finds no channel and quietly falls back to the local
  // matcher. The result was that the first question of every session was
  // answered by the wrong assistant, which is invisible until you compare two
  // answers. A failure here is not fatal: falling back is then the correct
  // outcome rather than an accident.
  try {
    await ref.read(assistantInfoProvider.future);
  } on Object {
    // Unreachable server: the local assistant is the honest fallback.
  }

  final replyId = '${now().microsecondsSinceEpoch}-reply';
  final buffer = StringBuffer();
  ContextCardKind? card;
  AssistantFailure? failure;
  var placed = false;

  /// Puts the reply on screen the first time there is anything to show, and
  /// rewrites it in place after that — so a streamed answer grows rather than
  /// arriving as a series of separate messages.
  void publish() {
    final message = ChatMessage(
      id: replyId,
      role: ChatRole.assistant,
      body: buffer.toString(),
      sentAt: now(),
      card: card,
      // Carried on the message so a reopened conversation still shows the
      // admission rather than an empty bubble where an answer looked like it
      // used to be.
      unrecognised: buffer.isEmpty && card == null && failure == null,
      failure: failure,
    );
    if (placed) {
      active.replaceMessage(message);
    } else {
      active.append(message);
      placed = true;
    }
  }

  try {
    final events = ref
        .read(assistantRepositoryProvider)
        .send(
          prompt: prompt,
          history: ref.read(activeThreadProvider)?.messages ?? const [],
        );

    await for (final event in events) {
      switch (event) {
        case AssistantDelta(:final text):
          buffer.write(text);
          publish();
        case AssistantDone(text: final finalText, card: final finalCard):
          // The complete answer replaces the accumulated fragments rather than
          // appending to them: a client that missed a delta still ends up with
          // the whole thing, and one that missed none sees no difference.
          if (finalText != null && finalText.isNotEmpty) {
            buffer
              ..clear()
              ..write(finalText);
          }
          card = finalCard;
        case AssistantFailed(:final reason):
          failure = reason;
        case AssistantToolActivity(:final tool):
          // Live only: the screen words it, and it is not kept in a transcript
          // someone reopens next week.
          ref.read(assistantActivityProvider.notifier).running(tool);
        // Confirmation needs a dialog and there are no write tools yet, so
        // there is nothing that can currently produce this.
        case AssistantNeedsConfirmation():
          break;
      }
    }

    publish();
  } finally {
    ref.read(assistantBusyProvider.notifier).finish();
    ref.read(assistantActivityProvider.notifier).idle();
    final thread = ref.read(activeThreadProvider);
    if (thread != null) {
      ref.read(threadsControllerProvider.notifier).save(thread);
    }
  }
}
