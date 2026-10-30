import 'package:meta/meta.dart';

/// The home screen's data, as one value.
@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.user,
    required this.metrics,
    this.attention = const [],
  });

  final String user;

  /// Keyed by metric name. A **missing or null** entry means the signed-in user
  /// has no permission to see that number — which is not the same as zero, and
  /// is rendered as a dash rather than a confident `0`.
  final Map<String, int?> metrics;

  final List<AttentionItem> attention;

  int? operator [](String metric) => metrics[metric];

  /// Metric keys, matching `korkem_ai.korkem_ai.dashboard.get_summary`.
  static const openDeals = 'open_deals';
  static const openLeads = 'open_leads';
  static const myOpenTasks = 'my_open_tasks';
  static const overdueTasks = 'overdue_tasks';
  static const pendingActions = 'pending_actions';
  static const workOrdersInProgress = 'work_orders_in_progress';
}

/// One row of "look at this first".
@immutable
class AttentionItem {
  const AttentionItem({
    required this.kind,
    required this.name,
    required this.title,
    this.subtitle,
    this.due,
  });

  final AttentionKind kind;

  /// The docname, as a string. `CRM Task` names are integers on the wire, so
  /// this is deliberately not typed as one.
  final String name;

  final String title;
  final String? subtitle;
  final DateTime? due;
}

enum AttentionKind {
  /// An AI agent is blocked waiting on a human decision.
  pendingAction('pending_action'),

  overdueTask('overdue_task');

  const AttentionKind(this.wireValue);

  final String wireValue;

  static AttentionKind? fromWire(String? value) {
    for (final kind in AttentionKind.values) {
      if (kind.wireValue == value) return kind;
    }
    return null;
  }
}
