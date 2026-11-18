import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/search/domain/smart_search.dart';

final smartSearchRepositoryProvider = Provider<SmartSearchRepository>(
  (ref) => SmartSearchRepository(ref.watch(frappeClientProvider)),
);

/// `korkem_manufacturing.api.smart_search` — one request for the whole
/// search window (owner, 18.11.2026, variant Б).
class SmartSearchRepository {
  const SmartSearchRepository(this._client);

  final FrappeClient _client;

  Future<SmartSearch> find(String query) async {
    final response = await _client.callMethod(
      'korkem_manufacturing.api.smart_search.find',
      params: {'q': query},
    );
    final raw = response['message'] ?? response;
    return SmartSearch.fromJson(
      raw is Map<String, dynamic> ? raw : const {},
    );
  }
}
