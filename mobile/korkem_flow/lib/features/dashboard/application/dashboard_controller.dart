import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/features/dashboard/data/dashboard_repository.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(frappeClientProvider)),
);

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSummary>(
      DashboardController.new,
    );

class DashboardController extends AsyncNotifier<DashboardSummary> {
  /// Watched, not read.
  ///
  /// The repository is rebuilt whenever the session changes, because it depends
  /// on the authenticated client. Reading it here took a one-time snapshot, so
  /// signing out and back in as somebody else left the *previous* user's counts
  /// on screen — stale, and showing figures the new viewer may not be entitled
  /// to. Watching ties this controller's lifetime to the session.
  @override
  Future<DashboardSummary> build() =>
      ref.watch(dashboardRepositoryProvider).fetch();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}
