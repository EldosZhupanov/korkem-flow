import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/updates/update_controller.dart';
import 'package:korkem_flow/core/updates/update_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateController', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'KORKEM Flow',
        packageName: 'asia.korkem.flow',
        version: '0.3.0',
        buildNumber: '5',
        buildSignature: '',
      );
    });

    test('обновление обнаруживается и доступно в состоянии', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) {
          return ResponseBody.fromString(
            jsonEncode({
              'message': {
                'available': true,
                'version': '0.3.0',
                'build': 6,
                'url': 'https://api.korkem.asia/files/korkem-flow.apk',
                'notes': 'Онбординг Pilot P1',
                'mandatory': false,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

      final container = ProviderContainer(
        overrides: [
          updateRepositoryProvider.overrideWithValue(
            UpdateRepository(
              dio,
              const AppConfig(baseUrl: 'https://api.korkem.asia', flavor: 'prod'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(updateControllerProvider.notifier);
      await controller.check();

      final state = container.read(updateControllerProvider);
      expect(state.hasUpdate, isTrue);
      expect(state.available?.build, 6);
      expect(state.available?.version, '0.3.0');
      expect(state.dismissed, isFalse);
    });

    test('пользователь может отложить необязательное обновление', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) {
          return ResponseBody.fromString(
            jsonEncode({
              'message': {
                'available': true,
                'version': '0.3.0',
                'build': 6,
                'url': 'https://api.korkem.asia/files/korkem-flow.apk',
                'notes': 'Онбординг Pilot P1',
                'mandatory': false,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

      final container = ProviderContainer(
        overrides: [
          updateRepositoryProvider.overrideWithValue(
            UpdateRepository(
              dio,
              const AppConfig(baseUrl: 'https://api.korkem.asia', flavor: 'prod'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(updateControllerProvider.notifier);
      await controller.check();

      expect(container.read(updateControllerProvider).dismissed, isFalse);
      controller.dismiss();
      expect(container.read(updateControllerProvider).dismissed, isTrue);

      // Принудительная проверка сбрасывает статус отложенности
      await controller.check(force: true);
      expect(container.read(updateControllerProvider).dismissed, isFalse);
    });

    test('обязательное обновление нельзя отложить', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) {
          return ResponseBody.fromString(
            jsonEncode({
              'message': {
                'available': true,
                'version': '0.3.0',
                'build': 6,
                'url': 'https://api.korkem.asia/files/korkem-flow.apk',
                'notes': 'Критическое обновление безопасности',
                'mandatory': true,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

      final container = ProviderContainer(
        overrides: [
          updateRepositoryProvider.overrideWithValue(
            UpdateRepository(
              dio,
              const AppConfig(baseUrl: 'https://api.korkem.asia', flavor: 'prod'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(updateControllerProvider.notifier);
      await controller.check();

      final state = container.read(updateControllerProvider);
      expect(state.hasUpdate, isTrue);
      expect(state.available?.mandatory, isTrue);

      controller.dismiss();
      expect(container.read(updateControllerProvider).dismissed, isFalse);
    });
  });
}
