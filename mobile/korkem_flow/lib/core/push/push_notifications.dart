import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push-уведомления: сигнал, что на узле что-то произошло. И только сигнал.
///
/// ## Почему в уведомлении нет ни одного слова о деле
///
/// Push от Google идёт **через серверы Google**. Мы обещаем клиенту обратное:
/// заказы, цены, имена клиентов и зарплаты не покидают его здания — это
/// записано в `docs/operations/privacy_policy.md` и стоит в архитектуре как R6.
/// Уведомление «Заказ Ерлана на 650 000 ₸ просрочен» нарушило бы обещание, не
/// нарушая ни строчки кода.
///
/// Поэтому уведомление приходит **без содержания**: узел присылает только
/// «есть новости», а приложение идёт за подробностями к своему серверу по TLS
/// и показывает их уже само. Человек видит то же самое; через Google не
/// проходит ничего.
///
/// ## Почему разрешение спрашивается не при запуске
///
/// Android 13 и новее спрашивают отдельно. Просить у человека, который только
/// что установил приложение и ещё ничего в нём не сделал, — верный способ
/// получить отказ навсегда: вернуть разрешение потом можно только через
/// настройки телефона. Спрашиваем после входа, когда уже понятно, о чём будут
/// уведомления.
class PushNotifications {
  PushNotifications._(this._messaging);

  final FirebaseMessaging _messaging;

  static PushNotifications? _instance;

  /// Поднимает Firebase один раз за запуск.
  ///
  /// Возвращает `null`, если платформа не поддержана или инициализация не
  /// удалась: приложение обязано работать без уведомлений вовсе — R8, узел
  /// живёт в цехе и без интернета.
  static Future<PushNotifications?> setUp() async {
    if (_instance != null) return _instance;
    try {
      await Firebase.initializeApp();
      return _instance = PushNotifications._(FirebaseMessaging.instance);
    } on Object catch (error) {
      // Не глушим молча: без этой строки «уведомления не приходят» становится
      // вопросом без ответа.
      debugPrint('Push unavailable: $error');
      return null;
    }
  }

  /// Спрашивает разрешение и возвращает адрес этого устройства, если дали.
  ///
  /// Адрес (registration token) сам по себе не секрет: он бесполезен без ключа
  /// проекта, который лежит на узле. Но он привязывает человека к устройству,
  /// поэтому уходит только на его собственный сервер и никуда больше.
  Future<String?> askAndGetToken() async {
    final settings = await _messaging.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return null;

    return _messaging.getToken();
  }

  /// Новый адрес, когда телефон его сменил.
  ///
  /// Токен меняется при переустановке, очистке данных и иногда сам по себе.
  /// Приложение, которое подписалось один раз и забыло, замолкает — и никто не
  /// узнает, когда именно.
  Stream<String> get tokenChanges => _messaging.onTokenRefresh;

  /// Пришёл сигнал, пока приложение открыто.
  Stream<RemoteMessage> get messages => FirebaseMessaging.onMessage;
}
