import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/push/push_notifications.dart';
import 'package:korkem_flow/core/push/push_repository.dart';

/// Держит узел в курсе, на какой телефон присылать.
///
/// Слушатель, а не правка в контроллере сессии: вход не должен ничего знать об
/// уведомлениях, иначе однажды сломанный Firebase начнёт мешать людям входить.
/// Здесь же наоборот — что бы ни случилось с уведомлениями, вход и работа
/// продолжаются (R8: узел живёт в цехе, где интернета может не быть вовсе).
final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final registration = PushRegistration(ref);
  ref.onDispose(registration.dispose);
  registration.start();
  return registration;
});

class PushRegistration {
  PushRegistration(this._ref);

  final Ref _ref;

  PushNotifications? _push;
  String? _token;
  StreamSubscription<String>? _refreshes;
  ProviderSubscription<AsyncValue<Session>>? _sessions;
  bool _signedIn = false;

  void start() {
    _sessions = _ref.listen<AsyncValue<Session>>(sessionProvider, (
      previous,
      next,
    ) {
      final signedIn = next.value?.isAuthenticated ?? false;
      if (signedIn == _signedIn) return;
      _signedIn = signedIn;
      // Только вход. Выход зовётся явно из `signOut`, до того как он сотрёт
      // доступ: отсюда, задним числом, сказать серверу уже нечем — запрос
      // ушёл бы без прав и вернулся бы отказом.
      if (signedIn) unawaited(_announce());
    }, fireImmediately: true);
  }

  /// Спросить разрешение, узнать адрес, назвать его узлу.
  ///
  /// Разрешение спрашивается здесь, а не при запуске приложения: до входа
  /// человеку нечего сообщать, а отказ, полученный на пустом месте, Android
  /// возвращает только через свои настройки.
  Future<void> _announce() async {
    try {
      _push ??= await PushNotifications.setUp();
      final push = _push;
      if (push == null) return;

      final token = await push.askAndGetToken();
      if (token == null) return;

      _token = token;
      await _ref.read(pushRepositoryProvider).register(token);

      // Адрес меняется сам — при переустановке, при очистке данных, иногда
      // просто так. Приложение, подписавшееся однажды, замолкает, и никто не
      // узнаёт, когда именно.
      _refreshes ??= push.tokenChanges.listen((fresh) async {
        _token = fresh;
        try {
          await _ref.read(pushRepositoryProvider).register(fresh);
        } on Object catch (error) {
          debugPrint('Push re-registration failed: $error');
        }
      });
    } on Object catch (error) {
      // Не глушим молча: «уведомления не приходят» — вопрос, на который должен
      // быть ответ хотя бы в журнале.
      debugPrint('Push registration failed: $error');
    }
  }

  /// Выход — это «на этот телефон больше не присылать».
  ///
  /// Зовётся из `SessionController.signOut` **до** стирания доступа. Иначе
  /// человек, вышедший из приложения, продолжал бы получать уведомления
  /// завода — до тех пор, пока на этом телефоне не войдёт кто-то другой.
  Future<void> withdrawNow() async {
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _ref.read(pushRepositoryProvider).forget(token);
    } on Object catch (error) {
      debugPrint('Push withdrawal failed: $error');
    }
  }

  void dispose() {
    unawaited(_refreshes?.cancel());
    _sessions?.close();
  }
}
