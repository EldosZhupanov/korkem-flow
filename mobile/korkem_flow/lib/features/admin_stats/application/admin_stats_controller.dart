import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/admin_stats/data/admin_stats_repository.dart';
import 'package:korkem_flow/features/admin_stats/domain/admin_stats.dart';

class AdminStatsDaysNotifier extends Notifier<int> {
  @override
  int build() => 30;

  void selectDays(int value) {
    if (state != value) {
      state = value;
    }
  }
}

/// The active period window in days (7, 30, 90).
final adminStatsDaysProvider = NotifierProvider<AdminStatsDaysNotifier, int>(
  AdminStatsDaysNotifier.new,
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final days = ref.watch(adminStatsDaysProvider);
  final repo = ref.watch(adminStatsRepositoryProvider);
  return repo.getStats(days: days);
});
