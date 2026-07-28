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
  @override
  Future<DashboardSummary> build() =>
      ref.read(dashboardRepositoryProvider).fetch();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}
