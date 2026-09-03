import 'package:flutter/foundation.dart';

/// Configuration and secret status for TrustMe integration (contracts).
@immutable
class TrustMeConfig {
  const TrustMeConfig({
    required this.enabled,
    required this.isApiTokenConfigured,
    required this.isWebhookSecretConfigured,
    this.organizationBin,
    this.lastStatus,
    this.lastCheckedOn,
    this.lastError,
  });

  factory TrustMeConfig.fromJson(Map<String, dynamic> json) {
    final configured = json['configured'];
    final configuredMap = configured is Map ? configured : <String, dynamic>{};

    return TrustMeConfig(
      enabled: json['enabled'] == 1 || json['enabled'] == true,
      organizationBin: json['organization_bin']?.toString(),
      isApiTokenConfigured:
          configuredMap['api_token'] == true || configuredMap['api_token'] == 1,
      isWebhookSecretConfigured:
          configuredMap['webhook_secret'] == true ||
          configuredMap['webhook_secret'] == 1,
      lastStatus: json['last_status']?.toString(),
      lastCheckedOn: json['last_checked_on']?.toString(),
      lastError: json['last_error']?.toString(),
    );
  }

  final bool enabled;
  final String? organizationBin;
  final bool isApiTokenConfigured;
  final bool isWebhookSecretConfigured;
  final String? lastStatus;
  final String? lastCheckedOn;
  final String? lastError;

  TrustMeConfig copyWith({
    bool? enabled,
    String? organizationBin,
    bool? isApiTokenConfigured,
    bool? isWebhookSecretConfigured,
    String? lastStatus,
    String? lastCheckedOn,
    String? lastError,
  }) {
    return TrustMeConfig(
      enabled: enabled ?? this.enabled,
      organizationBin: organizationBin ?? this.organizationBin,
      isApiTokenConfigured: isApiTokenConfigured ?? this.isApiTokenConfigured,
      isWebhookSecretConfigured:
          isWebhookSecretConfigured ?? this.isWebhookSecretConfigured,
      lastStatus: lastStatus ?? this.lastStatus,
      lastCheckedOn: lastCheckedOn ?? this.lastCheckedOn,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrustMeConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          organizationBin == other.organizationBin &&
          isApiTokenConfigured == other.isApiTokenConfigured &&
          isWebhookSecretConfigured == other.isWebhookSecretConfigured &&
          lastStatus == other.lastStatus &&
          lastCheckedOn == other.lastCheckedOn &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
    enabled,
    organizationBin,
    isApiTokenConfigured,
    isWebhookSecretConfigured,
    lastStatus,
    lastCheckedOn,
    lastError,
  );
}

/// Configuration and secret status for Kaspi Pay integration (payments).
@immutable
class KaspiConfig {
  const KaspiConfig({
    required this.enabled,
    required this.isApiKeyConfigured,
    required this.isWebhookSecretConfigured,
    this.merchantId,
    this.lastStatus,
    this.lastCheckedOn,
    this.lastError,
  });

  factory KaspiConfig.fromJson(Map<String, dynamic> json) {
    final configured = json['configured'];
    final configuredMap = configured is Map ? configured : <String, dynamic>{};

    return KaspiConfig(
      enabled: json['enabled'] == 1 || json['enabled'] == true,
      merchantId: json['merchant_id']?.toString(),
      isApiKeyConfigured:
          configuredMap['api_key'] == true || configuredMap['api_key'] == 1,
      isWebhookSecretConfigured:
          configuredMap['webhook_secret'] == true ||
          configuredMap['webhook_secret'] == 1,
      lastStatus: json['last_status']?.toString(),
      lastCheckedOn: json['last_checked_on']?.toString(),
      lastError: json['last_error']?.toString(),
    );
  }

  final bool enabled;
  final String? merchantId;
  final bool isApiKeyConfigured;
  final bool isWebhookSecretConfigured;
  final String? lastStatus;
  final String? lastCheckedOn;
  final String? lastError;

  KaspiConfig copyWith({
    bool? enabled,
    String? merchantId,
    bool? isApiKeyConfigured,
    bool? isWebhookSecretConfigured,
    String? lastStatus,
    String? lastCheckedOn,
    String? lastError,
  }) {
    return KaspiConfig(
      enabled: enabled ?? this.enabled,
      merchantId: merchantId ?? this.merchantId,
      isApiKeyConfigured: isApiKeyConfigured ?? this.isApiKeyConfigured,
      isWebhookSecretConfigured:
          isWebhookSecretConfigured ?? this.isWebhookSecretConfigured,
      lastStatus: lastStatus ?? this.lastStatus,
      lastCheckedOn: lastCheckedOn ?? this.lastCheckedOn,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KaspiConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          merchantId == other.merchantId &&
          isApiKeyConfigured == other.isApiKeyConfigured &&
          isWebhookSecretConfigured == other.isWebhookSecretConfigured &&
          lastStatus == other.lastStatus &&
          lastCheckedOn == other.lastCheckedOn &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
    enabled,
    merchantId,
    isApiKeyConfigured,
    isWebhookSecretConfigured,
    lastStatus,
    lastCheckedOn,
    lastError,
  );
}

/// Aggregated integrations status containing TrustMe and Kaspi settings.
@immutable
class IntegrationStatus {
  const IntegrationStatus({
    required this.trustme,
    required this.kaspi,
  });

  factory IntegrationStatus.fromJson(Map<String, dynamic> json) {
    final rawTrustme = json['trustme'];
    final rawKaspi = json['kaspi'];

    return IntegrationStatus(
      trustme: rawTrustme is Map
          ? TrustMeConfig.fromJson(Map<String, dynamic>.from(rawTrustme))
          : const TrustMeConfig(
              enabled: false,
              isApiTokenConfigured: false,
              isWebhookSecretConfigured: false,
            ),
      kaspi: rawKaspi is Map
          ? KaspiConfig.fromJson(Map<String, dynamic>.from(rawKaspi))
          : const KaspiConfig(
              enabled: false,
              isApiKeyConfigured: false,
              isWebhookSecretConfigured: false,
            ),
    );
  }

  final TrustMeConfig trustme;
  final KaspiConfig kaspi;

  IntegrationStatus copyWith({
    TrustMeConfig? trustme,
    KaspiConfig? kaspi,
  }) {
    return IntegrationStatus(
      trustme: trustme ?? this.trustme,
      kaspi: kaspi ?? this.kaspi,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegrationStatus &&
          runtimeType == other.runtimeType &&
          trustme == other.trustme &&
          kaspi == other.kaspi;

  @override
  int get hashCode => Object.hash(trustme, kaspi);
}
