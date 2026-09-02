import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/data/assistant_repository.dart';
import 'package:korkem_flow/features/assistant/data/thread_store.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';
import 'package:korkem_flow/features/assistant/presentation/chat_screen.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_empty_view.dart';

import '../../support/widget_harness.dart';

class _FakeStore implements ThreadStore {
  _FakeStore([this._threads = const []]);

  List<ChatThread> _threads;

  @override
  List<ChatThread> read() => _threads;

  @override
  Future<void> write(List<ChatThread> threads) async {
    _threads = threads;
  }
}

class _FakeAssistant extends AssistantRepository {
  const _FakeAssistant();

  @override
  Stream<AssistantEvent> send({
    required String prompt,
    required List<ChatMessage> history,
  }) => const Stream.empty();
}

void main() {
  final now = DateTime(2026, 9, 2, 14);

  ChatThread sampleThread(
    String id, {
    required String prompt,
    required String reply,
    required DateTime updatedAt,
    String? name,
  }) => ChatThread(
    id: id,
    name: name,
    updatedAt: updatedAt,
    messages: [
      ChatMessage(
        id: '$id-1',
        role: ChatRole.user,
        body: prompt,
        sentAt: updatedAt,
      ),
      ChatMessage(
        id: '$id-2',
        role: ChatRole.assistant,
        body: reply,
        sentAt: updatedAt,
      ),
    ],
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ChatThread> threads = const [],
    ChatThread? activeThread,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final store = _FakeStore(threads);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          threadStoreProvider.overrideWithValue(store),
          assistantInfoProvider.overrideWith((ref) async => null),
          assistantRepositoryProvider.overrideWithValue(const _FakeAssistant()),
        ],
        child: harness(const ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    if (activeThread != null) {
      final element = tester.element(find.byType(ChatScreen));
      final container = ProviderScope.containerOf(element);
      container.read(activeThreadProvider.notifier).replace(activeThread);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('compact screen renders single conversation column', (
    tester,
  ) async {
    final thread1 = sampleThread(
      't1',
      prompt: 'Покажи мои сделки',
      reply: 'Вот сделки',
      updatedAt: now,
    );

    await pumpScreen(tester, threads: [thread1], activeThread: thread1);

    expect(find.text('Покажи мои сделки'), findsOneWidget);
    expect(find.text('Вот сделки'), findsOneWidget);
    // Left pane with "New chat" button is absent on compact screen
    expect(find.widgetWithText(FilledButton, 'New chat'), findsNothing);
  });

  testWidgets('wide screen displays two-pane master-detail layout', (
    tester,
  ) async {
    final thread1 = sampleThread(
      't1',
      prompt: 'Покажи мои сделки',
      reply: 'Вот сделки',
      updatedAt: now,
    );
    final thread2 = sampleThread(
      't2',
      prompt: 'Что в производстве?',
      reply: 'В производстве 3 заказа',
      updatedAt: now.subtract(const Duration(days: 3)),
    );

    await pumpScreen(
      tester,
      threads: [thread1, thread2],
      activeThread: thread1,
      size: const Size(1200, 800),
    );

    // Master list has both threads
    expect(find.text('Покажи мои сделки'), findsWidgets);
    expect(find.text('Что в производстве?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New chat'), findsOneWidget);

    // Detail pane shows active thread message
    expect(find.text('Вот сделки'), findsOneWidget);
  });

  testWidgets('wide screen displays empty state when no threads exist', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      size: const Size(1200, 800),
    );

    expect(find.text('No conversations yet'), findsOneWidget);
    expect(
      find.text('Your conversations with the assistant will appear here.'),
      findsOneWidget,
    );
    expect(find.byType(ChatEmptyView), findsOneWidget);
  });

  testWidgets('wide screen switches active thread on tap', (tester) async {
    final thread1 = sampleThread(
      't1',
      prompt: 'Покажи мои сделки',
      reply: 'Вот сделки',
      updatedAt: now,
    );
    final thread2 = sampleThread(
      't2',
      prompt: 'Что в производстве?',
      reply: 'В производстве 3 заказа',
      updatedAt: now.subtract(const Duration(days: 3)),
    );

    await pumpScreen(
      tester,
      threads: [thread1, thread2],
      activeThread: thread1,
      size: const Size(1200, 800),
    );

    expect(find.text('Вот сделки'), findsOneWidget);
    expect(find.text('В производстве 3 заказа'), findsNothing);

    await tester.tap(find.text('Что в производстве?'));
    await tester.pumpAndSettle();

    expect(find.text('В производстве 3 заказа'), findsOneWidget);
  });

  testWidgets('wide screen New Chat button resets active thread', (
    tester,
  ) async {
    final thread1 = sampleThread(
      't1',
      prompt: 'Покажи мои сделки',
      reply: 'Вот сделки',
      updatedAt: now,
    );

    await pumpScreen(
      tester,
      threads: [thread1],
      activeThread: thread1,
      size: const Size(1200, 800),
    );

    expect(find.text('Вот сделки'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'New chat'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatEmptyView), findsOneWidget);
  });
}
