import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/auth_repository.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// In-memory stand-in for the platform keychain, which needs a D-Bus session
/// on Linux and simply is not there in a test runner.
class _FakeStore implements CredentialStore {
  _FakeStore({this.credentials, this.serverUrl});

  AuthCredentials? credentials;
  String? serverUrl;
  bool cleared = false;

  @override
  Future<AuthCredentials?> read() async => credentials;

  @override
  Future<void> write(AuthCredentials value) async => credentials = value;

  @override
  Future<String?> readServerUrl() async => serverUrl;

  @override
  Future<void> writeServerUrl(String url) async => serverUrl = url;

  @override
  Future<void> clear() async {
    cleared = true;
    credentials = null;
  }
}

const _stored = ApiKeyCredentials(
  user: 'aidos@korkem.kz',
  apiKey: 'K',
  apiSecret: 'S',
);

void main() {
  late _MockAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(_stored);
  });

  setUp(() {
    repository = _MockAuthRepository();
  });

  ProviderContainer containerWith(_FakeStore store) {
    final container = ProviderContainer(
      overrides: [
        credentialStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repository),
      ],
      // Riverpod 3 auto-retries a failed provider, which would park it in
      // AsyncLoading(retrying) forever instead of settling.
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  group('restore on launch', () {
    test('signs out when there is nothing stored', () async {
      final session = await containerWith(_FakeStore()).read(
        sessionProvider.future,
      );

      expect(session.isAuthenticated, isFalse);
      verifyNever(
        () => repository.verify(
          baseUrl: any(named: 'baseUrl'),
          credentials: any(named: 'credentials'),
        ),
      );
    });

    test('revalidates a stored credential against the server', () async {
      final store = _FakeStore(
        credentials: _stored,
        serverUrl: 'https://korkem.example.kz',
      );
      when(
        () => repository.verify(
          baseUrl: any(named: 'baseUrl'),
          credentials: any(named: 'credentials'),
        ),
      ).thenAnswer((_) async => 'aidos@korkem.kz');

      final session = await containerWith(store).read(sessionProvider.future);

      expect(session.isAuthenticated, isTrue);
      expect(session.user, 'aidos@korkem.kz');
      expect(session.serverUrl, 'https://korkem.example.kz');
    });

    test('discards a credential the server no longer accepts', () async {
      // The point of revalidating: a session cookie expires server-side with
      // nothing locally to show for it, so holding one is not being signed in.
      final store = _FakeStore(credentials: _stored, serverUrl: 'https://s.kz');
      when(
        () => repository.verify(
          baseUrl: any(named: 'baseUrl'),
          credentials: any(named: 'credentials'),
        ),
      ).thenThrow(const AuthFailure('expired'));

      final session = await containerWith(store).read(sessionProvider.future);

      expect(session.isAuthenticated, isFalse);
      expect(store.cleared, isTrue);
    });

    test('keeps the credential when the launch is merely offline', () async {
      // Being unreachable is not being rejected. Throwing the user back to a
      // login form they cannot complete without a network would be worse than
      // letting the cached UI open.
      final store = _FakeStore(credentials: _stored, serverUrl: 'https://s.kz');
      when(
        () => repository.verify(
          baseUrl: any(named: 'baseUrl'),
          credentials: any(named: 'credentials'),
        ),
      ).thenThrow(const NetworkFailure('offline'));

      final session = await containerWith(store).read(sessionProvider.future);

      expect(session.isAuthenticated, isTrue);
      expect(store.cleared, isFalse);
    });

    test('чужая пятисотка при запуске не выкидывает на экран входа', () async {
      // Владелец: «когда я вышел и опять захожу, всегда спрашивает мою почту и
      // пароль». Учётные данные при этом лежали на месте — приложение решало,
      // что они не годятся, из-за ошибки, которая к ним отношения не имеет.
      //
      // Раньше `build` ловил только «сессия истекла» и «нет сети»; всё
      // остальное уходило наверх, провайдер сессии становился ошибкой, роутер
      // видел «не вошёл». Пятисотка на сервере читалась как «вас тут не знают».
      final store = _FakeStore(credentials: _stored, serverUrl: 'https://s.kz');
      when(
        () => repository.verify(
          baseUrl: any(named: 'baseUrl'),
          credentials: any(named: 'credentials'),
        ),
      ).thenThrow(const ServerFailure('Internal Server Error'));

      final session = await containerWith(store).read(sessionProvider.future);

      expect(session.isAuthenticated, isTrue);
      expect(
        store.cleared,
        isFalse,
        reason: 'забыть человека вправе только сервер, сказавший «это не вы»',
      );
    });

    test('«это не вы» — единственная причина забыть учётные данные', () async {
      final store = _FakeStore(credentials: _stored, serverUrl: 'https://s.kz');
      when(
        () => repository.verify(
          baseUrl: any(named: 'baseUrl'),
          credentials: any(named: 'credentials'),
        ),
      ).thenThrow(const AuthFailure('expired'));

      final session = await containerWith(store).read(sessionProvider.future);

      expect(session.isAuthenticated, isFalse);
      expect(store.cleared, isTrue);
    });
  });

  group('signIn', () {
    test('persists both the credential and the server it belongs to', () async {
      final store = _FakeStore();
      when(
        () => repository.signIn(
          baseUrl: any(named: 'baseUrl'),
          user: any(named: 'user'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _stored);

      final container = containerWith(store);
      await container.read(sessionProvider.future);
      await container
          .read(sessionProvider.notifier)
          .signIn(
            serverUrl: 'korkem.example.kz',
            user: 'aidos@korkem.kz',
            password: 'secret',
          );

      expect(store.credentials, _stored);
      // A bare host is not a URL; without a scheme every later request would
      // resolve as a relative path and fail with nothing on screen to explain.
      expect(store.serverUrl, 'https://korkem.example.kz');
      expect(container.read(sessionProvider).value?.isAuthenticated, isTrue);
    });

    test('leaves the form usable after a rejected password', () async {
      final store = _FakeStore();
      when(
        () => repository.signIn(
          baseUrl: any(named: 'baseUrl'),
          user: any(named: 'user'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthFailure('Incorrect email or password.'));

      final container = containerWith(store);
      await container.read(sessionProvider.future);

      await expectLater(
        container
            .read(sessionProvider.notifier)
            .signIn(
              serverUrl: 'https://korkem.example.kz',
              user: 'aidos@korkem.kz',
              password: 'wrong',
            ),
        throwsA(isA<AuthFailure>()),
      );

      // The failure must reach the screen without stranding the provider in an
      // AsyncError it can never leave.
      final state = container.read(sessionProvider);
      expect(state.hasError, isFalse);
      expect(state.value?.isAuthenticated, isFalse);
    });

    test('never publishes a loading state while signing in', () async {
      // Regression: signIn used to set AsyncValue.loading(). The router reads a
      // loading session as "restoring at startup" and redirects to the splash,
      // disposing the login screen mid-request — so the error it caught was set
      // on an unmounted State and vanished. Every failure, from a wrong
      // password to a dead network, showed a spinner and then an empty form.
      //
      // Asserted on the emitted sequence, not the final state: the offending
      // transition was transient and a post-hoc read cannot see it.
      final store = _FakeStore();
      when(
        () => repository.signIn(
          baseUrl: any(named: 'baseUrl'),
          user: any(named: 'user'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const NetworkFailure('No connection to the server.'));

      final container = containerWith(store);
      await container.read(sessionProvider.future);

      final emitted = <AsyncValue<Session>>[];
      container.listen(
        sessionProvider,
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );

      await expectLater(
        container
            .read(sessionProvider.notifier)
            .signIn(
              serverUrl: 'https://korkem.example.kz',
              user: 'aidos@korkem.kz',
              password: 'secret',
            ),
        throwsA(isA<NetworkFailure>()),
      );

      expect(emitted, isNotEmpty);
      expect(emitted.any((state) => state.isLoading), isFalse);
    });
  });

  test('signOut clears storage even when the server call fails', () async {
    final store = _FakeStore(credentials: _stored, serverUrl: 'https://s.kz');
    when(
      () => repository.verify(
        baseUrl: any(named: 'baseUrl'),
        credentials: any(named: 'credentials'),
      ),
    ).thenAnswer((_) async => 'aidos@korkem.kz');
    when(
      () => repository.signOut(
        baseUrl: any(named: 'baseUrl'),
        credentials: any(named: 'credentials'),
      ),
    ).thenThrow(const NetworkFailure('offline'));

    final container = containerWith(store);
    await container.read(sessionProvider.future);

    await expectLater(
      container.read(sessionProvider.notifier).signOut(),
      throwsA(isA<NetworkFailure>()),
    );

    // The failure surfaces, but the device is signed out regardless — the one
    // outcome the user unambiguously asked for.
    expect(store.cleared, isTrue);
    expect(container.read(sessionProvider).value?.isAuthenticated, isFalse);
  });

  group('credential serialisation', () {
    test('round-trips both variants', () {
      for (final credentials in <AuthCredentials>[
        _stored,
        const SessionCredentials(user: 'rep@korkem.kz', sid: 'abc'),
      ]) {
        final restored = AuthCredentials.fromJson(credentials.toJson());
        expect(restored, isNotNull);
        expect(restored!.user, credentials.user);
        // MapEntry has no value equality, so compare the parts.
        expect(restored.header.key, credentials.header.key);
        expect(restored.header.value, credentials.header.value);
        expect(restored.runtimeType, credentials.runtimeType);
      }
    });

    test('rejects an unrecognised payload rather than guessing', () {
      expect(AuthCredentials.fromJson({'kind': 'oauth', 'user': 'a'}), isNull);
      expect(AuthCredentials.fromJson({'user': 42}), isNull);
    });
  });

  group('normaliseServerUrl', () {
    test('adds https, trims, and drops trailing slashes', () {
      expect(normaliseServerUrl('  korkem.kz/  '), 'https://korkem.kz');
      expect(
        normaliseServerUrl('http://10.0.0.5:8000'),
        'http://10.0.0.5:8000',
      );
      expect(normaliseServerUrl('https://a.kz//'), 'https://a.kz');
      expect(normaliseServerUrl('   '), '');
    });
  });
}
