import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/hardware/domain/hardware_item.dart';

@immutable
class HardwarePage {
  const HardwarePage({
    required this.hardware,
    required this.total,
  });

  final List<HardwareItem> hardware;
  final int total;
}

final hardwareRepositoryProvider = Provider<HardwareRepository>(
  (ref) => HardwareRepository(ref.watch(frappeClientProvider)),
);

/// Client for the furniture hardware catalogue endpoint.
class HardwareRepository {
  const HardwareRepository(this._client);

  static const endpoint = 'korkem_manufacturing.api.materials.hardware';

  final FrappeClient _client;

  /// Fetches a paginated slice of the hardware catalogue matching the filters.
  Future<HardwarePage> fetchHardware({
    int limit = 20,
    int offset = 0,
    String? query,
    String? hardwareType,
    String? overlay,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'start': offset,
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (hardwareType != null && hardwareType.trim().isNotEmpty)
        'hardware_type': hardwareType.trim(),
      if (overlay != null && overlay.trim().isNotEmpty)
        'overlay': overlay.trim(),
    };

    final response = await _client.callMethod(endpoint, params: params);
    final raw = response['message'] ?? response;

    if (raw is List) {
      final items = raw
          .whereType<Map<String, dynamic>>()
          .map(HardwareItem.fromJson)
          .toList();
      return HardwarePage(hardware: items, total: items.length);
    }

    if (raw is Map<String, dynamic>) {
      final rawList = raw['hardware'] ?? raw['items'] ?? raw['data'];
      final total = (raw['total'] as num?)?.toInt() ?? 0;
      if (rawList is List) {
        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map(HardwareItem.fromJson)
            .toList();
        return HardwarePage(
          hardware: items,
          total: total > 0 ? total : items.length,
        );
      }
    }

    return const HardwarePage(hardware: [], total: 0);
  }
}
