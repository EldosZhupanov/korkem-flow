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

/// Phase 26 — stopping a job, and putting it back to work.
///
/// A shop needs this more often than it would like: a customer postpones, a
/// board is the wrong colour, a machine goes down. Until now a job could only
/// go forwards, so a halted order kept asking for material in the shortage
/// report and kept a slot in the capacity queue for as long as it existed.
///
/// The assertion that matters is the reservation. `Work Order.stop_unstop`
/// calls `update_planned_qty`, and board a stopped job is sitting on is board
/// another order cannot use — so it is read from `Bin` before and after.
///
/// Three routed calls with three different phrasings, because Phase 25 showed
/// that a tool working when called directly proves nothing about what the model
/// sends it.
///
/// Leaves the job running. Safe to re-run.
///
/// ```sh
/// flutter test integration_test/stop_production_e2e_test.dart \
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

  const order = 'SAL-ORD-2026-00002';

  Future<Map<String, dynamic>> job() async => (await client().getList(
    'Work Order',
    const FrappeQuery(
      fields: ['name', 'qty', 'produced_qty', 'status'],
      filters: [FrappeFilter.equals('sales_order', order)],
    ),
  )).single;

  /// What the job is holding in the store, straight from ERPNext.
  Future<double> reserved() async {
    final rows = await client().getList(
      'Bin',
      const FrappeQuery(
        fields: ['reserved_qty_for_production'],
        filters: [
          FrappeFilter.equals('warehouse', 'Stores - KRK'),
          FrappeFilter('item_code', 'in', ['ЛДСП 18мм', 'Ручка']),
        ],
      ),
    );
    return rows.fold<double>(
      0,
      (sum, row) =>
          sum + ((row['reserved_qty_for_production'] as num?)?.toDouble() ?? 0),
    );
  }

  testWidgets(
    'a planner halts a job, its material is freed, and it goes back to work',
    (tester) async {
      await signIn(tester);

      final before = await job();
      expect(before['status'], 'In Process', reason: 'run seed_demo first');
      final heldBefore = await reserved();
      expect(
        heldBefore,
        greaterThan(0),
        reason: 'the seeded job reserves no material',
      );

      // 1. Halt it. A reason a foreman would actually give.
      await ask(
        tester,
        'Останови производство по заказу Караганда Мебель — '
        'клиент перенёс сроки.',
      );
      await confirmCard(tester, 'manufacturing.stop_production');
      await pumpWhile(
        tester,
        () async => (await job())['status'] != 'Stopped',
        reason: 'the job to stop. Transcript:\n${transcript()}',
      );

      expect(
        await reserved(),
        0.0,
        reason: 'a stopped job is still holding material other orders need',
      );
      expect(
        (await job())['produced_qty'],
        before['produced_qty'],
        reason: 'stopping unmade something',
      );

      // 2. Back to work — a different word for it.
      await ask(tester, 'Возобнови производство по этому заказу.');
      await confirmCard(tester, 'manufacturing.stop_production');
      await pumpWhile(
        tester,
        () async => (await job())['status'] == 'Stopped',
        reason: 'the job to resume. Transcript:\n${transcript()}',
      );

      expect((await job())['status'], 'In Process');
      expect(
        await reserved(),
        heldBefore,
        reason: 'resuming did not take the material back',
      );

      // 3. A third phrasing, to show the routing is not one memorised sentence.
      await ask(tester, 'Приостанови этот заказ, станок сломался.');
      await confirmCard(tester, 'manufacturing.stop_production');
      await pumpWhile(
        tester,
        () async => (await job())['status'] != 'Stopped',
        reason: 'the second halt. Transcript:\n${transcript()}',
      );
      expect(await reserved(), 0.0);

      // Leave the factory as it was found.
      await ask(tester, 'Верни его в работу.');
      await confirmCard(tester, 'manufacturing.stop_production');
      await pumpWhile(
        tester,
        () async => (await job())['status'] == 'Stopped',
        reason: 'the job to resume. Transcript:\n${transcript()}',
      );
      expect(await reserved(), heldBefore);
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
