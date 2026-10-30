import 'dart:async';

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

final AsyncNotifierProvider<AssistantCheckController, AssistantCheckReport>
assistantCheckControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AssistantCheckController,
      AssistantCheckReport
    >(
      AssistantCheckController.new,
    );

class AssistantCheckController extends AsyncNotifier<AssistantCheckReport> {
  static const pollInterval = Duration(seconds: 2);
  static const pollCeiling = Duration(minutes: 3);

  Timer? _pollTimer;
  Timer? _ceilingTimer;
  bool _isDisposed = false;
  bool _isFetching = false;

  @override
  Future<AssistantCheckReport> build() async {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _stopPolling();
    });

    final report = await ref
        .watch(assistantCheckRepositoryProvider)
        .getLastRun();
    if (report.isRunning) {
      _startPolling();
    }
    return report;
  }

  /// Triggers a test run of the assistant workshop scenarios suite.
  ///
  /// The in-progress state is carried by the report itself rather than by
  /// `AsyncLoading`, because the first load of the previous result is also
  /// `AsyncLoading` — and a screen that cannot tell the two apart announces a
  /// check it never started.
  Future<void> run() async {
    _stopPolling();
    final previous = state.value ?? const AssistantCheckReport.notRun();
    state = AsyncData(previous.asRunning());

    final runResult = await AsyncValue.guard(
      () => ref.read(assistantCheckRepositoryProvider).runCheck(),
    );

    if (_isDisposed) return;
    state = runResult;

    if (runResult.hasValue && runResult.value!.isRunning) {
      _startPolling();
    }
  }

  void _startPolling() {
    _stopPolling();

    _ceilingTimer = Timer(pollCeiling, () {
      _stopPolling();
      if (_isDisposed) return;
      final current = state.value ?? const AssistantCheckReport.notRun();
      state = AsyncData(current.asTimedOut());
    });

    _pollTimer = Timer.periodic(pollInterval, (_) async {
      if (_isDisposed || _isFetching || _pollTimer == null) return;
      _isFetching = true;
      try {
        final report = await ref
            .read(assistantCheckRepositoryProvider)
            .getLastRun();
        if (_isDisposed || _pollTimer == null) return;

        if (!report.isRunning) {
          _stopPolling();
        }
        state = AsyncData(report);
      } on Object catch (error, stackTrace) {
        if (_isDisposed || _pollTimer == null) return;
        _stopPolling();
        state = AsyncError(error, stackTrace);
      } finally {
        _isFetching = false;
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _ceilingTimer?.cancel();
    _ceilingTimer = null;
  }
}
