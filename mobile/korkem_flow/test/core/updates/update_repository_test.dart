import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/updates/update_repository.dart';

Dio _dioAnswering(Map<String, dynamic> message) {
  return Dio()..httpClientAdapter = _Adapter(message);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.message);

  final Map<String, dynamic> message;
  Uri? seen;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options.uri;
    return ResponseBody.fromString(
      jsonEncode({'message': message}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _config = AppConfig(baseUrl: 'https://node.example', flavor: 'prod');

void main() {
  group('Обновление приложения', () {
    // Владелец: «клиент, скачавший приложение один раз, не должен скачивать
    // его снова руками». Отсюда весь этот код — и отсюда же требование, чтобы
    // подсунуть человеку чужой файл было нельзя.

    test('сервер сказал «нечего» — обновления нет', () async {
      final repo = UpdateRepository(
        _dioAnswering({'available': false}),
        _config,
      );

      expect(await repo.check(platform: 'Android', build: 1), isNull);
    });

    test('новая сборка по https принимается', () async {
      final repo = UpdateRepository(
        _dioAnswering({
          'available': true,
          'version': '0.2.0',
          'build': 7,
          'url': 'https://node.example/files/korkem.apk',
          'notes': 'микрофон',
          'mandatory': false,
        }),
        _config,
      );

      final update = await repo.check(platform: 'Android', build: 1);

      expect(update, isNotNull);
      expect(update!.version, '0.2.0');
      expect(update.build, 7);
      expect(update.mandatory, isFalse);
    });

    test(
      'адрес без https отвергается, даже когда прислал его сервер',
      () async {
        // Сервер тоже бывает настроен неверно, а подменённый по дороге
        // установочный файл — это подменённое приложение на телефоне человека.
        final repo = UpdateRepository(
          _dioAnswering({
            'available': true,
            'version': '0.2.0',
            'build': 7,
            'url': 'http://node.example/files/korkem.apk',
          }),
          _config,
        );

        expect(await repo.check(platform: 'Android', build: 1), isNull);
      },
    );

    test('обязательное обновление приходит помеченным', () async {
      final repo = UpdateRepository(
        _dioAnswering({
          'available': true,
          'version': '0.3.0',
          'build': 9,
          'url': 'https://node.example/files/korkem.apk',
          'mandatory': true,
        }),
        _config,
      );

      final update = await repo.check(platform: 'Android', build: 1);

      expect(update!.mandatory, isTrue);
    });

    test(
      'свой номер сборки уходит на сервер: сравнивает он, а не мы',
      () async {
        final adapter = _Adapter({'available': false});
        final dio = Dio()..httpClientAdapter = adapter;

        await UpdateRepository(
          dio,
          _config,
        ).check(platform: 'Android', build: 42);

        expect(adapter.seen?.queryParameters['build'], '42');
        expect(adapter.seen?.queryParameters['platform'], 'Android');
      },
    );
  });
}
