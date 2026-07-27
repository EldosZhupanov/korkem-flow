import 'package:meta/meta.dart';

/// A CRM Deal, as the app understands it.
///
/// Domain model — deliberately free of Frappe's wire quirks. The mapping from
/// the raw payload lives in `DealDto`.
@immutable
class Deal {
  const Deal({
    required this.id,
    required this.organization,
    required this.status,
    this.nextStep,
    this.mobileNo,
    this.modified,
  });

  final String id;
  final String organization;
  final DealStatus status;
  final String? nextStep;

  /// Read-only in this model on purpose.
  ///
  /// `CRM Deal.mobile_no` is **derived**: `CRM Deal.validate()` recomputes it
  /// from the primary row of the `contacts` child table, so writing it directly
  /// is silently discarded by the backend. Changing a phone number means
  /// editing the contact. See docs/backend_api_audit.md §4.
  final String? mobileNo;

  final DateTime? modified;

  @override
  bool operator ==(Object other) => other is Deal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Deal pipeline stage.
///
/// These are the seeded `CRM Deal Status` values. There is no `Workflow`
/// record on this backend (verified: 0 workflows), so transitions are not
/// server-enforced — the status field accepts any configured option.
enum DealStatus {
  qualification('Qualification'),
  demo('Demo/Making'),
  proposal('Proposal/Quotation'),
  negotiation('Negotiation'),
  ready('Ready to Close'),
  won('Won'),
  lost('Lost');

  const DealStatus(this.wireValue);

  /// The exact string the backend stores. Never send the enum name.
  final String wireValue;

  static DealStatus? fromWire(String? value) {
    if (value == null) return null;
    for (final status in DealStatus.values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }

  bool get isClosed => this == DealStatus.won || this == DealStatus.lost;
}
