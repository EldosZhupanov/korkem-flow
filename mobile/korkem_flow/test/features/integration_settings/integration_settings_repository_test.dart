import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/integration_settings/data/integration_settings_repository.dart';
import 'package:korkem_flow/features/integration_settings/domain/integration_config.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  Map<String, dynamic> data, {
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(data),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?headers,
  },
);

void main() {
  Dio createDio(Future<ResponseBody> Function(RequestOptions options) handler) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
      ),
    )..httpClientAdapter = _FakeAdapter(handler);
  }

  group('IntegrationConfig domain models', () {
    test('TrustMeConfig deserialization and equality', () {
      const config1 = TrustMeConfig(
        enabled: true,
        isApiTokenConfigured: true,
        isWebhookSecretConfigured: false,
        organizationBin: '123456789012',
        lastStatus: 'active',
        lastCheckedOn: '2026-09-03',
      );

      final fromJson = TrustMeConfig.fromJson(const {
        'enabled': 1,
        'organization_bin': '123456789012',
        'configured': {
          'api_token': true,
          'webhook_secret': false,
        },
        'last_status': 'active',
        'last_checked_on': '2026-09-03',
        'last_error': null,
      });

      expect(fromJson, config1);
      expect(fromJson.hashCode, config1.hashCode);
    });

    test('KaspiConfig deserialization and equality', () {
      const config1 = KaspiConfig(
        enabled: true,
        isApiKeyConfigured: true,
        isWebhookSecretConfigured: true,
        merchantId: 'MERCHANT-99',
        lastError: 'Connection refused',
      );

      final fromJson = KaspiConfig.fromJson(const {
        'enabled': 1,
        'merchant_id': 'MERCHANT-99',
        'configured': {
          'api_key': true,
          'webhook_secret': true,
        },
        'last_status': null,
        'last_checked_on': null,
        'last_error': 'Connection refused',
      });

      expect(fromJson, config1);
      expect(fromJson.hashCode, config1.hashCode);
    });

    test('IntegrationStatus deserialization and equality', () {
      final status = IntegrationStatus.fromJson(const {
        'trustme': {
          'enabled': 0,
          'organization_bin': null,
          'configured': {
            'api_token': false,
            'webhook_secret': false,
          },
        },
        'kaspi': {
          'enabled': 1,
          'merchant_id': 'M123',
          'configured': {
            'api_key': true,
            'webhook_secret': false,
          },
        },
      });

      expect(status.trustme.enabled, isFalse);
      expect(status.trustme.isApiTokenConfigured, isFalse);
      expect(status.kaspi.enabled, isTrue);
      expect(status.kaspi.merchantId, 'M123');
      expect(status.kaspi.isApiKeyConfigured, isTrue);
    });
  });

  group('IntegrationSettingsRepository', () {
    test('fetchStatus calls endpoint and returns IntegrationStatus', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.integration_settings.status',
        );
        return _json({
          'message': {
            'trustme': {
              'enabled': 1,
              'organization_bin': '123456789012',
              'configured': {'api_token': true, 'webhook_secret': false},
            },
            'kaspi': {
              'enabled': 0,
              'merchant_id': null,
              'configured': {'api_key': false, 'webhook_secret': false},
            },
          },
        });
      });

      final repo = IntegrationSettingsRepository(FrappeClient(dio));
      final status = await repo.fetchStatus();

      expect(status.trustme.enabled, isTrue);
      expect(status.trustme.organizationBin, '123456789012');
      expect(status.trustme.isApiTokenConfigured, isTrue);
      expect(status.kaspi.enabled, isFalse);
    });

    test('saveTrustMe omits empty secret strings from payload', () async {
      Map<String, dynamic>? capturedParams;

      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.integration_settings.save',
        );
        capturedParams = options.data as Map<String, dynamic>?;
        return _json({
          'message': {
            'enabled': 1,
            'organization_bin': '999888777666',
            'configured': {'api_token': true, 'webhook_secret': false},
          },
        });
      });

      final repo = IntegrationSettingsRepository(FrappeClient(dio));
      final updated = await repo.saveTrustMe(
        enabled: true,
        organizationBin: '999888777666',
        apiToken: '', // Empty: MUST NOT be sent!
        webhookSecret: '   ', // Whitespace: MUST NOT be sent!
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['provider'], 'trustme');
      final values =
          jsonDecode(
                capturedParams!['values'] as String,
              )
              as Map<String, dynamic>;
      expect(values['enabled'], 1);
      expect(values['organization_bin'], '999888777666');
      expect(values.containsKey('api_token'), isFalse);
      expect(values.containsKey('webhook_secret'), isFalse);

      expect(updated.organizationBin, '999888777666');
    });

    test('saveKaspi includes newly entered non-empty secrets', () async {
      Map<String, dynamic>? capturedParams;

      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.integration_settings.save',
        );
        capturedParams = options.data as Map<String, dynamic>?;
        return _json({
          'message': {
            'enabled': 1,
            'merchant_id': 'MERCH-01',
            'configured': {'api_key': true, 'webhook_secret': true},
          },
        });
      });

      final repo = IntegrationSettingsRepository(FrappeClient(dio));
      await repo.saveKaspi(
        enabled: true,
        merchantId: 'MERCH-01',
        apiKey: 'secret-key-123',
        webhookSecret: 'webhook-secret-456',
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['provider'], 'kaspi');
      final values =
          jsonDecode(
                capturedParams!['values'] as String,
              )
              as Map<String, dynamic>;
      expect(values['enabled'], 1);
      expect(values['merchant_id'], 'MERCH-01');
      expect(values['api_key'], 'secret-key-123');
      expect(values['webhook_secret'], 'webhook-secret-456');
    });

    test('clearSecret posts provider and field name', () async {
      Map<String, dynamic>? capturedParams;

      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.integration_settings.clear_secret',
        );
        capturedParams = options.data as Map<String, dynamic>?;
        return _json({
          'message': {
            'enabled': 1,
            'organization_bin': '123456789012',
            'configured': {'api_token': false, 'webhook_secret': false},
          },
        });
      });

      final repo = IntegrationSettingsRepository(FrappeClient(dio));
      final result = await repo.clearSecret(
        provider: 'trustme',
        field: 'api_token',
      );

      expect(capturedParams!['provider'], 'trustme');
      expect(capturedParams!['field'], 'api_token');
      final configured = result['configured'] as Map<String, dynamic>;
      expect(configured['api_token'], isFalse);
    });

    test('throws ServerFailure on unexpected null response', () async {
      final dio = createDio((_) async => _json({'message': null}));
      final repo = IntegrationSettingsRepository(FrappeClient(dio));

      expect(
        repo.fetchStatus,
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
