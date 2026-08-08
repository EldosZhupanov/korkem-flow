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

/// Ordering from a supplier, on a phone.
///
/// The chain used to stop at "заявка создана". This carries it to a real
/// Purchase Order and then reads back what is on order and when it lands.
///
/// Setup is one submitted Material Request, created before the run — it is the
/// fixture, not the thing under test, and raising it through the assistant
/// would spend a second confirmation proving what Phase 13 already proved:
///
/// ```sh
/// bench --site korkem.localhost execute korkem_manufacturing.seed_demo.seed
/// # then, as the planner, raise one request for the board
/// flutter test integration_test/procurement_e2e_test_po.dart -d emulator-5554 \
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

  /// Purchase orders in ERPNext, read the way the app reads everything.
  Future<List<Map<String, dynamic>>> purchaseOrders() => container
      .read(frappeClientProvider)
      .getList(
        'Purchase Order',
        const FrappeQuery(
          fields: [
            'name',
            'supplier',
            'status',
            'docstatus',
            'owner',
            'grand_total',
          ],
        ),
      );

  Future<int> orderCount() async => (await purchaseOrders()).length;

  testWidgets(
    'a planner orders the missing board from the supplier and sees it on order',
    (tester) async {
      await signIn(tester);
      expect(
        await orderCount(),
        0,
        reason: 'a Purchase Order already exists — clear it before this run',
      );

      // 1. What has been asked for but not yet bought.
      await ask(tester, 'Покажи заявки на закупку, которые ещё не заказаны.');
      await answersWith(tester, 'MAT-MR');

      // 2. Order it. No supplier, price or quantity named by anyone.
      await ask(tester, 'Создай заказ поставщику по этой заявке.');

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
        find.textContaining('procurement.create_purchase_order'),
        findsOneWidget,
        reason: 'the card must name the tool it would run',
      );
      expect(
        await orderCount(),
        0,
        reason: 'an order was placed before anyone tapped Confirm',
      );

      final proposal = container.read(pendingConfirmationProvider);
      expect(
        proposal,
        isNotNull,
        reason: 'the proposal vanished before the tap',
      );
      final callId = proposal!.calls.single.id;

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

      await pumpWhile(
        tester,
        () async => await orderCount() == 0,
        reason:
            'the Purchase Order to be created. Transcript:\n${transcript()}',
      );

      final order = (await purchaseOrders()).single;
      expect(order['docstatus'], 1, reason: 'left as an unsent draft');
      expect(
        order['owner'],
        user,
        reason: 'the document must carry the real user, not a service account',
      );
      // The supplier came from the item, and the price from the price list.
      expect(order['supplier'], isNotNull);
      expect(
        order['grand_total'],
        greaterThan(0),
        reason: 'ordered at no price',
      );

      final name = '${order['name']}';
      final lines = await container
          .read(frappeClientProvider)
          .callMethod(
            'frappe.client.get',
            params: {'doctype': 'Purchase Order', 'name': name},
          );
      final items = ((lines['message'] as Map)['items']! as List)
          .cast<Map<String, dynamic>>();
      expect(items, hasLength(1));
      expect(
        items.single['material_request'],
        startsWith('MAT-MR'),
        reason: 'the order must cite the request it came from',
      );
      expect(
        items.single['qty'],
        4.0,
        reason: "the quantity is the request's",
      );

      // The real document number reaches the device.
      await answersWith(tester, name);

      // Replay must not order the same board twice.
      await expectLater(
        container
            .read(frappeClientProvider)
            .callMethod(
              'korkem_ai.korkem_ai.chat.confirm',
              post: true,
              params: {
                'turn_id': 'replay',
                'call_ids': [callId],
                'message': 'again',
              },
            ),
        throwsA(isA<Exception>()),
        reason: 'a replayed confirmation must be refused',
      );
      expect(await orderCount(), 1, reason: 'replay ordered it twice');

      // 3. And a plain read: what is on order, and when does it land.
      await ask(tester, 'Что сейчас уже заказано и когда придёт?');
      await answersWith(tester, name);

      // Leave the site as it was found.
      final client = container.read(frappeClientProvider);
      await client.callMethod(
        'frappe.client.cancel',
        post: true,
        params: {'doctype': 'Purchase Order', 'name': name},
      );
      await client.callMethod(
        'frappe.client.delete',
        post: true,
        params: {'doctype': 'Purchase Order', 'name': name},
      );
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
