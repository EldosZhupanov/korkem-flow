import 'package:flutter/foundation.dart';

/// Execution lifecycle status of the assistant quality check suite.
enum AssistantCheckStatus {
  notRun,
  running,
  completed,
  failed,
}

/// A single test scenario within the workshop verification suite.
@immutable
class CheckScenario {
  const CheckScenario({
    required this.id,
    required this.name,
    required this.passed,
    this.durationSeconds,
    this.failureReason,
  });

  factory CheckScenario.fromJson(Map<String, dynamic> json) {
    final rawDuration = json['duration_seconds'] ?? json['duration'];
    final rawMs = json['duration_ms'];
    final double? duration;
    if (rawDuration is num) {
      duration = rawDuration.toDouble();
    } else if (rawMs is num) {
      duration = rawMs.toDouble() / 1000.0;
    } else {
      duration = null;
    }

    final reason = json['failure_reason'] ?? json['reason'] ?? json['error'];

    return CheckScenario(
      id: (json['id'] ?? json['key'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      passed:
          json['passed'] == true ||
          json['success'] == true ||
          json['status'] == 'passed',
      durationSeconds: duration,
      failureReason: reason?.toString(),
    );
  }

  final String id;
  final String name;
  final bool passed;
  final double? durationSeconds;
  final String? failureReason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckScenario &&
          other.id == id &&
          other.name == name &&
          other.passed == passed &&
          other.durationSeconds == durationSeconds &&
          other.failureReason == failureReason;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    passed,
    durationSeconds,
    failureReason,
  );

  @override
  String toString() =>
      'CheckScenario(id: $id, name: $name, passed: $passed, '
      'duration: $durationSeconds, failure: $failureReason)';
}

/// Summary report of the assistant quality checks.
@immutable
class AssistantCheckReport {
  const AssistantCheckReport({
    this.status = AssistantCheckStatus.notRun,
    this.lastRunAt,
    this.scenarios = const [],
  });

  const AssistantCheckReport.notRun()
    : status = AssistantCheckStatus.notRun,
      lastRunAt = null,
      scenarios = const [];

  factory AssistantCheckReport.fromJson(Map<String, dynamic> json) {
    final rawScenarios = json['scenarios'] ?? json['tests'] ?? json['items'];
    final scenarios = <CheckScenario>[];
    if (rawScenarios is List) {
      for (final item in rawScenarios) {
        if (item is Map<String, dynamic>) {
          scenarios.add(CheckScenario.fromJson(item));
        } else if (item is Map) {
          scenarios.add(
            CheckScenario.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawDate =
        json['last_run_at'] ?? json['timestamp'] ?? json['finished_at'];
    final lastRunAt = rawDate is String
        ? DateTime.tryParse(rawDate)?.toLocal()
        : null;

    final rawStatus = json['status']?.toString().toLowerCase();
    final AssistantCheckStatus status;
    if (rawStatus == 'running') {
      status = AssistantCheckStatus.running;
    } else if (rawStatus == 'failed') {
      status = AssistantCheckStatus.failed;
    } else if (scenarios.isNotEmpty || lastRunAt != null) {
      status = AssistantCheckStatus.completed;
    } else {
      status = AssistantCheckStatus.notRun;
    }

    return AssistantCheckReport(
      status: status,
      lastRunAt: lastRunAt,
      scenarios: scenarios,
    );
  }

  final AssistantCheckStatus status;
  final DateTime? lastRunAt;
  final List<CheckScenario> scenarios;

  /// The same report, marked as a run in progress.
  ///
  /// The screen has to tell «загружаю прошлый результат» apart from «прогоняю
  /// сценарии прямо сейчас»: both are waiting, but only one of them is doing
  /// what the button promises. Keeping the previous scenarios means a re-run
  /// does not blank the list it is about to replace.
  AssistantCheckReport asRunning() => AssistantCheckReport(
    status: AssistantCheckStatus.running,
    lastRunAt: lastRunAt,
    scenarios: scenarios,
  );

  /// True when a test run has been performed at least once.
  bool get hasRun => scenarios.isNotEmpty || lastRunAt != null;

  /// True when the test suite is actively executing.
  bool get isRunning => status == AssistantCheckStatus.running;

  int get totalCount => scenarios.length;

  int get passedCount => scenarios.where((s) => s.passed).length;

  int get failedCount => totalCount - passedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantCheckReport &&
          other.status == status &&
          other.lastRunAt == lastRunAt &&
          listEquals(other.scenarios, scenarios);

  @override
  int get hashCode => Object.hash(
    status,
    lastRunAt,
    Object.hashAll(scenarios),
  );

  @override
  String toString() =>
      'AssistantCheckReport(status: $status, lastRunAt: $lastRunAt, '
      'scenarios: ${scenarios.length})';
}
