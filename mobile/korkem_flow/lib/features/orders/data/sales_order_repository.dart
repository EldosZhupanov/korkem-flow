import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';

final salesOrderRepositoryProvider = Provider<SalesOrderRepository>(
  (ref) => SalesOrderRepository(ref.watch(frappeClientProvider)),
);

/// Reading `Sales Order` lists through the dedicated query endpoint.
///
/// Does not call `/api/resource/Sales Order` by design: standard Frappe resource
/// queries require role-based field filtering and bypass the server-resolved
/// company scope. This calls the dedicated query method
/// `korkem_manufacturing.api.queries.sales_orders`, which enforces scope on the
/// server and formats the shape for mobile.
class SalesOrderRepository {
  const SalesOrderRepository(this._client);

  static const queryPath = 'korkem_manufacturing.api.queries.sales_orders';

  final FrappeClient _client;

  /// Fetches one page of sales orders.
  ///
  /// Deliberately accepts no company parameter: the company scope is resolved
  /// server-side from the active session.
  Future<SalesOrdersPage> fetchPage({
    required int pageSize,
    int offset = 0,
    SalesOrderStatus? status,
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
    return SalesOrdersPage.fromJson(raw);
  }
}

/// A paged response of sales orders with total count.
class SalesOrdersPage {
  const SalesOrdersPage({
    required this.orders,
    required this.total,
  });

  factory SalesOrdersPage.fromJson(Object? raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final list = json['orders'];
    final orders = list is List
        ? list
              .whereType<Map<String, dynamic>>()
              .map(SalesOrder.fromJson)
              .toList(growable: false)
        : const <SalesOrder>[];
    final total = json['total'] is num
        ? (json['total'] as num).toInt()
        : orders.length;

    return SalesOrdersPage(orders: orders, total: total);
  }

  final List<SalesOrder> orders;
  final int total;
}
