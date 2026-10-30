import 'package:korkem_flow/features/quotes/domain/quote.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Display names for `Quotation.status`.
///
/// Safe to translate for the same reason as the Work Order statuses: this is a
/// fixed Select on a vendored doctype, not an editable per-site record, so the
/// wire value and the label can diverge without the phone and the Desk
/// disagreeing about what gets written.
extension QuoteStatusLabel on QuoteStatus {
  String label(AppLocalizations l10n) => switch (this) {
    QuoteStatus.draft => l10n.qDraft,
    QuoteStatus.open => l10n.qOpen,
    QuoteStatus.replied => l10n.qReplied,
    QuoteStatus.partiallyOrdered => l10n.qPartiallyOrdered,
    QuoteStatus.ordered => l10n.qOrdered,
    QuoteStatus.lost => l10n.qLost,
    QuoteStatus.cancelled => l10n.qCancelled,
    QuoteStatus.expired => l10n.qExpired,
  };
}
