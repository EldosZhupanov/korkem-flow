import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';

/// Reads `Work Order`.
///
/// Read-only by design, and by permission: this app grants `Sales User` and
/// `Sales Manager` read on Work Order so they can answer a customer, and
/// nothing more. Production state is changed on the shop floor, through task
/// completion, not from a sales screen.
class WorkOrderRepository {
  const WorkOrderRepository(this._client);

  static const doctype = 'Work Order';

  static const listFields = [
    'name',
    'status',
    'production_item',
    'item_name',
    'qty',
    'produced_qty',
    'originating_deal',
    'planned_end_date',
    'actual_end_date',
    'wip_warehouse',
    'fg_warehouse',
    'bom_no',
  ];

  final FrappeClient _client;

  Future<List<WorkOrder>> fetchPage({
    required int pageSize,
    int offset = 0,
    WorkOrderStatus? status,
    String? search,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: listFields,
        filters: [
          if (status != null) FrappeFilter.equals('status', status.wireValue),
          if (search != null && search.trim().isNotEmpty)
            FrappeFilter.like('item_name', '%${search.trim()}%'),
        ],
        // Soonest deadline first. Nulls sort last in MariaDB, so undated orders
        // fall below dated ones — which is what a planner wants.
        orderBy: 'planned_end_date asc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(fromJson).toList(growable: false);
  }

  Future<WorkOrder> fetchOne(String id) async =>
      fromJson(await _client.getDoc(doctype, id));

  /// Every order raised for one deal — the CRM-to-production link, read from
  /// the custom `originating_deal` field.
  Future<List<WorkOrder>> fetchForDeal(String deal) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: listFields,
        filters: [FrappeFilter.equals('originating_deal', deal)],
        orderBy: 'creation desc',
      ),
    );

    return rows.map(fromJson).toList(growable: false);
  }

  static WorkOrder fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      id: '${json['name']}',
      status: WorkOrderStatus.fromWire(json['status'] as String?),
      qty: _number(json['qty']) ?? 0,
      producedQty: _number(json['produced_qty']) ?? 0,
      productionItem: _text(json['production_item']),
      itemName: _text(json['item_name']),
      originatingDeal: _text(json['originating_deal']),
      plannedEndDate: DateTime.tryParse('${json['planned_end_date']}'),
      actualEndDate: DateTime.tryParse('${json['actual_end_date']}'),
      wipWarehouse: _text(json['wip_warehouse']),
      fgWarehouse: _text(json['fg_warehouse']),
      bomNo: _text(json['bom_no']),
    );
  }

  /// Float fields arrive as numbers, and as strings through some code paths.
  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
