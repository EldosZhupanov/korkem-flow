import 'package:meta/meta.dart';

/// A CRM Task.
///
/// Used for both sales follow-ups and shop-floor work: the backend attaches a
/// task to any doctype through `reference_doctype` / `reference_docname`, so a
/// production task is a CRM Task pointing at a Work Order.
@immutable
class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.dueDate,
    this.assignedTo,
    this.referenceDoctype,
    this.referenceName,
  });

  /// An **int**, not a String.
  ///
  /// `CRM Task` uses `naming_rule: Autoincrement`. Frappe enforces whitelisted
  /// method signatures at runtime, so sending this as a String is rejected —
  /// see `docs/backend_api_audit.md` §3.
  final int id;

  final String title;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? assignedTo;
  final String? referenceDoctype;
  final String? referenceName;

  /// True when this task tracks shop-floor work rather than a sales follow-up.
  bool get isProduction => referenceDoctype == 'Work Order';

  bool get isOverdue {
    final due = dueDate;
    if (due == null || status == TaskStatus.done) return false;
    return due.isBefore(DateTime.now());
  }

  @override
  bool operator ==(Object other) => other is WorkTask && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Verified against the `CRM Task` doctype definition.
enum TaskStatus {
  backlog('Backlog'),
  todo('Todo'),
  inProgress('In Progress'),
  done('Done'),
  canceled('Canceled');

  const TaskStatus(this.wireValue);

  final String wireValue;

  static TaskStatus? fromWire(String? value) {
    for (final status in TaskStatus.values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }

  bool get isOpen => this != TaskStatus.done && this != TaskStatus.canceled;
}

enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const TaskPriority(this.wireValue);

  final String wireValue;

  static TaskPriority? fromWire(String? value) {
    for (final priority in TaskPriority.values) {
      if (priority.wireValue == value) return priority;
    }
    return null;
  }
}
