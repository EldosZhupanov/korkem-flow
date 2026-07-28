import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Display names for the two statuses that *are* safe to translate.
///
/// The rule that decides this: a CRM pipeline stage is an editable record, so
/// translating it would put a different word on the phone than in the Desk
/// while writing the English value back. `Pending Action.status` and
/// `Work Order.status` are fixed Selects on doctypes nobody renames per site,
/// so the wire value and the label can safely diverge — and a Russian-speaking
/// factory should not read "In Process".
extension PendingActionStatusLabel on PendingActionStatus {
  String label(AppLocalizations l10n) => switch (this) {
    PendingActionStatus.pending => l10n.paPending,
    PendingActionStatus.approved => l10n.paApproved,
    PendingActionStatus.rejected => l10n.paRejected,
    PendingActionStatus.expired => l10n.paExpired,
  };
}

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
