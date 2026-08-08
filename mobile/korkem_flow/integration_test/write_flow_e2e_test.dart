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
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The write path, driven through the real user interface.
///
/// The Phase 7 suite proved the socket by calling `RemoteAssistant.send`
/// directly. That leaves the most safety-critical widget in the product —
/// `ConfirmationCard`, the thing standing between a language model and a
/// database write — never once rendered on a device.
///
/// So this drives the widget tree: it types into the real login form, types
/// into the real composer, waits for a real Gemini turn to come back over a
/// real socket, and taps the real Confirm button. Nothing about the model, the
/// transport or the confirmation is simulated.
///
/// ```sh
/// flutter test integration_test/write_flow_e2e_test.dart -d emulator-5554 \
///   --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
///   --dart-define=KORKEM_E2E_USER=Administrator \
///   --dart-define=KORKEM_E2E_PASSWORD=...
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const user = String.fromEnvironment('KORKEM_E2E_USER');
  const password = String.fromEnvironment('KORKEM_E2E_PASSWORD');
  final baseUrl = AppConfig.fromEnvironment().baseUrl;

  // Unique per run, and deliberately Kazakh + Cyrillic: the whole path has to
  // carry it — prompt, model, tool arguments, database, and the answer back.
  final marker = 'Әдемі E2E ${DateTime.now().millisecondsSinceEpoch}';

  late ProviderContainer container;

  /// Pumps until [condition] holds, or gives up.
  ///
  /// `pumpAndSettle` cannot be used anywhere in this file: the app is talking
  /// to a live socket and a live model, so it legitimately never settles —
  /// a spinner is animating and events arrive seconds apart. This advances
  /// frames while real work happens, which is what a device actually does.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(minutes: 2),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('timed out waiting for ${reason ?? 'condition'}');
  }

  /// Like [pumpUntil], but the condition itself does I/O — used to wait on the
  /// database rather than on the widget tree.
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

  /// Counts through `/api/resource`, which is the path the app itself uses for
  /// every list. `frappe.client.get_count` is not whitelisted for RPC — worth
  /// recording, because it is a natural first guess and fails with a
  /// permission error that reads like auth rather than routing.
  Future<List<Map<String, dynamic>>> tasks() => container
      .read(frappeClientProvider)
      .getList(
        'CRM Task',
        FrappeQuery(
          fields: const ['name', 'title'],
          filters: [FrappeFilter.like('title', '%$marker%')],
        ),
      );

  Future<int> taskCount() async => (await tasks()).length;

  Future<void> signIn(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // Only the credential *cache* is substituted, and only because a
        // headless session has no keyring. Everything the test is really
        // about — the login, the socket, the model, the write — is real.
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

    // The real login form: server, user, password, then the button.
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

    // Waiting for "a TextField exists" is not enough, and was wrong at first:
    // `TextFormField` builds a `TextField`, so the login screen satisfies that
    // immediately and the test sails on unauthenticated — surfacing later as
    // "Insufficient Permission", which reads like a product bug and is not one.
    // The signal that sign-in finished is the login *form* going away.
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
    final composer = find.byType(TextField).last;
    await tester.enterText(composer, prompt);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'a model-proposed write is confirmed on the device and happens once',
    (tester) async {
      await signIn(tester);
      expect(await taskCount(), 0, reason: 'the marker must be unused');

      await ask(
        tester,
        'Создай задачу с названием "$marker". '
        'Ничего не спрашивай, просто создай.',
      );

      // Real Gemini, real socket. The card appearing at all is the assertion:
      // it means a structured tool call came back, the server refused to run
      // it, wrote a Pending Action, and published needs_confirmation.
      await pumpUntil(
        tester,
        () => find.byType(ConfirmationCard).evaluate().isNotEmpty,
        reason: 'the ConfirmationCard',
      );

      expect(
        find.textContaining('crm.create_task'),
        findsOneWidget,
        reason: 'the card must name the tool it would run',
      );
      expect(
        find.textContaining(marker),
        findsWidgets,
        reason: 'the card must show the arguments a human is agreeing to',
      );
      expect(
        await taskCount(),
        0,
        reason: 'nothing may be written before the tap',
      );

      // The real button, tapped the way a person would.
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump(const Duration(milliseconds: 500));

      await pumpUntil(
        tester,
        () => find.byType(ConfirmationCard).evaluate().isEmpty,
        reason: 'the card to be dismissed after confirming',
      );

      // The write itself, observed in the database rather than inferred from
      // the screen. Polled while pumping, because the turn continues after the
      // tap: the server executes the stored call and the model then summarises.
      await pumpWhile(
        tester,
        () async => await taskCount() == 0,
        reason: 'the task to be created',
      );
      expect(await taskCount(), 1);

      // …and the answer comes back to the device.
      await pumpUntil(
        tester,
        () => find.textContaining(marker).evaluate().length > 1,
        reason: 'the assistant to report the result on screen',
        timeout: const Duration(minutes: 3),
      );

      // Replay: the same proposal, confirmed again, must write nothing.
      final rows = await container
          .read(frappeClientProvider)
          .getList(
            'Pending Action',
            const FrappeQuery(
              fields: ['name', 'status'],
              filters: [FrappeFilter.equals('tool', 'crm.create_task')],
              orderBy: 'creation desc',
              limitPageLength: 1,
            ),
          );
      expect(rows, isNotEmpty, reason: 'the proposal must have been persisted');
      final callId = '${rows.first['name']}';
      expect(rows.first['status'], 'Approved');

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
      expect(await taskCount(), 1, reason: 'replay created a second record');

      // Leave the site as it was found.
      await container
          .read(frappeClientProvider)
          .callMethod(
            'frappe.client.delete',
            post: true,
            params: {
              'doctype': 'CRM Task',
              'name': await _taskName(container, marker),
            },
          );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<String> _taskName(ProviderContainer container, String marker) async {
  final response = await container
      .read(frappeClientProvider)
      .callMethod(
        'frappe.client.get_list',
        params: {
          'doctype': 'CRM Task',
          'filters': '[["title","like","%$marker%"]]',
          'fields': '["name"]',
          'limit_page_length': 1,
        },
      );
  return '${((response['message'] as List).first as Map)['name']}';
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
