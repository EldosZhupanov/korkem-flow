import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/customers/domain/customer.dart';

/// Reads `CRM Organization`.
class CustomerRepository {
  const CustomerRepository(this._client);

  static const doctype = 'CRM Organization';

  static const listFields = [
    'name',
    'organization_name',
    'industry',
    'territory',
    'website',
    'no_of_employees',
    'annual_revenue',
    'currency',
    'modified',
  ];

  final FrappeClient _client;

  Future<List<Customer>> fetchPage({
    required int pageSize,
    int offset = 0,
    String? industry,
    String? search,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: listFields,
        filters: [
          if (industry != null) FrappeFilter.equals('industry', industry),
          if (search != null && search.trim().isNotEmpty)
            FrappeFilter.like('organization_name', '%${search.trim()}%'),
        ],
        orderBy: 'modified desc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(fromJson).toList(growable: false);
  }

  Future<Customer> fetchOne(String id) async =>
      fromJson(await _client.getDoc(doctype, id));

  static Customer fromJson(Map<String, dynamic> json) {
    final id = '${json['name']}';

    return Customer(
      id: id,
      // The doctype is named `field:organization_name`, so the two normally
      // agree — but a list query that omitted the field would otherwise render
      // a blank card, and the id is always present.
      name: _text(json['organization_name']) ?? id,
      industry: _text(json['industry']),
      territory: _text(json['territory']),
      website: _text(json['website']),
      employeeCount: _text(json['no_of_employees']),
      annualRevenue: switch (json['annual_revenue']) {
        final num value => value.toDouble(),
        final String value => double.tryParse(value),
        _ => null,
      },
      currency: _text(json['currency']),
      modified: DateTime.tryParse('${json['modified']}'),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
