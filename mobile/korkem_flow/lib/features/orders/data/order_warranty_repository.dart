import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/orders/domain/order_warranty.dart';

final orderWarrantyRepositoryProvider = Provider<OrderWarrantyRepository>(
  (ref) => OrderWarrantyRepository(ref.watch(frappeClientProvider)),
);

/// Communicates with Frappe/ERPNext for Warranty status and Claims.
class OrderWarrantyRepository {
  const OrderWarrantyRepository(this._client);

  static const statusMethod = 'korkem_manufacturing.api.warranty.status';
  static const claimMethod = 'korkem_manufacturing.api.warranty.claim';

  final FrappeClient _client;

  /// Fetches warranty duration, start date, and status per item.
  Future<OrderWarranty> fetchWarranty(String salesOrder) async {
    final response = await _client.callMethod(
      statusMethod,
      params: {'sales_order': salesOrder},
    );
    final raw = response['message'] ?? response;
    if (raw is Map<String, dynamic>) {
      return OrderWarranty.fromJson(raw);
    }
    return OrderWarranty(salesOrder: salesOrder);
  }

  /// Files a warranty claim for a specific sales order item.
  Future<Map<String, dynamic>> claimWarranty({
    required String salesOrder,
    required String itemCode,
    required String complaint,
  }) async {
    final response = await _client.callMethod(
      claimMethod,
      params: {
        'sales_order': salesOrder,
        'item_code': itemCode,
        'complaint': complaint,
      },
      post: true,
    );
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }
}
