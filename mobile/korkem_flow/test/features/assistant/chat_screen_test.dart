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
import 'package:korkem_flow/features/assistant/presentation/chat_history.dart';
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

  // История живёт только в боковой панели оболочки (07.11.2026). Экран
  // чата на широком окне раньше рисовал свой второй список рядом с ней —
  // те же чаты дважды. Переключение и «Новый чат» проверяются тестами
  // боковой панели.
  testWidgets('wide screen renders one column without its own history list', (
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

    // The active conversation is shown once, as the conversation.
    expect(find.text('Покажи мои сделки'), findsOneWidget);
    expect(find.text('Вот сделки'), findsOneWidget);
    // Nothing on this screen lists the other thread or starts a new one.
    expect(find.text('Что в производстве?'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'New chat'), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets('wide screen with no threads shows the welcome view only', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(1200, 800));

    expect(find.byType(ChatEmptyView), findsOneWidget);
    expect(find.text('No conversations yet'), findsNothing);
  });

  // История — под кнопкой экрана чата (владелец, 11.11.2026): в боковой
  // панели она выталкивала разделы вниз. Пустое «привет» в ней не видно.
  testWidgets('the history opens from the chat, without lone greetings', (
    tester,
  ) async {
    final deals = sampleThread(
      't1',
      prompt: 'Покажи мои сделки',
      reply: 'Вот сделки',
      updatedAt: now,
    );
    final overdue = sampleThread(
      't2',
      prompt: 'Что просрочено?',
      reply: 'Ничего',
      updatedAt: now.subtract(const Duration(days: 3)),
    );
    final hello = sampleThread(
      't3',
      prompt: 'привет!',
      reply: 'Здравствуйте',
      updatedAt: now,
    );

    await pumpScreen(
      tester,
      threads: [deals, overdue, hello],
      activeThread: deals,
      size: const Size(1200, 800),
    );
    expect(find.text('Что просрочено?'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat:history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chatThread:t2')), findsOneWidget);
    expect(find.byKey(const ValueKey('chatThread:t1')), findsOneWidget);
    expect(find.byKey(const ValueKey('chatThread:t3')), findsNothing);

    // A conversation picked there is the one on screen.
    await tester.tap(find.byKey(const ValueKey('chatThread:t2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chatThread:t2')), findsNothing);
    expect(find.text('Ничего'), findsOneWidget);
  });

  test('a lone greeting is small talk; a question or a named one is not', () {
    final t = sampleThread(
      'x',
      prompt: 'Привет',
      reply: 'Здравствуйте',
      updatedAt: now,
    );
    expect(isSmallTalk(t), isTrue);
    expect(
      isSmallTalk(
        sampleThread(
          'y',
          prompt: 'привет, что с заказом 12?',
          reply: '…',
          updatedAt: now,
        ),
      ),
      isFalse,
    );
    expect(
      isSmallTalk(
        sampleThread(
          'z',
          prompt: 'привет',
          reply: '…',
          updatedAt: now,
          name: 'Важное',
        ),
      ),
      isFalse,
    );
  });
}
