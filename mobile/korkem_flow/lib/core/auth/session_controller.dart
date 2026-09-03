import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/auth_repository.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/push/push_registration.dart';

/// Who is signed in, and against which site.
///
/// Server and credential are one value rather than two providers because they
/// are only ever meaningful together: a key minted against one bench is not a
/// credential on another, and changing the server must invalidate the session.
@immutable
class Session {
  const Session({required this.serverUrl, this.credentials});

  final String serverUrl;

  /// `null` means signed out.
  final AuthCredentials? credentials;

  String? get user => credentials?.user;

  bool get isAuthenticated => credentials != null;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(authDioProvider)),
);

final sessionProvider = AsyncNotifierProvider<SessionController, Session>(
  SessionController.new,
);

class SessionController extends AsyncNotifier<Session> {
  /// Restores a stored credential and confirms it still works.
  ///
  /// A session cookie can expire server-side with nothing to signal it locally,
  /// so "we have a credential" is not the same as "we are signed in" — the only
  /// honest check is a round trip.
  @override
  Future<Session> build() async {
    final store = ref.watch(credentialStoreProvider);
    final serverUrl =
        await store.readServerUrl() ?? ref.watch(appConfigProvider).baseUrl;

    final credentials = await store.read();
    if (credentials == null) return Session(serverUrl: serverUrl);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .verify(baseUrl: serverUrl, credentials: credentials);

      return Session(
        serverUrl: serverUrl,
        credentials: user == credentials.user
            ? credentials
            // The server is authoritative about identity.
            : _rebind(credentials, user),
      );
    } on AuthFailure {
      // Единственная причина забыть человека: сервер сказал, что он не тот, за
      // кого себя выдаёт. Всё остальное — наши трудности, а не его.
      await store.clear();
      return Session(serverUrl: serverUrl);
    } on Object {
      // Сюда попадает всё прочее: нет сети, 500, разрыв на середине, ответ не
      // того вида. Раньше отсюда наверх уходило исключение, провайдер сессии
      // становился ошибкой, роутер видел «не вошёл» и показывал экран входа —
      // человек вводил почту и пароль заново из-за чужой пятисотки.
      //
      // Владелец описал это как «когда я вышел и опять захожу, всегда
      // спрашивает мою почту и пароль». Учётные данные при этом на месте:
      // приложение их не потеряло, оно решило, что они не годятся.
      //
      // Теперь сохранённые данные остаются, и первый же настоящий запрос
      // покажет, живы они или нет — если нет, вернётся `AuthFailure` выше.
      return Session(serverUrl: serverUrl, credentials: credentials);
    }
  }

  /// Exchanges credentials for a session. Progress is *not* published as
  /// [AsyncValue.loading].
  ///
  /// It used to be, and that single line made every sign-in failure invisible:
  /// the router treats a loading session as "still restoring at startup" and
  /// redirects to the splash, which disposed the login screen mid-request. The
  /// screen that later caught the error was already unmounted, so its
  /// `setState` was a no-op, and the router then built a *fresh* login screen
  /// with no error and empty fields. A wrong password looked identical to a
  /// network timeout: a spinner, then the form again, silently.
  ///
  /// Sign-in progress belongs to the screen — `LoginScreen` already tracks it —
  /// so the session now changes only on success, or on failure to re-seat the
  /// server the user typed.
  Future<void> signIn({
    required String serverUrl,
    required String user,
    required String password,
  }) async {
    final normalised = normaliseServerUrl(serverUrl);

    try {
      final credentials = await ref
          .read(authRepositoryProvider)
          .signIn(baseUrl: normalised, user: user, password: password);

      final store = ref.read(credentialStoreProvider);
      await store.writeServerUrl(normalised);
      await store.write(credentials);

      state = AsyncValue.data(
        Session(serverUrl: normalised, credentials: credentials),
      );
    } on Exception {
      // A failed sign-in must not park the app in an AsyncError it can never
      // leave — the login form has to stay usable for the next attempt. The
      // failure is rethrown for the screen to display, not swallowed.
      //
      // Only the server moves: the state stays `data`, so the router leaves the
      // login screen mounted and the banner it sets survives to be read.
      state = AsyncValue.data(Session(serverUrl: normalised));
      rethrow;
    }
  }

  Future<void> signOut() async {
    final current = state.value;
    final credentials = current?.credentials;
    final serverUrl = current?.serverUrl ?? ref.read(appConfigProvider).baseUrl;

    // Пока доступ ещё есть: сказать узлу, что на этот телефон присылать больше
    // не надо. Ниже доступ будет стёрт, и сказать это станет нечем. Обёрнуто
    // так, чтобы никакая беда с уведомлениями не помешала человеку выйти.
    try {
      await ref.read(pushRegistrationProvider).withdrawNow();
    } on Object catch (error) {
      debugPrint('Push withdrawal on sign-out failed: $error');
    }

    try {
      if (credentials != null) {
        await ref
            .read(authRepositoryProvider)
            .signOut(baseUrl: serverUrl, credentials: credentials);
      }
    } finally {
      // Whatever the server says — or fails to say — a user who taps "sign
      // out" must end up signed out on this device.
      await ref.read(credentialStoreProvider).clear();
      state = AsyncValue.data(Session(serverUrl: serverUrl));
    }
  }

  static AuthCredentials _rebind(AuthCredentials credentials, String user) =>
      switch (credentials) {
        ApiKeyCredentials(:final apiKey, :final apiSecret) => ApiKeyCredentials(
          user: user,
          apiKey: apiKey,
          apiSecret: apiSecret,
        ),
        SessionCredentials(:final sid) => SessionCredentials(
          user: user,
          sid: sid,
        ),
      };
}

/// Trims a hand-typed server address into something [Uri] can resolve.
///
/// Users type `korkem.localhost:8000`; a missing scheme would otherwise be
/// parsed as a relative path and every request would fail with nothing on
/// screen to explain why.
String normaliseServerUrl(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'/+$'), '');
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}
