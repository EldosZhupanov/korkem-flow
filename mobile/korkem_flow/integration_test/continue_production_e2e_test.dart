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

/// Phase 22 — finishing a job that was already half done.
///
/// Making the fixture honest made a real gap reachable: a job whose first batch
/// has been built and consumed needs its next batch of material moved into
/// work-in-progress, and `start_production` used to answer "already running"
/// and move nothing. The outstanding units then could not be manufactured —
/// ERPNext refused for want of material in WIP, and nothing could put it there.
///
/// The Караганда order is genuinely in that state and needs no purchasing:
/// twenty ordered, five built, five units' worth transferred, and plenty of
/// panel on the shelf. So this run is the gap closing, end to end — top up,
/// build the rest, ship the lot.
///
/// Leaves the order complete and delivered. Re-run
/// `seed_demo.remove(); seed_demo.seed()` before running it again.
///
/// ```sh
/// flutter test integration_test/continue_production_e2e_test.dart \
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

  const order = 'SAL-ORD-2026-00002';

  Future<Map<String, dynamic>> job() async => (await client().getList(
    'Work Order',
    const FrappeQuery(
      fields: [
        'name',
        'qty',
        'produced_qty',
        'material_transferred_for_manufacturing',
        'status',
      ],
      filters: [FrappeFilter.equals('sales_order', order)],
    ),
  )).single;

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

  Future<List<Map<String, dynamic>>> notes() => client().getList(
    'Delivery Note',
    const FrappeQuery(fields: ['name', 'customer', 'docstatus', 'owner']),
  );

  Future<double> delivered() async =>
      ((await client().getDoc('Sales Order', order))['per_delivered'] as num)
          .toDouble();

  testWidgets(
    'a planner feeds a half-built job and finishes the order',
    (tester) async {
      await signIn(tester);

      // The precondition is the state that used to be unreachable: part built,
      // and short of material for the rest.
      final before = await job();
      final total = (before['qty'] as num).toDouble();
      final built = (before['produced_qty'] as num).toDouble();
      final moved = (before['material_transferred_for_manufacturing'] as num)
          .toDouble();
      expect(before['status'], 'In Process');
      expect(built, 5.0, reason: 'expected five built — run seed_demo');
      expect(moved, lessThan(total), reason: 'material is already all across');
      expect(await notes(), isEmpty, reason: 'clear delivery notes first');
      final shelfBefore = await onShelf();

      // 1. How much is done — read from the ledger, as Phase 22 requires.
      await ask(tester, 'Сколько произведено по заказу Караганда Мебель?');
      await answersWith(tester, '5');

      // 2. Feed the rest of the job. This is the call that used to answer
      // "производство уже идёт" and move nothing.
      await ask(
        tester,
        'Подай материал на оставшиеся изделия по заказу Караганда Мебель.',
      );
      await confirmCard(tester, 'manufacturing.start_production');

      await pumpWhile(
        tester,
        () async =>
            ((await job())['material_transferred_for_manufacturing'] as num)
                .toDouble() ==
            moved,
        reason: 'the material to reach WIP. Transcript:\n${transcript()}',
      );
      expect(
        ((await job())['material_transferred_for_manufacturing'] as num)
            .toDouble(),
        total,
        reason: 'every unit of the job should now have its material',
      );
      expect(
        ((await job())['produced_qty'] as num).toDouble(),
        built,
        reason: 'a transfer is not production',
      );

      // 3. Build the rest — impossible before this phase.
      await ask(
        tester,
        'Производство по заказу Караганда Мебель закончено, '
        'выпусти готовую продукцию.',
      );
      await confirmCard(tester, 'manufacturing.complete_production');

      await pumpWhile(
        tester,
        () async => ((await job())['produced_qty'] as num).toDouble() == built,
        reason: 'the rest to be released. Transcript:\n${transcript()}',
      );
      final done = await job();
      expect((done['produced_qty'] as num).toDouble(), total);
      expect(done['status'], 'Completed');
      expect(
        await onShelf(),
        shelfBefore + (total - built),
        reason: 'the units built did not reach the shelf',
      );

      // 4. And the whole order goes out.
      await ask(tester, 'Отгрузи заказ Караганда Мебель.');
      await confirmCard(tester, 'sales.create_delivery');

      await pumpWhile(
        tester,
        () async => (await notes()).isEmpty,
        reason: 'the delivery note. Transcript:\n${transcript()}',
      );
      final note = (await notes()).single;
      expect(note['docstatus'], 1);
      expect(note['customer'], 'Караганда Мебель');
      expect(
        note['owner'],
        user,
        reason: 'the note must carry the real user, not a service account',
      );
      expect(await onShelf(), shelfBefore - built);
      expect(await delivered(), 100.0, reason: 'the order is not fully out');
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
