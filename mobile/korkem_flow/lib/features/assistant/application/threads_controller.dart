import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/assistant/data/assistant_repository.dart';
import 'package:korkem_flow/features/assistant/data/local_assistant.dart';
import 'package:korkem_flow/features/assistant/data/thread_store.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';

final threadStoreProvider = Provider<ThreadStore>(
  (ref) => ThreadStore(ref.watch(sharedPreferencesProvider)),
);

/// The assistant behind the chat.
///
/// Overridden wholesale to connect a real model later; overridden in tests to
/// make replies deterministic. The default is the local one, which writes no
/// prose and invents no numbers.
final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => const LocalAssistant(),
);

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
  try {
    final reply = await ref
        .read(assistantRepositoryProvider)
        .reply(
          prompt: prompt,
          history: ref.read(activeThreadProvider)?.messages ?? const [],
        );

    active.append(
      ChatMessage(
        id: '${now().microsecondsSinceEpoch}-reply',
        role: ChatRole.assistant,
        body: reply.body ?? '',
        sentAt: now(),
        card: reply.card,
        // Carried on the message so a reopened conversation still shows the
        // admission rather than an empty bubble where an answer looked like it
        // used to be.
        unrecognised: reply.isUnrecognised,
      ),
    );
  } finally {
    ref.read(assistantBusyProvider.notifier).finish();
    final thread = ref.read(activeThreadProvider);
    if (thread != null) {
      ref.read(threadsControllerProvider.notifier).save(thread);
    }
  }
}
