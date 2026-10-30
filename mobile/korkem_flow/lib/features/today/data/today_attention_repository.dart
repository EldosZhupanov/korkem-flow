import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/today/domain/today_attention.dart';

final todayAttentionRepositoryProvider = Provider<TodayAttentionRepository>(
  (ref) => TodayAttentionRepository(ref.watch(frappeClientProvider)),
);

/// Communicates with Frappe for the owner's daily attention overview.
class TodayAttentionRepository {
  const TodayAttentionRepository(this._client);

  static const todayMethod = 'korkem_manufacturing.api.attention.today';

  final FrappeClient _client;

  /// Fetches all 4 operational attention groups in a single call.
  Future<TodayAttention> fetchTodayAttention() async {
    final response = await _client.callMethod(
      todayMethod,
    );
    final raw = response['message'] ?? response;
    if (raw is Map<String, dynamic>) {
      return TodayAttention.fromJson(raw);
    }
    return const TodayAttention();
  }
}
