import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/ai_settings/domain/assistant_check.dart';

/// Repository for running and fetching assistant quality check reports.
class AssistantCheckRepository {
  const AssistantCheckRepository(this._client);

  static const _base = 'korkem_ai.korkem_ai.assistant_check_api';

  final FrappeClient _client;

  Future<AssistantCheckReport> getLastRun() async {
    final response = await _client.callMethod('$_base.get_last_run');
    final message = response['message'] ?? response['data'];
    if (message is Map<String, dynamic>) {
      return AssistantCheckReport.fromJson(message);
    }
    if (message is Map) {
      return AssistantCheckReport.fromJson(Map<String, dynamic>.from(message));
    }
    return const AssistantCheckReport.notRun();
  }

  Future<AssistantCheckReport> runCheck() async {
    final response = await _client.callMethod(
      '$_base.run_check',
      post: true,
    );
    final message = response['message'] ?? response['data'];
    if (message is Map<String, dynamic>) {
      return AssistantCheckReport.fromJson(message);
    }
    if (message is Map) {
      return AssistantCheckReport.fromJson(Map<String, dynamic>.from(message));
    }
    return const AssistantCheckReport.notRun();
  }
}

final assistantCheckRepositoryProvider = Provider<AssistantCheckRepository>(
  (ref) => AssistantCheckRepository(ref.watch(frappeClientProvider)),
);

final assistantCheckControllerProvider =
    AsyncNotifierProvider<AssistantCheckController, AssistantCheckReport>(
      AssistantCheckController.new,
    );

class AssistantCheckController extends AsyncNotifier<AssistantCheckReport> {
  @override
  Future<AssistantCheckReport> build() =>
      ref.watch(assistantCheckRepositoryProvider).getLastRun();

  /// Triggers a test run of the assistant workshop scenarios suite.
  ///
  /// The in-progress state is carried by the report itself rather than by
  /// `AsyncLoading`, because the first load of the previous result is also
  /// `AsyncLoading` — and a screen that cannot tell the two apart announces a
  /// check it never started.
  Future<void> run() async {
    final previous = state.value ?? const AssistantCheckReport.notRun();
    state = AsyncData(previous.asRunning());
    state = await AsyncValue.guard(
      () => ref.read(assistantCheckRepositoryProvider).runCheck(),
    );
  }
}
