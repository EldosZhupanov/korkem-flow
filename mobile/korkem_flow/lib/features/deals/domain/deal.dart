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

  /// The stored stage value, kept as text rather than parsed into an enum.
  ///
  /// `CRM Deal.status` is a **Link** to `CRM Deal Status`, whose rows are
  /// editable — and `PROJECT.md`'s Production Order lifecycle names stages
  /// (Measurement, Design, Approval) this site has not configured yet. An enum
  /// would turn the day someone adds one into a silent data-loss bug. Meaning
  /// is resolved through `StatusCatalog`, which reads the same records.
  final String status;

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
