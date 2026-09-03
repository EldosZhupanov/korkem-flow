import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/integration_settings/domain/integration_config.dart';

final integrationSettingsRepositoryProvider =
    Provider<IntegrationSettingsRepository>((ref) {
      return IntegrationSettingsRepository(ref.watch(frappeClientProvider));
    });

final integrationStatusProvider = FutureProvider<IntegrationStatus>((
  ref,
) async {
  final repo = ref.watch(integrationSettingsRepositoryProvider);
  return repo.fetchStatus();
});

/// Repository for reading and updating TrustMe and Kaspi integration settings.
class IntegrationSettingsRepository {
  IntegrationSettingsRepository(this._client);

  final FrappeClient _client;

  static const statusEndpoint =
      'korkem_manufacturing.api.integration_settings.status';
  static const saveEndpoint =
      'korkem_manufacturing.api.integration_settings.save';
  static const clearSecretEndpoint =
      'korkem_manufacturing.api.integration_settings.clear_secret';

  /// Fetches the integration status for TrustMe and Kaspi.
  ///
  /// Never returns credentials, only presence flags (`configured: true/false`).
  Future<IntegrationStatus> fetchStatus() async {
    final response = await _client.callMethod(statusEndpoint);
    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map) {
      throw const ServerFailure(
        'Failed to load integration status: unexpected response from server.',
      );
    }
    return IntegrationStatus.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Saves TrustMe configuration.
  ///
  /// Empty credentials are never sent, so existing secrets on the server
  /// remain untouched.
  Future<TrustMeConfig> saveTrustMe({
    bool? enabled,
    String? organizationBin,
    String? apiToken,
    String? webhookSecret,
  }) async {
    final values = <String, dynamic>{
      if (enabled != null) 'enabled': enabled ? 1 : 0,
      if (organizationBin != null) 'organization_bin': organizationBin.trim(),
      if (apiToken != null && apiToken.trim().isNotEmpty)
        'api_token': apiToken.trim(),
      if (webhookSecret != null && webhookSecret.trim().isNotEmpty)
        'webhook_secret': webhookSecret.trim(),
    };

    final response = await _client.callMethod(
      saveEndpoint,
      params: {
        'provider': 'trustme',
        'values': jsonEncode(values),
      },
      post: true,
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map) {
      throw const ServerFailure(
        'Failed to save TrustMe settings: unexpected response from server.',
      );
    }

    return TrustMeConfig.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Saves Kaspi Pay configuration.
  ///
  /// Empty credentials are never sent, so existing secrets on the server
  /// remain untouched.
  Future<KaspiConfig> saveKaspi({
    bool? enabled,
    String? merchantId,
    String? apiKey,
    String? webhookSecret,
  }) async {
    final values = <String, dynamic>{
      if (enabled != null) 'enabled': enabled ? 1 : 0,
      if (merchantId != null) 'merchant_id': merchantId.trim(),
      if (apiKey != null && apiKey.trim().isNotEmpty) 'api_key': apiKey.trim(),
      if (webhookSecret != null && webhookSecret.trim().isNotEmpty)
        'webhook_secret': webhookSecret.trim(),
    };

    final response = await _client.callMethod(
      saveEndpoint,
      params: {
        'provider': 'kaspi',
        'values': jsonEncode(values),
      },
      post: true,
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map) {
      throw const ServerFailure(
        'Failed to save Kaspi settings: unexpected response from server.',
      );
    }

    return KaspiConfig.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Explicitly clears a stored secret on the server.
  ///
  /// Requires intentional action and confirmation on the UI.
  Future<Map<String, dynamic>> clearSecret({
    required String provider,
    required String field,
  }) async {
    final response = await _client.callMethod(
      clearSecretEndpoint,
      params: {
        'provider': provider,
        'field': field,
      },
      post: true,
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map) {
      throw const ServerFailure(
        'Failed to clear secret: unexpected response from server.',
      );
    }

    return Map<String, dynamic>.from(raw);
  }
}
