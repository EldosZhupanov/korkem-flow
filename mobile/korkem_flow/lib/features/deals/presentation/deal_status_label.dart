import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Presentation-only naming for a pipeline stage.
///
/// Lives here, not on [DealStatus], because the domain must not depend on the
/// localisation layer — and because the two strings serve different masters:
/// [DealStatus.wireValue] is the exact text the backend stores and must never
/// be translated, while this is the only thing a user should ever read.
extension DealStatusLabel on DealStatus {
  String label(AppLocalizations l10n) => switch (this) {
    DealStatus.qualification => l10n.dealStatusQualification,
    DealStatus.demo => l10n.dealStatusDemo,
    DealStatus.proposal => l10n.dealStatusProposal,
    DealStatus.negotiation => l10n.dealStatusNegotiation,
    DealStatus.ready => l10n.dealStatusReady,
    DealStatus.won => l10n.dealStatusWon,
    DealStatus.lost => l10n.dealStatusLost,
  };
}
