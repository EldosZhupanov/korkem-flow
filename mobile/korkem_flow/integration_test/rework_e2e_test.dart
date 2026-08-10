import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 24 — a spoiled piece that gets fixed.
///
/// One of five fails at the saw. It is *held* rather than written off — booked
/// as the card's pending quantity, because process loss on a submitted card
/// cannot be taken back and nobody has decided yet. ERPNext's corrective job
/// card records the rework itself, and the piece returns to good output on the
/// card that lost it.
///
/// The assertion that matters: five started, one reworked, and the operation
/// ends at five good with no loss.
///
/// Leaves the order part-produced. Re-run
/// `seed_demo.remove(); seed_demo.seed()` before running it again.
///
/// ```sh
/// flutter test integration_test/rework_e2e_test.dart \
///   -d emulator-5554 --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
///   --dart-define=KORKEM_E2E_USER=korkem.planner@example.com \
///   --dart-define=KORKEM_E2E_PASSWORD=...
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const user = String.fromEnvironment('KORKEM_E2E_USER');
  const password = String.fromEnvironment('KORKEM_E2E_PASSWORD');
  final baseUrl = AppConfig.fromEnvironment().baseUrl;

  late ProviderContainer container;

  /// Pumps until [condition] holds, or gives up.
  ///
  /// `pumpAndSettle` is unusable here: the app is talking to a live socket and
  /// a live model, so it legitimately never settles.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(minutes: 3),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('timed out waiting for ${reason ?? 'condition'}');
  }

  /// Like [pumpUntil], but the condition does I/O — waiting on the database
  /// rather than on the widget tree.
  Future<void> pumpWhile(
    WidgetTester tester,
    Future<bool> Function() keepWaiting, {
    Duration timeout = const Duration(minutes: 3),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await keepWaiting()) return;
      await tester.pump(const Duration(milliseconds: 500));
    }
    fail('timed out waiting for ${reason ?? 'condition'}');
  }

  Future<void> signIn(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // Only the credential *cache* is substituted, and only because a
        // headless session has no keyring.
        credentialStoreProvider.overrideWithValue(_MemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KorkemFlowApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final fields = find.byType(TextFormField);
    await pumpUntil(
      tester,
      () => fields.evaluate().length >= 3,
      reason: 'the login form',
    );

    await tester.enterText(fields.at(0), baseUrl);
    await tester.enterText(fields.at(1), user);
    await tester.enterText(fields.at(2), password);
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pump(const Duration(seconds: 1));

    // The signal that sign-in finished is the login *form* going away —
    // `TextFormField` builds a `TextField`, so waiting on the latter is
    // satisfied by the login screen itself.
    await pumpUntil(
      tester,
      () => find.byType(TextFormField).evaluate().isEmpty,
      reason: 'sign-in to complete (login form to disappear)',
    );
    await pumpUntil(
      tester,
      () => find.byType(TextField).evaluate().isNotEmpty,
      reason: 'the assistant composer',
    );
  }

  Future<void> ask(WidgetTester tester, String prompt) async {
    // The composer does not accept input while a turn is running, and
    // `answersWith` below returns as soon as the expected fragment has
    // *streamed* — several seconds before the turn ends. Typing then is
    // silently dropped, and the next assertion fails describing a model that
    // never answered a question it was never asked.
    await pumpUntil(
      tester,
      () => !container.read(assistantBusyProvider),
      reason: 'the assistant to finish the previous turn',
      timeout: const Duration(minutes: 4),
    );

    // Tapped before typing. After the first send the composer clears itself
    // and re-requests focus, which leaves the test's input connection stale:
    // `enterText` then reports success and the controller stays empty, so the
    // send button never leaves its idle state and the turn is simply lost.
    // Scrolled back into view before it is tapped. After confirming, the
    // transcript is long and the drag that found the card left the composer
    // off screen — a tap there lands on nothing and the text never arrives,
    // which surfaces one step later as "the send button never appeared".
    final composer = find.byType(TextField).last;
    await tester.ensureVisible(composer);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(composer);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(composer, prompt);
    await tester.pump();

    // The send button, not `receiveAction`. The composer declares
    // `TextInputAction.newline` — messages are multi-line — so submitting
    // through the keyboard action depends on an input connection that is gone
    // by the second turn, and the text is silently dropped. Tapping the button
    // is both more reliable and what a person actually does.
    final appears = DateTime.now().add(const Duration(minutes: 1));
    while (find.byKey(const ValueKey('send')).evaluate().isEmpty) {
      if (DateTime.now().isAfter(appears)) {
        fail(
          'the send button never appeared. '
          'busy=${container.read(assistantBusyProvider)} '
          'textFields=${find.byType(TextField).evaluate().length} '
          'idleSlot=${find.byKey(const ValueKey('idle')).evaluate().length} '
          'busySlot=${find.byKey(const ValueKey('busy')).evaluate().length}',
        );
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    // The button cross-fades in through a `ScaleTransition`, so it exists in
    // the tree while it is still scaled to nothing. Tapping it then lands on
    // empty space and does nothing at all — no error, no message.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The transcript the app itself is holding.
  ///
  /// Read from the thread rather than from the widget tree, and the reason is
  /// worth recording: the transcript is a lazy list, so only the messages
  /// currently on screen are built. Once the conversation is a few turns long
  /// the earlier answers are real, correct, and completely invisible to
  /// `find.textContaining` — which failed this test twice while the app was
  /// behaving perfectly. What is rendered still matters and is still asserted,
  /// but for the *confirmation card*, which is what a person has to see and
  /// touch. Answer content is state.
  String transcript() => (container.read(activeThreadProvider)?.messages ?? [])
      .map((message) => '${message.role}: ${message.body}')
      .join('\n');

  /// Waits for the card, checks it names the tool, taps Confirm.
  Future<void> confirmCard(WidgetTester tester, String tool) async {
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (find.byType(ConfirmationCard).evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('no ConfirmationCard for $tool. Transcript:\n${transcript()}');
      }
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -400));
      }
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(
      find.textContaining(tool),
      findsOneWidget,
      reason: 'the card must name the tool it would run',
    );

    final confirm = find.descendant(
      of: find.byType(ConfirmationCard),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(confirm);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 500));

    await pumpUntil(
      tester,
      () => container.read(pendingConfirmationProvider) == null,
      reason: 'the proposal to be resolved after confirming',
    );
  }

  FrappeClient client() => container.read(frappeClientProvider);

  const order = 'SAL-ORD-2026-00003';

  Future<Map<String, dynamic>?> job() async {
    final rows = await client().getList(
      'Work Order',
      const FrappeQuery(
        fields: ['name', 'qty', 'produced_qty', 'process_loss_qty', 'status'],
        filters: [FrappeFilter.equals('sales_order', order)],
      ),
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> card(String workOrder, String operation) async {
    final rows = await client().getList(
      'Job Card',
      FrappeQuery(
        fields: const [
          'name',
          'for_quantity',
          'total_completed_qty',
          'process_loss_qty',
          'pending_qty',
          'status',
          'docstatus',
        ],
        filters: [
          FrappeFilter.equals('work_order', workOrder),
          FrappeFilter.equals('operation', operation),
          const FrappeFilter.equals('is_corrective_job_card', 0),
        ],
      ),
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> corrective(String workOrder) =>
      client().getList(
        'Job Card',
        FrappeQuery(
          fields: const [
            'name',
            'operation',
            'for_operation',
            'for_job_card',
            'for_quantity',
            'docstatus',
          ],
          filters: [
            FrappeFilter.equals('work_order', workOrder),
            const FrappeFilter.equals('is_corrective_job_card', 1),
          ],
        ),
      );

  /// Read through the parent. A child table cannot be listed directly however
  /// the user's rights on the Work Order stand — Frappe answers "Insufficient
  /// Permission for Work Order Operation" — so it is asked for the way the
  /// permission model expects rather than by widening anything.
  Future<Map<String, dynamic>> operationRow(String workOrder) async {
    final doc = await client().getDoc('Work Order', workOrder);
    return (doc['operations'] as List).cast<Map<String, dynamic>>().firstWhere(
      (row) => row['operation'] == 'Раскрой',
    );
  }

  testWidgets(
    'a planner sends one piece for rework and gets it back as good output',
    (tester) async {
      await signIn(tester);

      await ask(tester, 'Запусти производство по заказу Павлодар Уют.');
      await confirmCard(tester, 'manufacturing.start_production');
      await pumpWhile(
        tester,
        () async => (await job())?['status'] != 'In Process',
        reason: 'the job to start. Transcript:\n${transcript()}',
      );
      final workOrder = (await job())!['name'] as String;

      // 1. Four good; one is damaged but can be saved.
      await ask(
        tester,
        'Раскрой: 4 штуки годные, 1 штука в браке — отправь её на исправление.',
      );
      await confirmCard(tester, 'manufacturing.complete_operation');
      await pumpWhile(
        tester,
        () async => (await corrective(workOrder)).isEmpty,
        reason: 'the rework card. Transcript:\n${transcript()}',
      );

      final held = (await card(workOrder, 'Раскрой'))!;
      expect((held['total_completed_qty'] as num).toDouble(), 4.0);
      expect(
        (held['process_loss_qty'] as num).toDouble(),
        0.0,
        reason: 'a piece on its way to be fixed was written off as scrap',
      );
      expect((held['pending_qty'] as num).toDouble(), 1.0);
      expect(
        held['docstatus'],
        0,
        reason: 'the stage closed on an open rework',
      );

      final fix = (await corrective(workOrder)).single;
      expect(fix['operation'], 'Исправление брака');
      expect(fix['for_operation'], 'Раскрой');
      expect(fix['for_job_card'], held['name']);
      expect((fix['for_quantity'] as num).toDouble(), 1.0);

      // 2. It was saved.
      await ask(tester, 'Исправление завершено, деталь починили.');
      await confirmCard(tester, 'manufacturing.complete_rework');
      await pumpWhile(
        tester,
        () async =>
            ((await card(workOrder, 'Раскрой'))?['total_completed_qty'] as num?)
                ?.toDouble() !=
            5.0,
        reason: 'the piece to come back. Transcript:\n${transcript()}',
      );

      final closed = (await card(workOrder, 'Раскрой'))!;
      expect((closed['total_completed_qty'] as num).toDouble(), 5.0);
      expect((closed['process_loss_qty'] as num).toDouble(), 0.0);
      expect(closed['docstatus'], 1, reason: 'the stage did not close');

      final row = await operationRow(workOrder);
      expect((row['completed_qty'] as num).toDouble(), 5.0);
      expect((row['process_loss_qty'] as num).toDouble(), 0.0);
      expect(row['status'], 'Completed');

      // 3. The rework itself is recorded and submitted, and adds no quantity.
      expect((await corrective(workOrder)).single['docstatus'], 1);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

class _MemoryStore implements CredentialStore {
  AuthCredentials? _credentials;
  String? _serverUrl;

  @override
  Future<AuthCredentials?> read() async => _credentials;

  @override
  Future<void> write(AuthCredentials credentials) async =>
      _credentials = credentials;

  @override
  Future<String?> readServerUrl() async => _serverUrl;

  @override
  Future<void> writeServerUrl(String url) async => _serverUrl = url;

  @override
  Future<void> clear() async {
    _credentials = null;
    _serverUrl = null;
  }
}
