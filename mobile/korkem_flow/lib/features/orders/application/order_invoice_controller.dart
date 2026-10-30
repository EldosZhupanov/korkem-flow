import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/orders/data/order_invoice_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_invoice.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final orderInvoiceProvider = FutureProvider.autoDispose
    .family<OrderInvoice, String>(
      (ref, salesOrder) =>
          ref.watch(orderInvoiceRepositoryProvider).fetchInvoice(salesOrder),
    );

final orderInvoiceActionsProvider = Provider<OrderInvoiceActionsController>(
  OrderInvoiceActionsController.new,
);

class OrderInvoiceActionsController {
  const OrderInvoiceActionsController(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> draft(String salesOrder) async {
    final repo = _ref.read(orderInvoiceRepositoryProvider);
    final result = await repo.draftInvoice(salesOrder);
    _ref.invalidate(orderInvoiceProvider(salesOrder));
    return result;
  }
}
