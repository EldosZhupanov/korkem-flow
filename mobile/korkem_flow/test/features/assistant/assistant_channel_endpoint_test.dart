import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/features/assistant/data/assistant_channel.dart';

FrappeSocketChannel _channel(String baseUrl) {
  return FrappeSocketChannel(
    baseUrl: baseUrl,
    siteName: 'api.korkem.asia',
    credentials: const ApiKeyCredentials(
      user: 'owner@korkem.kz',
      apiKey: 'k',
      apiSecret: 's',
    ),
  );
}

void main() {
  group('Куда приложение стучится за ответом ассистента', () {
    // Найдено на живом узле. Владелец писал «привет», сервер отвечал за
    // секунды — в журнале «Successfully completed», — а на телефоне было
    // «не удалось связаться с KORKEM. Проверьте подключение».
    //
    // Приложение всегда подменяло порт на 9000. На стенде разработчика там и
    // правда слушает socket.io. На настоящем узле этот порт наружу не
    // публикуют вовсе: открыты 22, 80 и 443, а реальное время идёт через тот
    // же TLS-адрес. Стук в закрытый порт выглядит как молчание сервера.

    test('за TLS порт не подменяется: сокет идёт через тот же 443', () {
      final endpoint = _channel('https://api.korkem.asia').endpoint;

      expect(endpoint.scheme, 'https');
      expect(
        endpoint.hasPort,
        isFalse,
        reason: 'порт 9000 снаружи закрыт, и стучаться в него — молчать',
      );
      expect(endpoint.path, '/api.korkem.asia');
    });

    test('на стенде разработчика порт по-прежнему 9000', () {
      final endpoint = _channel('http://10.0.2.2:8000').endpoint;

      expect(endpoint.port, 9000);
      expect(endpoint.path, '/api.korkem.asia');
    });

    test('имя сайта остаётся пространством имён в обоих случаях', () {
      // Middleware Frappe сверяет `socket.nsp.name` с именем сайта и молча
      // отвергает несовпадение.
      for (final base in ['https://api.korkem.asia', 'http://127.0.0.1:8000']) {
        expect(_channel(base).endpoint.path, '/api.korkem.asia');
      }
    });
  });
}
