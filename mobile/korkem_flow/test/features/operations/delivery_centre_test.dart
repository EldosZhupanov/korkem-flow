import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/operations/data/operations_repository.dart';
import 'package:korkem_flow/features/operations/domain/delivery.dart';
import 'package:korkem_flow/features/operations/presentation/delivery_centre_screen.dart';
import 'package:korkem_flow/features/operations/presentation/work_instructions_screen.dart';

import '../../support/widget_harness.dart';

/// The operator's view of what was sent.
///
/// Two properties matter more than the layout: an administrator can tell a
/// delivered message from one that is still being retried, and the screen
/// offers Retry on exactly the states where retrying is a real answer —
/// never on one that already arrived, because re-sending it is the duplicate
/// the whole delivery model exists to prevent.
void main() {
  NotificationDelivery delivery({
    String status = NotificationDelivery.failed,
    String event = 'production.stopped',
    int attempts = 2,
    String? error = 'Bad Gateway',
  }) => NotificationDelivery(
    name: 'row-1',
    event: event,
    recipient: 'korkem.ivan@example.com',
    status: status,
    channel: 'Telegram',
    attempts: attempts,
    eventKey: 'production.stopped:korkem.ivan@example.com:Work Order:WO-1:',
    body: 'Производство остановлено',
    error: error,
    nextAttemptAt: '2026-08-12 10:00:00',
  );

  Future<void> pump(
    WidgetTester tester,
    List<NotificationDelivery> rows, {
    Map<String, int> summary = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveriesProvider.overrideWith(
            (ref, status) async =>
                DeliveryBoard(deliveries: rows, summary: summary),
          ),
        ],
        child: harness(const DeliveryCentreScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it names the event, the person and the channel', (
    tester,
  ) async {
    await pump(tester, [delivery()]);

    expect(find.text('production.stopped'), findsOneWidget);
    expect(find.textContaining('korkem.ivan@example.com'), findsOneWidget);
    expect(find.textContaining('Telegram'), findsOneWidget);
  });

  testWidgets('a delivered message offers no Retry', (tester) async {
    await pump(tester, [delivery(status: NotificationDelivery.sent)]);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(
      find.text('Retry'),
      findsNothing,
      reason: 're-sending a message that arrived is a duplicate',
    );
  });

  testWidgets('a failed one does', (tester) async {
    await pump(tester, [delivery()]);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a dead letter can be retried, but only by asking', (
    tester,
  ) async {
    await pump(tester, [delivery(status: NotificationDelivery.deadLetter)]);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a suppressed one offers nothing to retry', (tester) async {
    // Nobody to send to is not fixed by trying harder.
    await pump(tester, [delivery(status: NotificationDelivery.suppressed)]);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('the attempts and the last error are shown', (tester) async {
    await pump(tester, [delivery()]);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.textContaining('Attempts: 2'), findsOneWidget);
    expect(find.text('Bad Gateway'), findsOneWidget);
  });

  testWidgets('nothing token-shaped is ever rendered', (tester) async {
    await pump(tester, [delivery(error: 'Unauthorized')]);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    final rendered = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data ?? '')
        .join('\n');
    expect(rendered, isNot(matches(RegExp(r'\d{6,}:[A-Za-z0-9_-]{10,}'))));
    expect(rendered, isNot(contains('Bearer ')));
  });

  testWidgets('an empty board says so', (tester) async {
    await pump(tester, []);

    expect(find.text('Nothing has been sent yet.'), findsOneWidget);
  });

  testWidgets('the filters count what is in each state', (tester) async {
    await pump(
      tester,
      [delivery()],
      summary: {NotificationDelivery.failed: 3},
    );

    expect(find.text('Failed 3'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  group('the dispatch board', () {
    WorkInstructionRow row({
      String status = 'Acknowledged',
      String? response = 'принял',
      int? seconds = 90,
    }) => WorkInstructionRow(
      name: 'wi-1',
      sender: 'korkem.manager@example.com',
      employee: 'korkem.ivan@example.com',
      instruction: 'Закончить раскрой',
      status: status,
      channel: 'Telegram',
      salesOrder: 'SAL-ORD-2026-00011',
      response: response,
      responseSeconds: seconds,
    );

    Future<void> pumpBoard(
      WidgetTester tester,
      List<WorkInstructionRow> rows,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workInstructionsProvider.overrideWith((ref) async => rows),
          ],
          child: harness(const WorkInstructionsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it shows who was asked, what, and what they said', (
      tester,
    ) async {
      await pumpBoard(tester, [row()]);

      expect(find.text('korkem.ivan@example.com'), findsOneWidget);
      expect(find.text('Закончить раскрой'), findsOneWidget);
      expect(find.text('«принял»'), findsOneWidget);
      expect(find.textContaining('Answered in'), findsOneWidget);
    });

    testWidgets('a question is open, and reads differently from silence', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        [row(status: 'Clarification Requested', response: null, seconds: null)],
      );

      expect(find.text('Clarification Requested'), findsOneWidget);
      expect(
        const WorkInstructionRow(
          name: 'x',
          sender: 'a',
          employee: 'b',
          instruction: 'c',
          status: 'Clarification Requested',
        ).isOpen,
        isTrue,
      );
    });

    testWidgets('an empty board says so', (tester) async {
      await pumpBoard(tester, []);

      expect(find.text('Nobody has been given work yet.'), findsOneWidget);
    });
  });
}
