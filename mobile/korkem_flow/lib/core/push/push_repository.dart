import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';

final pushRepositoryProvider = Provider<PushRepository>((ref) {
  return PushRepository(ref.watch(frappeClientProvider));
});

/// Адрес этого телефона на узле.
///
/// Узел — единственный, кто его получает: адрес привязывает человека к
/// устройству, и уходить куда-либо ещё ему незачем.
class PushRepository {
  const PushRepository(this._client);

  final FrappeClient _client;

  static const _registerEndpoint = 'korkem_ai.korkem_ai.push_api.register';
  static const _forgetEndpoint = 'korkem_ai.korkem_ai.push_api.forget';

  Future<void> register(String token) async {
    await _client.callMethod(
      _registerEndpoint,
      params: {'token': token},
      post: true,
    );
  }

  /// «На этот телефон больше не присылать».
  ///
  /// Зовётся до того, как выход стирает доступ: после стирания сказать об этом
  /// уже нечем, и человек, вышедший из приложения, продолжал бы получать
  /// уведомления завода до тех пор, пока на этом телефоне не войдёт кто-то ещё.
  Future<void> forget(String token) async {
    await _client.callMethod(
      _forgetEndpoint,
      params: {'token': token},
      post: true,
    );
  }
}
