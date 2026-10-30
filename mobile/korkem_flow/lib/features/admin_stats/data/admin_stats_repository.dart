import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/admin_stats/domain/admin_stats.dart';

final adminStatsRepositoryProvider = Provider<AdminStatsRepository>((ref) {
  return AdminStatsRepository(ref.watch(frappeClientProvider));
});

/// Fetches aggregation metrics for the digital administrator pipeline.
class AdminStatsRepository {
  AdminStatsRepository(this._client);

  final FrappeClient _client;

  static const statsPath = 'korkem_manufacturing.api.capture.stats';

  /// Queries outcome counts for the specified time window in days.
  Future<AdminStats> getStats({int days = 30}) async {
    final response = await _client.callMethod(
      statsPath,
      params: {'days': days},
    );
    return AdminStats.fromJson(response);
  }
}
