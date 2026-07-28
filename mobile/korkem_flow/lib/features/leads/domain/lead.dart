import 'package:meta/meta.dart';

/// A CRM Lead — an enquiry that has not yet become a Deal.
@immutable
class Lead {
  const Lead({
    required this.id,
    required this.status,
    this.leadName,
    this.organization,
    this.mobileNo,
    this.email,
    this.source,
    this.converted = false,
    this.modified,
  });

  final String id;

  /// The stored stage value, resolved against `CRM Deal Status` /
  /// `CRM Lead Status` at render time rather than parsed into an enum — the
  /// stages are editable records, not a fixed set. See `CrmStatus`.
  final String status;

  /// `lead_name` is maintained by the backend from the name parts; it can be
  /// empty on a lead captured with only a phone number.
  final String? leadName;

  /// A plain Data field on `CRM Lead`, **not** a link to `CRM Organization` —
  /// a lead's company has no record until the lead converts.
  final String? organization;

  final String? mobileNo;
  final String? email;
  final String? source;
  final bool converted;
  final DateTime? modified;

  /// What to put on the card when the contact has no name yet.
  String get displayName {
    final name = leadName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final org = organization?.trim();
    if (org != null && org.isNotEmpty) return org;

    return mobileNo ?? email ?? id;
  }

  @override
  bool operator ==(Object other) => other is Lead && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
