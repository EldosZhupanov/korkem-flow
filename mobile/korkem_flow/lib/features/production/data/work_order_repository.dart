import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/domain/work_order_operation.dart';

/// Reads `Work Order`.
///
/// Read-only by design, and by permission: this app grants `Sales User` and
/// `Sales Manager` read on Work Order so they can answer a customer, and
/// nothing more. Production state is changed on the shop floor, through task
/// completion, not from a sales screen.
///
/// Calls `korkem_manufacturing.api.queries.work_orders`, where the session
/// company is enforced on the server rather than trusting a client parameter.
class WorkOrderRepository {
  const WorkOrderRepository(this._client);

  static const queryPath = 'korkem_manufacturing.api.queries.work_orders';

  final FrappeClient _client;

  Future<List<WorkOrder>> fetchPage({
    required int pageSize,
    int offset = 0,
    WorkOrderStatus? status,
    String? search,
  }) async {
    final response = await _client.callMethod(
      queryPath,
      params: {
        'limit': pageSize,
        'offset': offset,
        if (status != null) 'status': status.wireValue,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final raw = response['message'] ?? response;
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final list = json['orders'];
    if (list is! List) return const [];

    return list
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  Future<WorkOrder> fetchOne(String id) async {
    final list = await fetchPage(pageSize: 10, search: id);
    for (final order in list) {
      if (order.id == id) return order;
    }
    if (list.isNotEmpty) return list.first;
    throw NotFoundFailure('Work Order $id not found');
  }

  /// Every order raised for one deal / sales order.
  Future<List<WorkOrder>> fetchForDeal(String deal) async {
    return fetchPage(pageSize: 50, search: deal);
  }

  static const operationsQueryPath =
      'korkem_manufacturing.api.queries.operations';

  /// Every operation for a work order in routing sequence order.
  Future<List<WorkOrderOperation>> fetchOperations(
    String workOrder, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.callMethod(
      operationsQueryPath,
      params: {
        'work_order': workOrder,
        'limit': limit,
        'offset': offset,
      },
    );

    final raw = response['message'] ?? response;
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final list = json['operations'];
    if (list is! List) return const [];

    return list
        .whereType<Map<String, dynamic>>()
        .map(WorkOrderOperation.fromJson)
        .toList(growable: false);
  }

  static WorkOrder fromJson(Map<String, dynamic> json) {
    final salesOrder = _text(json['sales_order']);
    final originatingDeal = _text(json['originating_deal']) ?? salesOrder;

    return WorkOrder(
      id: '${json['name']}',
      status: WorkOrderStatus.fromWire(json['status'] as String?),
      qty: _number(json['qty']) ?? 0,
      producedQty: _number(json['produced_qty']) ?? 0,
      productionItem: _text(json['production_item']),
      itemName: _text(json['item_name']),
      originatingDeal: originatingDeal,
      salesOrder: salesOrder ?? originatingDeal,
      plannedEndDate: _date(json['planned_end_date']),
      actualEndDate: _date(json['actual_end_date']),
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

  static DateTime? _date(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
