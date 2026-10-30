import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/ai_settings/domain/ai_provider_config.dart';
import 'package:korkem_flow/features/ai_settings/domain/prompt_breakdown.dart';

/// The client half of the AI gateway's settings API.
///
/// Every method here names a provider. None of them sends a key anywhere except
/// to KORKEM's own backend, and none receives one back — the gateway resolves
/// credentials server-side, which is the entire reason this app can be
/// decompiled without leaking anything.
class AiSettingsRepository {
  const AiSettingsRepository(this._client);

  static const _base = 'korkem_ai.korkem_ai.settings_api';

  final FrappeClient _client;

  Future<({List<AiProviderConfig> providers, String defaultProvider})>
  list() async {
    final response = await _client.callMethod('$_base.list_providers');
    final message = response['message'] as Map? ?? const {};

    return (
      providers: [
        for (final raw in (message['providers'] as List? ?? const []))
          AiProviderConfig.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      defaultProvider: message['default_provider'] as String? ?? '',
    );
  }

  /// Saves configuration. [apiKey] is write-only and omitted when null, so
  /// changing a model does not require the caller to possess the key.
  Future<void> save({
    required String provider,
    String? model,
    String? baseUrl,
    String? apiKey,
    bool enabled = true,
  }) => _client.callMethod(
    '$_base.save_provider',
    post: true,
    params: {
      'provider': provider,
      'enabled': enabled,
      'model': ?model,
      'base_url': ?baseUrl,
      // Only when the user actually typed one. Sending an empty string would
      // ask the server to clear a working credential.
      if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
    },
  );

  /// Asks the backend to make one real call to the provider.
  ///
  /// Returns whether it worked and, when it did not, the reason code — which
  /// is what the screen words, rather than the provider's English.
  Future<({bool ok, String? code})> test(String provider) async {
    final response = await _client.callMethod(
      '$_base.test_provider',
      post: true,
      params: {'provider': provider},
    );
    final message = response['message'] as Map? ?? const {};
    return (
      ok: message['ok'] as bool? ?? false,
      code: message['code'] as String?,
    );
  }

  Future<List<String>> models(String provider) async {
    final response = await _client.callMethod(
      '$_base.list_models',
      params: {'provider': provider},
    );
    final message = response['message'] as Map? ?? const {};
    return [
      for (final raw in (message['models'] as List? ?? const []))
        (raw as Map)['id'] as String,
    ];
  }

  /// Порядок, в котором роутер будет спрашивать модели.
  ///
  /// Считает сервер тем же кодом, что и решает на самом деле. Повторить это
  /// правило здесь значило бы завести второе место, отвечающее на тот же
  /// вопрос, — и однажды они разойдутся.
  Future<List<AiCascadeStep>> cascade() async {
    final response = await _client.callMethod('$_base.cascade');
    final rows = response['message'] ?? response['data'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map((e) => AiCascadeStep.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<void> setDefault(String provider, {String? model}) =>
      _client.callMethod(
        '$_base.set_default_provider',
        post: true,
        params: {'provider': provider, 'model': ?model},
      );

  static const _usageBase = 'korkem_ai.korkem_ai.usage_api';

  /// Загружает разбивку последнего запроса по токенам и недельную сводку.
  Future<PromptBreakdownReport> promptBreakdown() async {
    final response = await _client.callMethod(
      '$_usageBase.get_prompt_breakdown',
    );
    final message = response['message'];
    if (message is Map<String, dynamic>) {
      return PromptBreakdownReport.fromJson(message);
    }
    if (message is Map) {
      return PromptBreakdownReport.fromJson(
        Map<String, dynamic>.from(message),
      );
    }
    return const PromptBreakdownReport.empty();
  }
}

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>(
  (ref) => AiSettingsRepository(ref.watch(frappeClientProvider)),
);

/// Every provider the gateway supports, with how far its setup has got.
final aiProvidersProvider =
    FutureProvider<
      ({List<AiProviderConfig> providers, String defaultProvider})
    >((ref) => ref.watch(aiSettingsRepositoryProvider).list());

/// Каскад: что спросят первым, что вторым, что когда всё кончится.
final aiCascadeProvider = FutureProvider<List<AiCascadeStep>>(
  (ref) => ref.watch(aiSettingsRepositoryProvider).cascade(),
);

/// Разбивку токенов последнего запроса и сводка использования за неделю.
final aiPromptBreakdownProvider = FutureProvider<PromptBreakdownReport>(
  (ref) => ref.watch(aiSettingsRepositoryProvider).promptBreakdown(),
);
