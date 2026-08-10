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

/// Phase 22 — the numbers are the ledger's, not a fixture's.
///
/// Until this phase the Мебель Астана order claimed six finished cabinets that
/// no stock entry had ever posted: `produced_qty` was written straight onto the
/// work order and the units were put on the shelf by a Material Receipt
/// labelled "opening stock". Both are gone. The six are now built by a real
/// Material Transfer for Manufacture followed by a real Manufacture entry, and
/// every answer below has to come out the same as before — because the physical
/// truth never changed, only whether the system was telling it.
///
/// The four questions are the ones ШАГ 8 of the brief asks a user to be able to
/// ask. The shipment at the end proves the six are real goods and not a number.
///
/// Leaves the order part-delivered. Re-run
/// `seed_demo.remove(); seed_demo.seed()` before running it again.
///
/// ```sh
/// flutter test integration_test/ledger_truth_e2e_test.dart -d emulator-5554 \
///   --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
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

  /// Waits for the assistant to say something it could only have learned from
  /// a tool result.
  Future<void> answersWith(WidgetTester tester, String fragment) async {
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (DateTime.now().isBefore(deadline)) {
      if (transcript().contains(fragment)) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('never answered with "$fragment". Transcript:\n${transcript()}');
  }

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

  /// Finished cabinets on the shelf, straight from ERPNext.
  Future<double> onShelf() async {
    final rows = await client().getList(
      'Bin',
      const FrappeQuery(
        fields: ['actual_qty'],
        filters: [
          FrappeFilter.equals('item_code', 'Шкаф Астана'),
          FrappeFilter.equals('warehouse', 'Finished Goods - KRK'),
        ],
      ),
    );
    return rows.isEmpty ? 0 : (rows.single['actual_qty'] as num).toDouble();
  }

  Future<Map<String, dynamic>> job() async => (await client().getList(
    'Work Order',
    const FrappeQuery(
      fields: ['name', 'qty', 'produced_qty', 'status'],
      filters: [FrappeFilter.equals('sales_order', 'SAL-ORD-2026-00001')],
    ),
  )).single;

  /// What ERPNext's own definition of `produced_qty` sums to: the finished-item
  /// rows of every submitted Manufacture entry against the job.
  Future<double> manufacturedQty(String workOrder) async {
    final entries = await client().getList(
      'Stock Entry',
      FrappeQuery(
        filters: [
          FrappeFilter.equals('work_order', workOrder),
          const FrappeFilter.equals('purpose', 'Manufacture'),
          const FrappeFilter.equals('docstatus', 1),
        ],
      ),
    );
    var total = 0.0;
    for (final entry in entries) {
      // Read through the parent document. A child table cannot be listed
      // directly — Frappe answers "Insufficient Permission for Stock Entry
      // Detail" whatever the user's rights on Stock Entry are — and the fix is
      // to ask the way the permission model expects, not to widen it.
      final doc = await client().getDoc('Stock Entry', entry['name'] as String);
      for (final row in (doc['items'] as List).cast<Map<String, dynamic>>()) {
        if ((row['is_finished_item'] as num?)?.toInt() == 1) {
          total += (row['transfer_qty'] as num).toDouble();
        }
      }
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> notes() => client().getList(
    'Delivery Note',
    const FrappeQuery(
      fields: ['name', 'customer', 'docstatus', 'owner', 'company'],
    ),
  );

  testWidgets(
    'the factory answers from its own ledger, and ships what it built',
    (tester) async {
      await signIn(tester);

      // The precondition is itself the phase's claim: six cabinets exist
      // because six were manufactured, and the two numbers are the same fact.
      final planned = await job();
      final workOrder = planned['name'] as String;
      expect(
        (planned['produced_qty'] as num).toDouble(),
        6.0,
        reason: 'expected six built — run seed_demo',
      );
      expect(
        await manufacturedQty(workOrder),
        6.0,
        reason:
            'produced_qty is not backed by Manufacture entries — the fixture '
            'fiction is back',
      );
      expect(await onShelf(), 6.0);
      expect(await notes(), isEmpty, reason: 'clear delivery notes first');

      // 1. How much is done. A db_set used to answer this.
      await ask(tester, 'Сколько уже произведено по заказу Мебель Астана?');
      await answersWith(tester, '6');

      // 2. How much is left.
      await ask(tester, 'Сколько осталось произвести по этому заказу?');
      await answersWith(tester, '4');

      // 3. What blocks the rest. The shortage formula was corrected this
      // phase; producing six for real used to turn this answer into 29.2.
      await ask(tester, 'Чего не хватает, чтобы доделать заказ?');
      await answersWith(tester, '4');

      // 4. The six that exist go out — real goods, really made.
      await ask(tester, 'Отгрузи то, что готово.');
      await confirmCard(tester, 'sales.create_delivery');

      await pumpWhile(
        tester,
        () async => (await notes()).isEmpty,
        reason: 'the delivery note. Transcript:\n${transcript()}',
      );

      final note = (await notes()).single;
      expect(note['docstatus'], 1, reason: 'left as an unsubmitted draft');
      expect(note['customer'], 'Мебель Астана');
      expect(note['company'], 'KORKEM');
      expect(
        note['owner'],
        user,
        reason: 'the note must carry the real user, not a service account',
      );
      expect(
        await onShelf(),
        0.0,
        reason: 'the six built cabinets did not leave the shelf',
      );

      // 5. And the job still says six were made — delivery moves stock, not
      // production history.
      expect((await job())['produced_qty'], 6.0);
      expect(await manufacturedQty(workOrder), 6.0);
    },
    timeout: const Timeout(Duration(minutes: 15)),
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
