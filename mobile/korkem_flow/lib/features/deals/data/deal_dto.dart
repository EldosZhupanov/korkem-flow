import 'package:korkem_flow/features/deals/domain/deal.dart';

/// Maps the raw `CRM Deal` payload onto the domain model.
///
/// This is the only place that knows about Frappe's wire quirks. Field names
/// were verified against live responses — docs/api_mapping.md §5.
abstract final class DealDto {
  /// Fields requested from `/api/resource/CRM Deal`.
  ///
  /// Keep in sync with [fromJson]: requesting a field that is never read costs
  /// bandwidth, reading one that is never requested yields a silent null.
  static const listFields = <String>[
    'name',
    'organization',
    'status',
    'next_step',
    'mobile_no',
    'modified',
  ];

  static Deal fromJson(Map<String, dynamic> json) {
    final id = json['name'];
    if (id == null) {
      throw const FormatException('CRM Deal payload has no "name".');
    }

    return Deal(
      // `name` is a String for CRM Deal, but not for every doctype — CRM Task
      // is autoincrement (int). Stringifying here is deliberate and safe.
      id: '$id',
      organization: _asString(json['organization']) ?? '—',
      status:
          DealStatus.fromWire(_asString(json['status'])) ??
          DealStatus.qualification,
      nextStep: _asString(json['next_step']),
      mobileNo: _asString(json['mobile_no']),
      modified: _asDate(json['modified']),
    );
  }

  /// Frappe returns empty strings rather than nulls for unset Data fields.
  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _asDate(Object? value) {
    final text = _asString(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }
}
