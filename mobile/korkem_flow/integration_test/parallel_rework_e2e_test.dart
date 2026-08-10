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

/// Phase 25 — one damaged piece must not stop the other four.
///
/// Holding a piece by leaving its card open stopped the line: an unsubmitted
/// job card contributes nothing to `Work Order Operation.completed_qty`, which
/// is what ERPNext's sequence check reads, so four finished pieces looked like
/// none. The stage is split instead — the good pieces go out on a card that
/// submits, the held one waits on a card that does not.
///
/// This run proves the whole shape: four move on while one waits, a first
/// repair fails, the piece is written off, and the shelf gets four — not five.
///
/// Leaves the order part-produced. Re-run
/// `seed_demo.remove(); seed_demo.seed()` before running it again.
///
/// ```sh
/// flutter test integration_test/parallel_rework_e2e_test.dart \
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

  Future<List<Map<String, dynamic>>> cards(
    String workOrder,
    String operation,
  ) => client().getList(
    'Job Card',
    FrappeQuery(
      fields: const [
        'name',
        'for_quantity',
        'total_completed_qty',
        'process_loss_qty',
        'docstatus',
      ],
      filters: [
        FrappeFilter.equals('work_order', workOrder),
        FrappeFilter.equals('operation', operation),
        const FrappeFilter.equals('is_corrective_job_card', 0),
      ],
      orderBy: 'creation asc',
    ),
  );

  Future<Map<String, dynamic>> operationRow(
    String workOrder,
    String operation,
  ) async {
    final doc = await client().getDoc('Work Order', workOrder);
    return (doc['operations'] as List).cast<Map<String, dynamic>>().firstWhere(
      (row) => row['operation'] == operation,
    );
  }

  Future<double> onShelf() async {
    final rows = await client().getList(
      'Bin',
      const FrappeQuery(
        fields: ['actual_qty'],
        filters: [
          FrappeFilter.equals('item_code', 'Тумба Караганда'),
          FrappeFilter.equals('warehouse', 'Finished Goods - KRK'),
        ],
      ),
    );
    return rows.isEmpty ? 0 : (rows.single['actual_qty'] as num).toDouble();
  }

  testWidgets(
    'four good pieces keep moving while one waits at the rework bench',
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
      final shelfBefore = await onShelf();

      // 1. Four good, one damaged and sent to be fixed.
      await ask(
        tester,
        'Раскрой: сделали 5, одна штука в браке — отправь её на исправление.',
      );
      await confirmCard(tester, 'manufacturing.complete_operation');
      await pumpWhile(
        tester,
        () async => (await cards(workOrder, 'Раскрой')).length < 2,
        reason: 'the stage to split. Transcript:\n${transcript()}',
      );

      final split = await cards(workOrder, 'Раскрой');
      final good = split.firstWhere((c) => c['docstatus'] == 1);
      final held = split.firstWhere((c) => c['docstatus'] == 0);
      expect((good['for_quantity'] as num).toDouble(), 4.0);
      expect((good['total_completed_qty'] as num).toDouble(), 4.0);
      expect((held['for_quantity'] as num).toDouble(), 1.0);
      expect(
        (await operationRow(workOrder, 'Раскрой'))['completed_qty'],
        4.0,
        reason: 'the stage did not report its good pieces to the work order',
      );

      // 2. The four move on — the point of the whole phase.
      await ask(tester, 'Кромление закончено.');
      await confirmCard(tester, 'manufacturing.complete_operation');
      await pumpWhile(
        tester,
        () async =>
            ((await operationRow(workOrder, 'Кромление'))['completed_qty']
                    as num)
                .toDouble() !=
            4.0,
        reason: 'the four to move on. Transcript:\n${transcript()}',
      );
      expect(
        (await operationRow(workOrder, 'Кромление'))['process_loss_qty'],
        0.0,
        reason: 'a piece at the bench was written off downstream',
      );

      // 3. The repair fails, and the piece is written off.
      await ask(tester, 'Исправление не удалось.');
      await confirmCard(tester, 'manufacturing.complete_rework');
      await pumpWhile(
        tester,
        () async => (await cards(workOrder, 'Раскрой')).length < 2,
        reason: 'the verdict. Transcript:\n${transcript()}',
      );
      expect(
        (await cards(workOrder, 'Раскрой')).where((c) => c['docstatus'] == 0),
        isNotEmpty,
        reason: 'a failed repair wrote the piece off instead of holding it',
      );

      await ask(tester, 'Списать эту деталь в брак.');
      await confirmCard(tester, 'manufacturing.complete_rework');
      await pumpWhile(
        tester,
        () async => (await cards(workOrder, 'Раскрой')).length > 1,
        timeout: const Duration(minutes: 6),
        reason: 'the write-off. Transcript:\n${transcript()}',
      );

      // 4. The rest of the routing, then release. Four were built.
      for (final operation in const [
        'ЧПУ обработка',
        'Сверление',
        'Покраска',
        'Сборка',
      ]) {
        await ask(tester, 'Операция $operation закончена.');
        await confirmCard(tester, 'manufacturing.complete_operation');
        await pumpWhile(
          tester,
          () async =>
              ((await operationRow(workOrder, operation))['completed_qty']
                      as num)
                  .toDouble() !=
              4.0,
          reason: '$operation. Transcript:\n${transcript()}',
        );
      }

      await ask(tester, 'ОТК принял.');
      await confirmCard(tester, 'manufacturing.record_inspection');
      await ask(tester, 'ОТК закончен.');
      await confirmCard(tester, 'manufacturing.complete_operation');
      await ask(tester, 'Производство закончено, выпусти готовую продукцию.');
      await confirmCard(tester, 'manufacturing.complete_production');
      await pumpWhile(
        tester,
        () async => ((await job())?['produced_qty'] as num?)?.toDouble() == 0,
        reason: 'the release. Transcript:\n${transcript()}',
      );

      final done = (await job())!;
      expect(
        (done['produced_qty'] as num).toDouble(),
        4.0,
        reason: 'the written-off piece reached the shelf',
      );
      expect((done['process_loss_qty'] as num).toDouble(), 1.0);
      expect(await onShelf(), shelfBefore + 4.0);
    },
    timeout: const Timeout(Duration(minutes: 25)),
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
