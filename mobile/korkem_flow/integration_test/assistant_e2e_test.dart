import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/data/assistant_channel.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one test that talks to a real server.
///
/// Everything else in `test/` fakes the network, which is what makes those
/// suites fast and deterministic — and also what makes them blind to the layer
/// that has caused every device-level failure in this project so far:
/// `FrappeSocketChannel`. A turn is queued over HTTP and answered on a
/// socket.io channel, so a green unit suite proves nothing about whether an
/// answer ever arrives.
///
/// This drives the production `RemoteAssistant` and `FrappeSocketChannel`
/// against a live bench, a live gateway and a live model.
///
/// Run it against a running bench:
///
/// ```sh
/// flutter test integration_test/assistant_e2e_test.dart -d linux \
///   --dart-define=KORKEM_BASE_URL=http://korkem.localhost:8000 \
///   --dart-define=KORKEM_E2E_USER=Administrator \
///   --dart-define=KORKEM_E2E_PASSWORD=...
/// ```
///
/// The password arrives as a `--dart-define`, never as a literal here — a
/// credential in a test file is a credential in git.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const user = String.fromEnvironment('KORKEM_E2E_USER');
  const password = String.fromEnvironment('KORKEM_E2E_PASSWORD');

  /// A container wired to the real backend, with a real signed-in session.
  Future<ProviderContainer> signedIn() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // Only the *persistence* is swapped. The login, the credential, the
        // HTTP client and the socket are all the real ones — this exists
        // because `flutter_secure_storage` on Linux needs gnome-keyring, which
        // is locked in a headless WSL session (`KeyringLocked`). Android uses
        // EncryptedSharedPreferences and has no such problem, so this stands in
        // for the environment rather than for any part of the app under test.
        credentialStoreProvider.overrideWithValue(_MemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(sessionProvider.notifier)
        .signIn(
          serverUrl: AppConfig.fromEnvironment().baseUrl,
          user: user,
          password: password,
        );

    final session = container.read(sessionProvider).value;
    expect(
      session?.credentials,
      isNotNull,
      reason: 'sign-in failed — is the bench up and the password right?',
    );
    return container;
  }

  testWidgets('the gateway reports the site the socket needs', (tester) async {
    // A client cannot derive this: the socket.io namespace must equal the site
    // name, which is not the host the app dials.
    final container = await signedIn();

    final info = await container.read(assistantInfoProvider.future);

    expect(info, isNotNull);
    expect(info!.site, isNotEmpty);
    expect(info.event, FrappeSocketChannel.defaultEvent);
  });

  testWidgets(
    'the real socket delivers a real answer',
    (tester) async {
      // The whole point. HTTP working has never implied the socket working, and
      // this is the assertion that tells them apart.
      final container = await signedIn();
      await container.read(assistantInfoProvider.future);

      final assistant = container.read(assistantRepositoryProvider);
      expect(
        assistant.runtimeType.toString(),
        'RemoteAssistant',
        reason: 'fell back to the local matcher — no channel was built',
      );

      final events = await assistant
          .send(
            prompt: 'Сколько сделок в статусе Negotiation? Кратко.',
            history: const [],
          )
          .toList();

      final failures = events.whereType<AssistantFailed>();
      expect(
        failures,
        isEmpty,
        reason: 'turn failed: ${failures.map((f) => f.reason)}',
      );

      final done = events.whereType<AssistantDone>().single;
      expect(done.text, isNotNull);
      expect(done.text, isNotEmpty);
      // Cyrillic must survive the socket. A UTF-8 bug in the SSE reader once
      // mangled every non-ASCII streamed reply, and this is the layer
      // that would hide a repeat.
      expect(
        RegExp('[А-Яа-я]').hasMatch(done.text!),
        isTrue,
        reason: 'expected a Russian answer, got: ${done.text}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'a read tool runs and is reported as activity',
    (tester) async {
      final container = await signedIn();
      await container.read(assistantInfoProvider.future);

      final events = await container
          .read(assistantRepositoryProvider)
          .send(prompt: 'Покажи мои открытые сделки.', history: const [])
          .toList();

      final activity = events.whereType<AssistantToolActivity>().toList();
      expect(activity, isNotEmpty, reason: 'no tool was reported');
      expect(activity.first.tool, startsWith('crm.'));
      expect(activity.every((a) => a.ok), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Keeps a credential in memory for the length of one test.
///
/// Substituting this is what lets the suite run headlessly; it is deliberately
/// the smallest possible substitution, and it is *not* on the path this test
/// exists to prove.
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
