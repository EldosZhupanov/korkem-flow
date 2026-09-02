import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/domain/work_order_operation.dart';

/// One work order, fetched through the same permission-aware endpoint the list
/// uses.
// The generics are right there, and `FutureProviderFamily` is not exported,
// so the type this lint asks for cannot be written down.
// ignore: specify_nonobvious_property_types
final workOrderDetailProvider = FutureProvider.family<WorkOrder, String>(
  _fetchWorkOrder,
);

/// The operations that belong to one work order, in routing order.
// ignore: specify_nonobvious_property_types
final workOrderOperationsProvider =
    FutureProvider.family<List<WorkOrderOperation>, String>(
      _fetchOperations,
    );

/// There is no `get_one` on the server and there should not be: a second
/// endpoint would be a second place for the company scope to be applied, and
/// the search filter already returns exactly the rows this caller may see.
///
/// The exact-name check is what turns a search back into a lookup — a search
/// for `MFG-WO-00001` also matches `MFG-WO-000011`, and showing the wrong
/// order confidently is worse than saying it was not found.
Future<WorkOrder> _fetchWorkOrder(Ref ref, String id) async {
  final list = await ref
      .watch(workOrderRepositoryProvider)
      .fetchPage(pageSize: 20, search: id);

  for (final order in list) {
    if (order.id == id) return order;
  }
  throw NotFoundFailure('Work Order $id not found');
}

/// Operations for one work order. Empty list is a valid state (an order
/// may have no routing operations defined).
Future<List<WorkOrderOperation>> _fetchOperations(Ref ref, String id) =>
    ref.watch(workOrderRepositoryProvider).fetchOperations(id);
