import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:meta/meta.dart';

/// One routing operation in an ERPNext `Work Order`.
@immutable
class WorkOrderOperation {
  const WorkOrderOperation({
    required this.name,
    this.operation,
    this.workstation,
    this.status,
    this.completedQty = 0,
    this.scrapQty = 0,
    this.plannedMinutes = 0,
    this.sequence,
  });

  factory WorkOrderOperation.fromJson(Map<String, dynamic> json) {
    return WorkOrderOperation(
      name: json['name'] as String? ?? '',
      operation: _text(json['operation']),
      workstation: _text(json['workstation']),
      status: _text(json['status']),
      completedQty: _number(json['completed_qty']) ?? 0,
      scrapQty: _number(json['scrap_qty']) ?? 0,
      plannedMinutes: _number(json['planned_minutes']) ?? 0,
      sequence: _int(json['sequence']),
    );
  }

  final String name;
  final String? operation;
  final String? workstation;
  final String? status;
  final double completedQty;
  final double scrapQty;
  final double plannedMinutes;
  final int? sequence;

  WorkOrderOperationStatus get statusEnum =>
      WorkOrderOperationStatus.fromWire(status);

  bool get canComplete =>
      statusEnum != WorkOrderOperationStatus.completed &&
      statusEnum != WorkOrderOperationStatus.closed &&
      statusEnum != WorkOrderOperationStatus.cancelled;

  @override
  bool operator ==(Object other) =>
      other is WorkOrderOperation && other.name == name;

  @override
  int get hashCode => name.hashCode;

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Status of one routing operation within a Work Order.
enum WorkOrderOperationStatus {
  pending('Pending', StatusIntent.neutral),
  inProgress('Work in Progress', StatusIntent.info),
  completed('Completed', StatusIntent.success),
  closed('Closed', StatusIntent.neutral),
  cancelled('Cancelled', StatusIntent.neutral);

  const WorkOrderOperationStatus(this.wireValue, this.intent);

  final String wireValue;
  final StatusIntent intent;

  static WorkOrderOperationStatus fromWire(String? value) {
    if (value == null) return WorkOrderOperationStatus.pending;
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'work in progress' ||
      'in progress' ||
      'in process' => WorkOrderOperationStatus.inProgress,
      'completed' => WorkOrderOperationStatus.completed,
      'closed' => WorkOrderOperationStatus.closed,
      'cancelled' || 'canceled' => WorkOrderOperationStatus.cancelled,
      _ => WorkOrderOperationStatus.pending,
    };
  }
}
