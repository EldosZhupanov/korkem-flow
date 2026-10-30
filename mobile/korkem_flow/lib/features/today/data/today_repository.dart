import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/today/domain/today_summary.dart';

/// Fetches the owner's daily attention summary from the backend.
class TodayRepository {
  const TodayRepository(this._client);

  static const summaryMethod = 'korkem_ai.korkem_ai.today_api.get_summary';

  final FrappeClient _client;

  Future<TodaySummary> fetchSummary() async {
    final response = await _client.callMethod(summaryMethod);
    final raw = response['message'] ?? response;
    if (raw is Map<String, dynamic>) {
      return TodaySummary.fromJson(raw);
    }
    return const TodaySummary();
  }
}

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => TodayRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type in Riverpod.
// ignore: specify_nonobvious_property_types
final todaySummaryProvider = FutureProvider.autoDispose<TodaySummary>((
  ref,
) async {
  final repo = ref.watch(todayRepositoryProvider);
  return repo.fetchSummary();
});
