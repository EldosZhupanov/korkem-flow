import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/price_visibility/domain/price_visibility.dart';

final priceVisibilityRepositoryProvider = Provider<PriceVisibilityRepository>((
  ref,
) {
  return PriceVisibilityRepository(ref.watch(frappeClientProvider));
});

/// Reads and sets whether the shop floor sees prices.
class PriceVisibilityRepository {
  const PriceVisibilityRepository(this._client);

  static const _base = 'korkem_manufacturing.api.price_visibility';
  static const readEndpoint = '$_base.read';
  static const saveEndpoint = '$_base.save';

  final FrappeClient _client;

  Future<PriceVisibility> fetch() async =>
      _parsed(await _client.callMethod(readEndpoint));

  /// The server answers with the state it actually stored; that is what is
  /// shown, not the value that was sent.
  Future<PriceVisibility> save({required bool floorSeesPrices}) async {
    final response = await _client.callMethod(
      saveEndpoint,
      post: true,
      params: {'enabled': floorSeesPrices ? 1 : 0},
    );
    return _parsed(response);
  }

  PriceVisibility _parsed(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map || raw.isEmpty) {
      throw const ServerFailure('Сервер не ответил, кто видит цены.');
    }
    return PriceVisibility.fromJson(Map<String, dynamic>.from(raw));
  }
}
