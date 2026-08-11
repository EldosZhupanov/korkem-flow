import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 28 — a customer asks about their own order, and only that.
///
/// The same assistant the planner uses, signed in as a customer. Two boundaries
/// are under test and both are real: Frappe's own `User Permission`, written
/// when the customer was linked, and `scope.customer_scope()`, which pins every
/// read to the customer the session belongs to.
///
/// The negative half matters more than the positive one. Naming another
/// customer must return this customer's orders, not theirs; asking to start
/// production must be refused outright; and neither refusal may reveal that the
/// other customer or their order exists.
///
/// Requires the customer to be linked:
/// `customer_access.link("korkem.client@example.com", "Мебель Астана")`.
///
/// ```sh
/// flutter test integration_test/customer_reads_e2e_test.dart \
///   -d emulator-5554 --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
///   --dart-define=KORKEM_E2E_USER=korkem.client@example.com \
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

  /// Only what the assistant said.
  ///
  /// The customer's own messages are in the transcript too, and this test makes
  /// the customer type another company's name on purpose — so asserting on the
  /// whole transcript would fail on the words the test itself put there. What
  /// is under test is what the *assistant* says back.
  String saidByAssistant() =>
      (container.read(activeThreadProvider)?.messages ?? [])
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.body)
          .join('\n');

  int repliesSoFar() => (container.read(activeThreadProvider)?.messages ?? [])
      .where((message) => message.role == ChatRole.assistant)
      .length;

  /// Waits for one more answer than there were before.
  ///
  /// Pumping a fixed couple of seconds and then asserting reads the *previous*
  /// answer and calls it a pass — or a failure, which is how this test first
  /// failed while the app was right.
  Future<void> replied(WidgetTester tester, int before) async {
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (DateTime.now().isBefore(deadline)) {
      if (repliesSoFar() > before) {
        await tester.pump(const Duration(milliseconds: 500));
        return;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('the assistant never answered. Said so far:\n${saidByAssistant()}');
  }

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

  FrappeClient client() => container.read(frappeClientProvider);

  const theirs = 'Караганда Мебель';

  testWidgets(
    'a customer sees their own order and cannot reach anybody elses',
    (tester) async {
      await signIn(tester);

      // 1. Their own order, without naming anything.
      await ask(tester, 'Где мой заказ?');
      await answersWith(tester, 'SAL-ORD-2026-00001');
      expect(
        saidByAssistant(),
        isNot(contains(theirs)),
        reason: 'another customer was named in the answer',
      );

      // 2. Naming another customer must not widen the scope.
      var before = repliesSoFar();
      await ask(tester, 'Покажи заказы клиента $theirs.');
      await replied(tester, before);
      expect(
        saidByAssistant(),
        isNot(contains('SAL-ORD-2026-00002')),
        reason: "another customer's order number reached the customer",
      );
      expect(
        saidByAssistant(),
        isNot(contains(theirs)),
        reason: 'the answer repeated the other company back as a lookup',
      );

      // 3. Naming the order number directly. The refusal must read as absence,
      //    not as a locked door with something behind it.
      before = repliesSoFar();
      await ask(tester, 'Что с заказом SAL-ORD-2026-00002?');
      await replied(tester, before);
      final refusal = saidByAssistant();
      expect(
        refusal,
        isNot(contains(theirs)),
        reason: 'the refusal named the other customer',
      );
      for (final leak in const [
        'другому',
        'другого клиента',
        'нет доступа',
        'не разрешен',
        'нет прав',
      ]) {
        expect(
          refusal.toLowerCase(),
          isNot(contains(leak)),
          reason: 'the refusal admitted the order exists ("$leak")',
        );
      }

      // 4. A write is not theirs to ask for.
      before = repliesSoFar();
      await ask(tester, 'Запусти производство по моему заказу.');
      await replied(tester, before);
      expect(
        find.byType(ConfirmationCard),
        findsNothing,
        reason: 'a customer was offered a write to confirm',
      );

      // 5. Nothing was created on their behalf — and the customer cannot
      //    even ask the question. `Pending Action` is not one of the three
      //    doctypes the Korkem Customer role can read, so the list is refused
      //    outright rather than coming back empty. That the queue is genuinely
      //    empty is checked in ERPNext as an administrator afterwards; a read
      //    performed by the customer could never prove it either way.
      await expectLater(
        () => client().getList('Pending Action', const FrappeQuery()),
        throwsA(isA<PermissionFailure>()),
      );

      // Printed, not asserted: the exact words a customer is answered with are
      // the model's, and pinning them would make this test fail on a rewording
      // rather than on a leak. What must not appear is asserted above; what did
      // appear is on the record.
      debugPrint('--- what the customer was told ---\n${saidByAssistant()}');
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
