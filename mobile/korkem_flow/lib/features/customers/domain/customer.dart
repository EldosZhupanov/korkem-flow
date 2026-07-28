import 'package:meta/meta.dart';

/// A `CRM Organization` — the company side of a customer relationship.
///
/// Named "Customer" in the UI because that is what the business calls it. It is
/// deliberately **not** ERPNext's `Customer` doctype: that one has 2 DocPerms
/// with `read = 0` on this site, so no mobile role can read it
/// (docs/backend_api_audit.md §5). `CRM Organization` is what deals actually
/// link to.
@immutable
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.industry,
    this.territory,
    this.website,
    this.employeeCount,
    this.annualRevenue,
    this.currency,
    this.modified,
  });

  /// `CRM Organization` is named `field:organization_name`, so the id *is* the
  /// company name. Kept separate anyway: renaming an organisation would change
  /// the id, and code that conflates the two breaks silently when it happens.
  final String id;

  final String name;
  final String? industry;
  final String? territory;
  final String? website;

  /// A bucket like `11-50`, not a number — the field is a Select.
  final String? employeeCount;

  final double? annualRevenue;
  final String? currency;
  final DateTime? modified;

  @override
  bool operator ==(Object other) => other is Customer && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
