import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/events/data/events_repository.dart';
import 'package:korkem_flow/features/events/domain/proactive_event.dart';
import 'package:korkem_flow/features/events/presentation/widgets/events_feed.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _MockEventsRepository implements EventsRepository {
  _MockEventsRepository({
    this.events = const <ProactiveEvent>[],
    this.onDismiss,
  });

  List<ProactiveEvent> events;
  final void Function(String eventId)? onDismiss;

  @override
  Future<List<ProactiveEvent>> fetchPending() async => events;

  @override
  Future<void> dismiss(String eventId) async {
    onDismiss?.call(eventId);
    events = events.where((e) => e.id != eventId).toList();
  }
}

void main() {
  ProactiveEvent sampleEvent({
    String id = 'evt-1',
    String kind = 'deadline_at_risk',
    EventSeverity severity = EventSeverity.high,
    String title = 'Кухня Ахметова: срок послезавтра, работа не начата',
    String? detail = 'Заказ SAL-ORD-2026-00042, срок 06.09, ни одной операции',
    EventSubject? subject = const EventSubject(
      doctype: 'Sales Order',
      name: 'SAL-ORD-2026-00042',
    ),
    List<EventAction> actions = const [
      EventAction(id: 'start', label: 'Запустить производство'),
    ],
  }) => ProactiveEvent(
    id: id,
    kind: kind,
    severity: severity,
    title: title,
    detail: detail,
    subject: subject,
    actions: actions,
  );

  Widget buildHarness({
    required EventsRepository repository,
    Locale locale = const Locale('ru'),
    List<RouteBase>? additionalRoutes,
    void Function(ProactiveEvent, EventAction)? onAction,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: EventsFeed(onAction: onAction),
            ),
          ),
        ),
        ...?additionalRoutes,
      ],
    );

    return ProviderScope(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  group('Proactive Events (Этап 8)', () {
    testWidgets('1. пусто — это хорошая новость, и она так и читается', (
      tester,
    ) async {
      final repo = _MockEventsRepository();

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      // Clear reassurance: "Всё под контролем", not empty placeholder or error
      expect(find.text('Всё под контролем'), findsOneWidget);
      expect(
        find.text('Завод идёт по плану, срочных событий нет.'),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.success), findsOneWidget);

      // Must not read like broken loading or missing data
      expect(find.text('Нет данных'), findsNothing);
      expect(find.text('Пусто'), findsNothing);
      expect(find.text('Ошибка'), findsNothing);
    });

    testWidgets(
      '2. событие ведёт к делу: тап открывает subject, '
      'кнопка запускает действие',
      (tester) async {
        String? navigatedRoute;
        EventAction? triggeredAction;

        final additionalRoutes = [
          GoRoute(
            path: '/orders/:id',
            builder: (context, state) {
              navigatedRoute = state.uri.toString();
              return const Scaffold(body: Text('Order Details Screen'));
            },
          ),
        ];

        final event = sampleEvent();
        final repo = _MockEventsRepository(events: [event]);

        await tester.pumpWidget(
          buildHarness(
            repository: repo,
            additionalRoutes: additionalRoutes,
            onAction: (e, action) => triggeredAction = action,
          ),
        );
        await tester.pumpAndSettle();

        // Details are rendered
        expect(find.text(event.title), findsOneWidget);
        expect(find.text(event.detail!), findsOneWidget);
        expect(
          find.text('Sales Order: SAL-ORD-2026-00042'),
          findsOneWidget,
        );
        expect(find.text('Запустить производство'), findsOneWidget);

        // Tap the action button -> triggers action directly
        await tester.tap(find.text('Запустить производство'));
        await tester.pumpAndSettle();
        expect(triggeredAction?.id, 'start');
        expect(triggeredAction?.label, 'Запустить производство');

        // Tap the card body -> navigates to subject document route
        await tester.tap(find.text(event.title));
        await tester.pumpAndSettle();
        expect(navigatedRoute, '/orders/SAL-ORD-2026-00042');
      },
    );

    testWidgets(
      '3. «Скрыть» скрывает только это событие и только у этого человека',
      (tester) async {
        String? dismissedId;

        final event1 = sampleEvent(
          title: 'Событие 1: срок послезавтра',
        );
        final event2 = sampleEvent(
          id: 'evt-2',
          title: 'Событие 2: дефицит фурнитуры',
          severity: EventSeverity.medium,
        );

        final repo = _MockEventsRepository(
          events: [event1, event2],
          onDismiss: (id) => dismissedId = id,
        );

        await tester.pumpWidget(buildHarness(repository: repo));
        await tester.pumpAndSettle();

        expect(find.text('Событие 1: срок послезавтра'), findsOneWidget);
        expect(find.text('Событие 2: дефицит фурнитуры'), findsOneWidget);

        // Tap "Скрыть" on the first event
        final dismissButtons = find.text('Скрыть');
        expect(dismissButtons, findsNWidgets(2));
        await tester.tap(dismissButtons.first);
        await tester.pumpAndSettle();

        // Server dismiss was called with evt-1
        expect(dismissedId, 'evt-1');

        // evt-1 is removed from view, evt-2 remains visible
        expect(find.text('Событие 1: срок послезавтра'), findsNothing);
        expect(find.text('Событие 2: дефицит фурнитуры'), findsOneWidget);
        expect(find.text('Событие скрыто'), findsOneWidget);
      },
    );

    testWidgets('важность показывается цветом, иконкой и словом', (
      tester,
    ) async {
      final highEvent = sampleEvent(
        id: 'h-1',
        title: 'Высокая важность',
      );
      final mediumEvent = sampleEvent(
        id: 'm-1',
        title: 'Средняя важность',
        severity: EventSeverity.medium,
      );
      final lowEvent = sampleEvent(
        id: 'l-1',
        title: 'Низкая важность',
        severity: EventSeverity.low,
      );

      final repo = _MockEventsRepository(
        events: [highEvent, mediumEvent, lowEvent],
      );

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      // Words explicitly displayed
      expect(find.text('СРОЧНО'), findsOneWidget);
      expect(find.text('ВНИМАНИЕ'), findsOneWidget);
      expect(find.text('ИНФО'), findsOneWidget);

      // Icons displayed for visual distinction
      expect(find.byIcon(AppIcons.danger), findsOneWidget);
      expect(find.byIcon(AppIcons.warning), findsOneWidget);
      expect(find.byIcon(AppIcons.info), findsOneWidget);
    });

    testWidgets('разбор терпит отсутствующие поля и не падает', (
      tester,
    ) async {
      // Missing detail, subject, and actions
      final raw = <String, dynamic>{
        'id': 'evt-sparse',
        'kind': 'unusual_delay',
        'title': 'Задержка поставки',
      };

      final parsed = ProactiveEvent.fromJson(raw);
      expect(parsed, isNotNull);
      expect(parsed!.id, 'evt-sparse');
      expect(parsed.title, 'Задержка поставки');
      expect(parsed.detail, isNull);
      expect(parsed.subject, isNull);
      expect(parsed.actions, isEmpty);
      expect(parsed.severity, EventSeverity.medium); // Safe fallback

      final repo = _MockEventsRepository(events: [parsed]);
      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Задержка поставки'), findsOneWidget);
      expect(find.text('Скрыть'), findsOneWidget);
    });

    testWidgets('поддержка трёх языков (kk, en, ru)', (tester) async {
      final event = sampleEvent();

      // Kazakh
      await tester.pumpWidget(
        buildHarness(
          repository: _MockEventsRepository(events: [event]),
          locale: const Locale('kk'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ШҰҒЫЛ'), findsOneWidget);
      expect(find.text('Жасыру'), findsOneWidget);

      // English
      await tester.pumpWidget(
        buildHarness(
          repository: _MockEventsRepository(events: [event]),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });
}
