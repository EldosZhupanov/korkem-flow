import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/materials/domain/material_item.dart';

@immutable
class MaterialsPage {
  const MaterialsPage({
    required this.materials,
    required this.total,
  });

  final List<MaterialItem> materials;
  final int total;
}

final materialsRepositoryProvider = Provider<MaterialsRepository>(
  (ref) => MaterialsRepository(ref.watch(frappeClientProvider)),
);

/// Client for the materials catalogue endpoint.
class MaterialsRepository {
  const MaterialsRepository(this._client);

  static const endpoint = 'korkem_manufacturing.api.catalogue.materials';

  final FrappeClient _client;

  /// Fetches a paginated slice of the materials catalogue matching the filters.
  Future<MaterialsPage> fetchMaterials({
    int limit = 20,
    int offset = 0,
    String? query,
    int? thickness,
    String? colorFamily,
    String? kind,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      'thickness': ?thickness,
      if (colorFamily != null && colorFamily.trim().isNotEmpty)
        'color_family': colorFamily.trim(),
      if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
    };

    final response = await _client.callMethod(endpoint, params: params);
    final raw = response['message'] ?? response;

    if (raw is List) {
      final items = raw
          .whereType<Map<String, dynamic>>()
          .map(MaterialItem.fromJson)
          .toList();
      return MaterialsPage(materials: items, total: items.length);
    }

    if (raw is Map<String, dynamic>) {
      final rawList = raw['materials'] ?? raw['items'] ?? raw['data'];
      final total = (raw['total'] as num?)?.toInt() ?? 0;
      if (rawList is List) {
        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map(MaterialItem.fromJson)
            .toList();
        return MaterialsPage(
          materials: items,
          total: total > 0 ? total : items.length,
        );
      }
    }

    return const MaterialsPage(materials: [], total: 0);
  }
}
