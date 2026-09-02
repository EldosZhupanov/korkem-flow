import 'package:korkem_flow/features/production/domain/work_order_operation.dart';
import 'package:meta/meta.dart';

/// One unfinished operation waiting in a workstation's queue.
@immutable
class StationOperation {
  const StationOperation({
    required this.name,
    required this.workOrder,
    this.operation,
    this.status,
    this.completedQty = 0,
    this.plannedMinutes = 0,
    this.sequence,
    this.item,
    this.itemName,
    this.orderQty = 0,
    this.dueOn,
  });

  factory StationOperation.fromJson(Map<String, dynamic> json) {
    return StationOperation(
      name: json['name'] as String? ?? '',
      workOrder: json['work_order'] as String? ?? '',
      operation: _text(json['operation']),
      status: _text(json['status']),
      completedQty: _number(json['completed_qty']) ?? 0,
      plannedMinutes: _number(json['planned_minutes']) ?? 0,
      sequence: _int(json['sequence']),
      item: _text(json['item']),
      itemName: _text(json['item_name']),
      orderQty: _number(json['order_qty']) ?? 0,
      dueOn: _text(json['due_on']),
    );
  }

  final String name;
  final String workOrder;
  final String? operation;
  final String? status;
  final double completedQty;
  final double plannedMinutes;
  final int? sequence;
  final String? item;
  final String? itemName;
  final double orderQty;
  final String? dueOn;

  WorkOrderOperation toWorkOrderOperation() => WorkOrderOperation(
    name: name,
    operation: operation,
    status: status,
    completedQty: completedQty,
    plannedMinutes: plannedMinutes,
    sequence: sequence,
  );

  @override
  bool operator ==(Object other) =>
      other is StationOperation && other.name == name;

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
