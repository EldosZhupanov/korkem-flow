import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/leads/domain/lead.dart';

/// Reads and writes `CRM Lead`.
class LeadRepository {
  const LeadRepository(this._client);

  static const doctype = 'CRM Lead';

  static const listFields = [
    'name',
    'status',
    'lead_name',
    'organization',
    'mobile_no',
    'email',
    'source',
    'converted',
    'modified',
  ];

  final FrappeClient _client;

  Future<List<Lead>> fetchPage({
    required int pageSize,
    int offset = 0,
    String? status,
    String? search,
    bool includeConverted = false,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: listFields,
        filters: [
          if (status != null) FrappeFilter.equals('status', status),
          // A converted lead has become a deal; leaving it in the lead list
          // makes the same customer appear to be in two places at once.
          if (!includeConverted) const FrappeFilter.equals('converted', 0),
          if (search != null && search.trim().isNotEmpty)
            FrappeFilter.like('lead_name', '%${search.trim()}%'),
        ],
        orderBy: 'modified desc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(fromJson).toList(growable: false);
  }

  Future<Lead> fetchOne(String id) async =>
      fromJson(await _client.getDoc(doctype, id));

  /// Moves a lead to a new stage. Only `status` is sent — a full `PUT` would
  /// clobber fields the list view never loaded.
  Future<void> updateStatus(String id, String status) async {
    await _client.callMethod(
      'frappe.client.set_value',
      post: true,
      params: <String, dynamic>{
        'doctype': doctype,
        'name': id,
        'fieldname': 'status',
        'value': status,
      },
    );
  }

  static Lead fromJson(Map<String, dynamic> json) {
    return Lead(
      id: '${json['name']}',
      status: json['status'] as String? ?? '',
      leadName: _text(json['lead_name']),
      organization: _text(json['organization']),
      mobileNo: _text(json['mobile_no']),
      email: _text(json['email']),
      source: _text(json['source']),
      // Frappe Check fields arrive as 0/1, and occasionally as "0"/"1".
      converted: switch (json['converted']) {
        final int value => value != 0,
        final bool value => value,
        final String value => value == '1',
        _ => false,
      },
      modified: DateTime.tryParse('${json['modified']}'),
    );
  }

  /// Frappe returns `""` for an unset Data field, which is not the same as a
  /// value and must not reach the UI as an empty line.
  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
