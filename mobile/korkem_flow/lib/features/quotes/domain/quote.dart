import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:meta/meta.dart';

/// An ERPNext `Quotation`.
///
/// Named "Quote" here because a `Quotation` is what the customer is sent, and
/// "quotation" reads as a document type rather than a stage of a sale.
@immutable
class Quote {
  const Quote({
    required this.id,
    required this.status,
    required this.docStatus,
    this.customerName,
    this.partyName,
    this.transactionDate,
    this.validTill,
    this.grandTotal,
    this.currency,
    this.totalQty,
  });

  final String id;
  final QuoteStatus status;

  /// Quotation is a **submittable** doctype: 0 draft, 1 submitted, 2 cancelled.
  /// The `status` field and `docstatus` can disagree — a submitted quote whose
  /// validity has lapsed reads `Expired` while `docstatus` stays 1 — so both
  /// are carried rather than one being inferred from the other.
  final int docStatus;

  final String? customerName;

  /// The linked party. `quotation_to` decides its doctype (Customer or Lead),
  /// which is why the app never assumes one.
  final String? partyName;

  final DateTime? transactionDate;
  final DateTime? validTill;
  final double? grandTotal;
  final String? currency;
  final double? totalQty;

  String get displayName => customerName ?? partyName ?? id;

  bool get isDraft => docStatus == 0;

  /// Lapsing within a week and still live — the window in which a salesperson
  /// can still save it by calling.
  bool expiresSoon(DateTime now) {
    final until = validTill;
    if (until == null || status.isClosed) return false;

    return until.isAfter(now) && until.difference(now).inDays <= 7;
  }

  bool isExpiredAt(DateTime now) {
    final until = validTill;
    if (until == null || status.isClosed) return false;
    return now.isAfter(until);
  }

  @override
  bool operator ==(Object other) => other is Quote && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The `Quotation.status` Select, verified against the doctype definition.
enum QuoteStatus {
  draft('Draft', StatusIntent.neutral),
  open('Open', StatusIntent.info),
  replied('Replied', StatusIntent.info),
  partiallyOrdered('Partially Ordered', StatusIntent.warning),
  ordered('Ordered', StatusIntent.success),
  lost('Lost', StatusIntent.danger),
  cancelled('Cancelled', StatusIntent.neutral),
  expired('Expired', StatusIntent.neutral);

  const QuoteStatus(this.wireValue, this.intent);

  final String wireValue;
  final StatusIntent intent;

  static QuoteStatus fromWire(String? value) {
    for (final status in QuoteStatus.values) {
      if (status.wireValue == value) return status;
    }
    return QuoteStatus.draft;
  }

  bool get isClosed =>
      this == ordered || this == lost || this == cancelled || this == expired;
}
