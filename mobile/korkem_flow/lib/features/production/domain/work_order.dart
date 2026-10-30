import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:meta/meta.dart';

/// An ERPNext `Work Order` — the manufacturing half of a Production Order.
@immutable
class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.status,
    required this.qty,
    this.producedQty = 0,
    this.productionItem,
    this.itemName,
    this.originatingDeal,
    this.salesOrder,
    this.plannedEndDate,
    this.actualEndDate,
    this.wipWarehouse,
    this.fgWarehouse,
    this.bomNo,
  });

  final String id;
  final WorkOrderStatus status;

  final double qty;
  final double producedQty;

  final String? productionItem;
  final String? itemName;

  /// The `CRM Deal` or `Sales Order` this order was raised for.
  final String? originatingDeal;
  final String? salesOrder;

  final DateTime? plannedEndDate;
  final DateTime? actualEndDate;
  final String? wipWarehouse;
  final String? fgWarehouse;
  final String? bomNo;

  /// 0–1. Guarded against a zero quantity, which would otherwise be NaN and
  /// render as a blank progress bar rather than an empty one.
  double get progress {
    if (qty <= 0) return 0;
    return (producedQty / qty).clamp(0.0, 1.0);
  }

  /// Whether this order has missed its planned end, as of [now].
  ///
  /// Takes the time rather than reading the system clock. Every other screen
  /// that reasons about lateness — quotes, approvals, the task grouping — asks
  /// `clockProvider` for it, and this was the one place that did not. The cost
  /// was invisible until a golden that had passed for days began to fail on its
  /// own: the fixture's due date arrived, and a test whose whole job is to be
  /// deterministic started reporting on the wall clock instead.
  bool isLateAt(DateTime now) {
    final planned = plannedEndDate;
    if (planned == null || status.isFinished) return false;
    return now.isAfter(planned);
  }

  @override
  bool operator ==(Object other) => other is WorkOrder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The `Work Order.status` Select, verified against the doctype definition.
///
/// A fixed Select on a vendored doctype, unlike CRM's editable stage records —
/// so an enum is right here, and an unrecognised value means the app is older
/// than the ERPNext it is talking to.
enum WorkOrderStatus {
  draft('Draft', StatusIntent.neutral),
  submitted('Submitted', StatusIntent.info),
  notStarted('Not Started', StatusIntent.neutral),
  inProcess('In Process', StatusIntent.info),
  stockReserved('Stock Reserved', StatusIntent.info),
  stockPartiallyReserved('Stock Partially Reserved', StatusIntent.warning),
  completed('Completed', StatusIntent.success),
  stopped('Stopped', StatusIntent.danger),
  closed('Closed', StatusIntent.neutral),
  cancelled('Cancelled', StatusIntent.neutral);

  const WorkOrderStatus(this.wireValue, this.intent);

  final String wireValue;
  final StatusIntent intent;

  static WorkOrderStatus fromWire(String? value) {
    for (final status in WorkOrderStatus.values) {
      if (status.wireValue == value) return status;
    }
    return WorkOrderStatus.draft;
  }

  bool get isFinished =>
      this == completed || this == closed || this == cancelled;

  /// What a factory is actually working on right now.
  bool get isActive =>
      this == inProcess ||
      this == notStarted ||
      this == submitted ||
      this == stockReserved ||
      this == stockPartiallyReserved;
}
