import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/deals/data/deal_dto.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';

/// Reads and writes `CRM Deal`.
///
/// Returns domain models, never DTOs or raw maps — the boundary that keeps
/// Frappe's wire format out of the UI.
class DealRepository {
  const DealRepository(this._client);

  static const doctype = 'CRM Deal';

  final FrappeClient _client;

  /// One page of deals, newest activity first.
  Future<List<Deal>> fetchPage({
    required int pageSize,
    int offset = 0,
    String? status,
    String? search,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: DealDto.listFields,
        filters: [
          if (status != null) FrappeFilter.equals('status', status),
          if (search != null && search.trim().isNotEmpty)
            FrappeFilter.like('organization', '%${search.trim()}%'),
        ],
        orderBy: 'modified desc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(DealDto.fromJson).toList(growable: false);
  }

  Future<Deal> fetchOne(String id) async {
    final json = await _client.getDoc(doctype, id);
    return DealDto.fromJson(json);
  }

  /// Moves a deal to a new pipeline stage.
  ///
  /// Only `status` is sent. Frappe merges a partial payload on `PUT`, and
  /// sending the whole document would risk clobbering fields the app never
  /// loaded — including `mobile_no`, which the backend derives.
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
}
