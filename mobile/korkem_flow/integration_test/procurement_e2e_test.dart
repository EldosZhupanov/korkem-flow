import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A production decision, made on a phone.
///
/// Phase 8 proved a write could be confirmed on the device. This asks the
/// harder question: can somebody hold a *conversation* about an order and end
/// it with real material on order — without ever typing an ERPNext document ID?
///
/// The three prompts are deliberately how a shop foreman would speak. The
/// second and third never name the order; if the agent cannot carry
/// `SAL-ORD-2026-00001` from its own earlier answer, the run fails here rather
/// than in a report. History is whatever the app itself accumulated in the
/// thread, so this exercises the real client-side context, not a fixture.
///
/// ```sh
/// flutter test integration_test/procurement_e2e_test.dart -d emulator-5554 \
///   --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
///   --dart-define=KORKEM_E2E_USER=Administrator \
///   --dart-define=KORKEM_E2E_PASSWORD=...
/// ```
///
/// Requires the seeded dataset (`korkem_manufacturing.seed_demo.seed`) and no
/// open Material Request against that order — the tool correctly refuses to
/// order the same material twice, so a leftover request from a previous run
/// makes this fail for the right reason at the wrong moment.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const user = String.fromEnvironment('KORKEM_E2E_USER');
  const password = String.fromEnvironment('KORKEM_E2E_PASSWORD');
  final baseUrl = AppConfig.fromEnvironment().baseUrl;

  const order = 'SAL-ORD-2026-00001';
  const board = 'ДСП 16мм';

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

  /// Material Requests in ERPNext, read through the same `/api/resource` path
  /// the app itself uses.
  ///
  /// Listed by the parent doctype, not by `Material Request Item`. A child
  /// doctype listed without its parent comes back as bare rows — every
  /// requested field `null` — which reads exactly like a document that was
  /// created wrong rather than a query that was written wrong.
  Future<List<Map<String, dynamic>>> requests() => container
      .read(frappeClientProvider)
      .getList(
        'Material Request',
        const FrappeQuery(
          fields: ['name', 'docstatus', 'status', 'material_request_type'],
        ),
      );

  Future<int> requestCount() async => (await requests()).length;

  /// The full document, children included.
  Future<Map<String, dynamic>> requestDoc(String name) async {
    final response = await container
        .read(frappeClientProvider)
        .callMethod(
          'frappe.client.get',
          params: {'doctype': 'Material Request', 'name': name},
        );
    return response['message'] as Map<String, dynamic>;
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
    final composer = find.byType(TextField).last;
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

  testWidgets(
    'a shortage becomes a real purchase request without anyone typing an ID',
    (tester) async {
      await signIn(tester);
      expect(
        await requestCount(),
        0,
        reason:
            'a Material Request already exists for $order — clear it first, '
            'or duplicate protection will (correctly) refuse this run',
      );

      // 1. The order, by customer name. Nothing here is an ID.
      await ask(tester, 'Покажи заказ клиента Мебель Астана.');
      await answersWith(tester, order);

      // 2. "Can it be started?" — no order named. The agent has to carry it.
      await ask(tester, 'Можно его запускать в производство?');
      await answersWith(tester, board);

      // 3. The business action, still without an ID.
      await ask(tester, 'Не хватает материалов. Создай заявку на закупку.');

      // The card appearing means a structured tool call came back, the server
      // refused to run it, wrote a Pending Action, and published
      // needs_confirmation — the entire safety chain, observed from outside.
      //
      // Dragged towards the end of the transcript while waiting: by the third
      // turn the card lands below the fold, and an unbuilt widget is
      // indistinguishable from an absent one.
      final deadline = DateTime.now().add(const Duration(minutes: 4));
      while (find.byType(ConfirmationCard).evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('no ConfirmationCard appeared. Transcript:\n${transcript()}');
        }
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -400));
        }
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(
        find.textContaining('inventory.create_material_request'),
        findsOneWidget,
        reason: 'the card must name the tool it would run',
      );
      expect(
        find.textContaining(order),
        findsWidgets,
        reason: 'the card must show which order is being bought for',
      );
      expect(
        await requestCount(),
        0,
        reason: 'material was ordered before anyone tapped Confirm',
      );

      // The real button, tapped the way a person would — scrolled into view
      // first, and found *inside the card* rather than as "the last
      // FilledButton on screen". A tap that lands slightly off a partially
      // visible button does nothing and reports nothing.
      final confirm = find.descendant(
        of: find.byType(ConfirmationCard),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(confirm);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 500));

      // Dismissal is read from state, not from the widget tree. The transcript
      // is a lazy list: the card scrolling out of view empties the finder just
      // as convincingly as confirming does, and an earlier version of this
      // test passed that way while the proposal sat untouched in the database.
      await pumpUntil(
        tester,
        () => container.read(pendingConfirmationProvider) == null,
        reason: 'the proposal to be resolved after confirming',
      );

      // Observed in ERPNext, not inferred from the screen.
      await pumpWhile(
        tester,
        () async => await requestCount() == 0,
        reason:
            'the Material Request to be created. Transcript:\n${transcript()}',
      );

      final header = (await requests()).single;
      expect(header['docstatus'], 1, reason: 'left as an unsent draft');
      expect(header['material_request_type'], 'Purchase');

      final name = '${header['name']}';
      final lines = (await requestDoc(name))['items']! as List;
      expect(lines, hasLength(1), reason: 'exactly one line, for one shortage');

      final line = lines.single as Map<String, dynamic>;
      expect(line['item_code'], board);
      expect(line['sales_order'], order, reason: 'the request must cite why');
      expect(
        line['qty'],
        4.0,
        reason:
            'the shortage is four sheets — not the 42 required, '
            'nor the 38 in stock',
      );

      // The real document number reaches the device.
      await answersWith(tester, name);

      // Leave the site as it was found. A submitted document has to be
      // cancelled before it can be deleted.
      final client = container.read(frappeClientProvider);
      await client.callMethod(
        'frappe.client.cancel',
        post: true,
        params: {'doctype': 'Material Request', 'name': name},
      );
      await client.callMethod(
        'frappe.client.delete',
        post: true,
        params: {'doctype': 'Material Request', 'name': name},
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
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
