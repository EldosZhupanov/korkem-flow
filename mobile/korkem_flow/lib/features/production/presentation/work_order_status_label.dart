import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Display names for `Work Order.status`.
///
/// Safe to translate, unlike a CRM pipeline stage: this is a fixed Select on a
/// vendored doctype, not an editable per-site record, so the wire value and the
/// label can diverge without the phone and the Desk disagreeing about what
/// gets written. A Russian-speaking factory should not have to read
/// "In Process".
extension WorkOrderStatusLabel on WorkOrderStatus {
  String label(AppLocalizations l10n) => switch (this) {
    WorkOrderStatus.draft => l10n.woDraft,
    WorkOrderStatus.submitted => l10n.woSubmitted,
    WorkOrderStatus.notStarted => l10n.woNotStarted,
    WorkOrderStatus.inProcess => l10n.woInProcess,
    WorkOrderStatus.stockReserved => l10n.woStockReserved,
    WorkOrderStatus.stockPartiallyReserved => l10n.woStockPartial,
    WorkOrderStatus.completed => l10n.woCompleted,
    WorkOrderStatus.stopped => l10n.woStopped,
    WorkOrderStatus.closed => l10n.woClosed,
    WorkOrderStatus.cancelled => l10n.woCancelled,
  };
}
