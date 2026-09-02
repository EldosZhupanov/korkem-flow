import 'package:korkem_flow/features/production/domain/work_order_operation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Display names for `WorkOrderOperationStatus`.
extension WorkOrderOperationStatusLabel on WorkOrderOperationStatus {
  String label(AppLocalizations l10n) => switch (this) {
    WorkOrderOperationStatus.pending => l10n.opPending,
    WorkOrderOperationStatus.inProgress => l10n.opInProgress,
    WorkOrderOperationStatus.completed => l10n.opCompleted,
    WorkOrderOperationStatus.closed => l10n.opClosed,
    WorkOrderOperationStatus.cancelled => l10n.opCancelled,
  };
}
