import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';

/// Reads the configured pipeline stages of a CRM doctype.
class StatusCatalogRepository {
  const StatusCatalogRepository(this._client);

  static const dealStatusDoctype = 'CRM Deal Status';
  static const leadStatusDoctype = 'CRM Lead Status';

  final FrappeClient _client;

  Future<StatusCatalog> fetch(String doctype) async {
    final rows = await _client.getList(
      doctype,
      const FrappeQuery(
        fields: ['name', 'type', 'position'],
        orderBy: 'position asc',
        // The catalogue is a handful of rows and the UI needs all of them; a
        // partial list would silently hide stages from the filter sheet.
        limitPageLength: 0,
      ),
    );

    return StatusCatalog(
      rows
          .map(
            (row) => CrmStatus(
              name: '${row['name']}',
              type: CrmStatusType.fromWire(row['type'] as String?),
              position: switch (row['position']) {
                final int value => value,
                final String value => int.tryParse(value) ?? 0,
                _ => 0,
              },
            ),
          )
          .toList(growable: false),
    );
  }
}
