import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';

/// One order, fetched through the same permission-aware endpoint the list uses.
// The generics are right there, and `FutureProviderFamily` is not exported,
// so the type this lint asks for cannot be written down.
// ignore: specify_nonobvious_property_types
final orderDetailProvider = FutureProvider.family<SalesOrder, String>(
  _fetchOrder,
);

/// Every production job raised for this order.
// The generics are right there, and `FutureProviderFamily` is not exported,
// so the type this lint asks for cannot be written down.
// ignore: specify_nonobvious_property_types
final orderWorkOrdersProvider = FutureProvider.family<List<WorkOrder>, String>(
  _fetchWorkOrders,
);

/// There is no `get_one` on the server and there should not be: a second
/// endpoint would be a second place for the company scope to be applied, and
/// the search filter already returns exactly the rows this caller may see.
///
/// The exact-name check is what turns a search back into a lookup — a search
/// for `SAL-ORD-00001` also matches `SAL-ORD-000011`, and showing the wrong
/// order confidently is worse than saying it was not found.
Future<SalesOrder> _fetchOrder(Ref ref, String name) async {
  final page = await ref
      .watch(salesOrderRepositoryProvider)
      .fetchPage(pageSize: 20, search: name);

  for (final order in page.orders) {
    if (order.name == name) return order;
  }
  throw NotFoundFailure('Sales Order $name not found');
}

/// Empty is an answer, not an absence: it means production has not been
/// started yet, and the screen says exactly that rather than showing nothing.
Future<List<WorkOrder>> _fetchWorkOrders(Ref ref, String name) async {
  final orders = await ref
      .watch(workOrderRepositoryProvider)
      .fetchForDeal(name);

  // `fetchForDeal` searches, and a search matches more than it should. The
  // server decides what may be seen; this decides what belongs here.
  return orders
      .where((order) => order.salesOrder == name)
      .toList(growable: false);
}
