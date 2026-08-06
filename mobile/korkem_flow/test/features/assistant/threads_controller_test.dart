import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/data/thread_store.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';

/// Renaming and deleting a conversation.
///
/// Both write through to storage and both can touch the conversation that is
/// currently on screen, which is where the interesting failures are: a rename
/// that the open screen does not see, or a delete that comes back on the next
/// save because the screen still held it.
void main() {
  ChatThread thread(String id, {String? name}) => ChatThread(
    id: id,
    name: name,
    updatedAt: DateTime(2026, 7, 28),
    messages: [
      ChatMessage(
        id: '$id-m',
        role: ChatRole.user,
        body: 'Что просрочено?',
        sentAt: DateTime(2026, 7, 28),
      ),
    ],
  );

  ProviderContainer harness(_FakeStore store) {
    final container = ProviderContainer(
      overrides: [threadStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a renamed conversation stops following its first message', () {
    final store = _FakeStore([thread('a')]);
    final container = harness(store);
    final threads = container.read(threadsControllerProvider.notifier);

    expect(
      container.read(threadsControllerProvider).single.title,
      'Что просрочено?',
    );

    threads.rename('a', '  Просрочка по цеху  ');

    expect(
      container.read(threadsControllerProvider).single.title,
      'Просрочка по цеху',
      reason: 'the name is trimmed before it is stored',
    );
    expect(store.written.last.single.name, 'Просрочка по цеху');
  });

  test(
    'an empty name restores the derived title rather than blanking the row',
    () {
      final store = _FakeStore([thread('a', name: 'Old name')]);
      final container = harness(store);

      container.read(threadsControllerProvider.notifier).rename('a', '   ');

      final renamed = container.read(threadsControllerProvider).single;
      expect(renamed.name, isNull);
      expect(renamed.title, 'Что просрочено?');
    },
  );

  test('renaming the open conversation updates what is on screen', () {
    final store = _FakeStore([thread('a')]);
    final container = harness(store);
    container.read(threadsControllerProvider.notifier)
      ..open('a')
      ..rename('a', 'Renamed');

    expect(container.read(activeThreadProvider)?.title, 'Renamed');
  });

  test('delete removes it from the list and from storage', () {
    final store = _FakeStore([thread('a'), thread('b')]);
    final container = harness(store);

    container.read(threadsControllerProvider.notifier).delete('a');

    expect(container.read(threadsControllerProvider).map((t) => t.id), ['b']);
    expect(store.written.last.map((t) => t.id), ['b']);
  });

  test('deleting the open conversation clears the screen', () {
    // Otherwise the next `save` files it straight back and the user watches
    // the thing they deleted reappear.
    final store = _FakeStore([thread('a')]);
    final container = harness(store);
    container.read(threadsControllerProvider.notifier)
      ..open('a')
      ..delete('a');

    expect(container.read(activeThreadProvider), isNull);
  });

  test('deleting one conversation leaves another open', () {
    final store = _FakeStore([thread('a'), thread('b')]);
    final container = harness(store);
    container.read(threadsControllerProvider.notifier)
      ..open('b')
      ..delete('a');

    expect(container.read(activeThreadProvider)?.id, 'b');
  });

  test('deleting something that is not there writes nothing', () {
    final store = _FakeStore([thread('a')]);
    final container = harness(store);

    container.read(threadsControllerProvider.notifier).delete('nope');

    expect(store.written, isEmpty);
  });

  test('a name survives a round trip through storage', () {
    final named = thread('a', name: 'Кухня Иванова');
    expect(ChatThread.fromJson(named.toJson()).name, 'Кухня Иванова');
  });

  test('a thread stored before renaming existed still reads', () {
    // No `name` key at all — the shape every conversation on a user's device
    // has today.
    final legacy = ChatThread.fromJson({
      'id': 'a',
      'updatedAt': DateTime(2026, 7, 28).toIso8601String(),
      'messages': const <Map<String, dynamic>>[],
    });

    expect(legacy.name, isNull);
    expect(legacy.title, isEmpty);
  });
}

class _FakeStore implements ThreadStore {
  _FakeStore(this._initial);

  final List<ChatThread> _initial;
  final written = <List<ChatThread>>[];

  @override
  List<ChatThread> read() => _initial;

  @override
  Future<void> write(List<ChatThread> threads) async => written.add(threads);
}
