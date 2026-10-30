import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Display names for `Pending Action.status`.
///
/// Safe to translate, unlike a CRM pipeline stage: this is a fixed Select on a
/// doctype this project owns, so the wire value and the label can diverge
/// without the phone and the Desk disagreeing about what gets written.
extension PendingActionStatusLabel on PendingActionStatus {
  String label(AppLocalizations l10n) => switch (this) {
    PendingActionStatus.pending => l10n.paPending,
    PendingActionStatus.approved => l10n.paApproved,
    PendingActionStatus.rejected => l10n.paRejected,
    PendingActionStatus.expired => l10n.paExpired,
  };
}
