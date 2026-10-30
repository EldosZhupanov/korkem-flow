import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:meta/meta.dart';

/// A pipeline stage, as the backend actually defines it.
///
/// `CRM Deal.status` and `CRM Lead.status` are **Link** fields, not Selects:
/// the stages are editable records in `CRM Deal Status` / `CRM Lead Status`.
/// Hardcoding them in the client would work right up until someone adds one —
/// and they will: `PROJECT.md`'s Production Order lifecycle has a Measurement
/// stage that this site does not yet carry.
@immutable
class CrmStatus {
  const CrmStatus({
    required this.name,
    required this.type,
    this.position = 0,
  });

  /// The exact string the backend stores. Never translated, never invented.
  final String name;

  final CrmStatusType type;

  /// Pipeline order, as configured. Drives the order of filter options so the
  /// app agrees with the Desk instead of sorting alphabetically.
  final int position;

  StatusIntent get intent => type.intent;
}

/// The semantic axis of a stage, and the only part of it the app reasons about.
///
/// Every status record carries this, which is what makes stage names safe to
/// treat as opaque data: the app never needs to know that "Ready to Close"
/// means progress, only that its type is [ongoing].
enum CrmStatusType {
  open('Open', StatusIntent.neutral),
  ongoing('Ongoing', StatusIntent.info),
  onHold('On Hold', StatusIntent.warning),
  won('Won', StatusIntent.success),
  lost('Lost', StatusIntent.danger);

  const CrmStatusType(this.wireValue, this.intent);

  final String wireValue;

  /// Mapped through the design system's intents rather than the `color` field
  /// the records also carry. Those are CRM's own palette names ("yellow",
  /// "purple") with no dark-theme variant and no measured contrast; routing
  /// through [StatusIntent] keeps the AA guarantees the theme was built for.
  final StatusIntent intent;

  static CrmStatusType fromWire(String? value) {
    for (final type in CrmStatusType.values) {
      if (type.wireValue == value) return type;
    }
    // An unrecognised type is a status the app should still display, just
    // without claiming to know what it means.
    return CrmStatusType.open;
  }

  bool get isClosed => this == won || this == lost;
}

/// The configured stages of one doctype, in pipeline order.
@immutable
class StatusCatalog {
  const StatusCatalog(this.statuses);

  static const empty = StatusCatalog([]);

  final List<CrmStatus> statuses;

  /// Looks up a stage by its stored value.
  ///
  /// Returns a neutral placeholder rather than null for a value not in the
  /// catalog: a record whose status was removed from the settings must still
  /// render, showing what it actually holds.
  CrmStatus resolve(String? name) {
    if (name == null || name.isEmpty) {
      return const CrmStatus(name: '', type: CrmStatusType.open);
    }

    for (final status in statuses) {
      if (status.name == name) return status;
    }
    return CrmStatus(name: name, type: CrmStatusType.open);
  }

  bool get isEmpty => statuses.isEmpty;
}
