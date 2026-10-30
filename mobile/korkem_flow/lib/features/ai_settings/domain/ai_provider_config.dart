import 'package:meta/meta.dart';

/// One provider as the gateway describes it.
///
/// Note what is *not* here: the API key. The server sends [maskedKey] — enough
/// to recognise which account is configured, useless to anyone who intercepts
/// it — and nothing in this app ever holds the real one. A key travels in one
/// direction only.
@immutable
class AiProviderConfig {
  const AiProviderConfig({
    required this.provider,
    required this.enabled,
    required this.configured,
    required this.isDefault,
    required this.hasKey,
    required this.needsKey,
    required this.needsBaseUrl,
    required this.capabilities,
    this.model,
    this.baseUrl,
    this.maskedKey,
    this.lastTestOk = false,
    this.lastTestError,
  });

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) =>
      AiProviderConfig(
        provider: json['provider'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        configured: json['configured'] as bool? ?? false,
        isDefault: json['is_default'] as bool? ?? false,
        hasKey: json['has_key'] as bool? ?? false,
        needsKey: json['needs_key'] as bool? ?? false,
        needsBaseUrl: json['needs_base_url'] as bool? ?? false,
        model: json['model'] as String?,
        baseUrl: json['base_url'] as String?,
        maskedKey: json['masked_key'] as String?,
        lastTestOk: json['last_test_ok'] as bool? ?? false,
        lastTestError: json['last_test_error'] as String?,
        capabilities: {
          for (final entry
              in (json['capabilities'] as Map? ?? const {}).entries)
            '${entry.key}': '${entry.value}',
        },
      );

  final String provider;
  final bool enabled;

  /// True once the operator has saved a row for this provider. A provider that
  /// is merely *supported* is offered but not yet set up.
  final bool configured;
  final bool isDefault;
  final bool hasKey;

  /// Whether this provider needs a key at all — Ollama runs locally and does
  /// not, so demanding one would be a wrong error message.
  final bool needsKey;
  final bool needsBaseUrl;

  final String? model;
  final String? baseUrl;
  final String? maskedKey;
  final bool lastTestOk;
  final String? lastTestError;

  /// Capability name to `yes` / `no` / `unknown`.
  ///
  /// Three-valued on purpose: `unknown` means nobody has verified it, which is
  /// different from `no` and must not be rendered as either. Ollama's tool
  /// support is the live example.
  final Map<String, String> capabilities;

  bool get ready => configured && enabled && (hasKey || !needsKey);
}

/// Один шаг каскада: какую модель спросят и что с ней было в прошлый раз.
@immutable
class AiCascadeStep {
  const AiCascadeStep({
    required this.position,
    required this.provider,
    required this.model,
    required this.free,
    required this.lastOk,
    required this.lastError,
  });

  factory AiCascadeStep.fromJson(Map<String, dynamic> json) {
    return AiCascadeStep(
      position: switch (json['position']) {
        final int value => value,
        final String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
      provider: '${json['provider'] ?? ''}',
      model: '${json['model'] ?? ''}',
      free: json['free'] == true || json['free'] == 1,
      lastOk: json['last_ok'] == true || json['last_ok'] == 1,
      lastError: '${json['last_error'] ?? ''}',
    );
  }

  final int position;
  final String provider;
  final String model;

  /// Бесплатный по цене, записанной в самом провайдере.
  final bool free;

  /// Чем закончилось последнее обращение. Владелец должен видеть, какая модель
  /// кончилась, не открывая журналов сервера.
  final bool lastOk;
  final String lastError;
}
