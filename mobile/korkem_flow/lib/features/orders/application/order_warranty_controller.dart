import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/orders/data/order_warranty_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_warranty.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final orderWarrantyProvider = FutureProvider.autoDispose
    .family<OrderWarranty, String>(
      (ref, salesOrder) =>
          ref.watch(orderWarrantyRepositoryProvider).fetchWarranty(salesOrder),
    );

final orderWarrantyActionsProvider = Provider<OrderWarrantyActionsController>(
  OrderWarrantyActionsController.new,
);

class OrderWarrantyActionsController {
  const OrderWarrantyActionsController(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> claim({
    required String salesOrder,
    required String itemCode,
    required String complaint,
  }) async {
    final repo = _ref.read(orderWarrantyRepositoryProvider);
    final result = await repo.claimWarranty(
      salesOrder: salesOrder,
      itemCode: itemCode,
      complaint: complaint,
    );
    _ref.invalidate(orderWarrantyProvider(salesOrder));
    return result;
  }
}
