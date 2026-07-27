import 'package:korkem_flow/features/tasks/domain/task.dart';

/// Maps the raw `CRM Task` payload onto the domain model.
abstract final class TaskDto {
  static const listFields = <String>[
    'name',
    'title',
    'status',
    'priority',
    'due_date',
    'assigned_to',
    'reference_doctype',
    'reference_docname',
  ];

  static WorkTask fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['name']);
    if (id == null) {
      throw const FormatException('CRM Task payload has no numeric "name".');
    }

    return WorkTask(
      id: id,
      title: _asString(json['title']) ?? 'Untitled task',
      status: TaskStatus.fromWire(_asString(json['status'])) ?? TaskStatus.todo,
      priority:
          TaskPriority.fromWire(_asString(json['priority'])) ??
          TaskPriority.medium,
      dueDate: _asDate(json['due_date']),
      assignedTo: _asString(json['assigned_to']),
      referenceDoctype: _asString(json['reference_doctype']),
      referenceName: _asString(json['reference_docname']),
    );
  }

  /// Frappe may serialise an autoincrement name as either a JSON number or a
  /// string depending on the endpoint, so both are accepted.
  static int? _asInt(Object? value) => switch (value) {
    final int v => v,
    final String v => int.tryParse(v),
    _ => null,
  };

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _asDate(Object? value) {
    final text = _asString(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}
