import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:meta/meta.dart';

final workOrderRepositoryProvider = Provider<WorkOrderRepository>(
  (ref) => WorkOrderRepository(ref.watch(frappeClientProvider)),
);

final productionFilterProvider =
    NotifierProvider<ProductionFilterNotifier, ProductionFilter>(
      ProductionFilterNotifier.new,
    );

@immutable
class ProductionFilter {
  const ProductionFilter({this.status, this.search});

  final WorkOrderStatus? status;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is ProductionFilter &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

class ProductionFilterNotifier extends Notifier<ProductionFilter> {
  @override
  ProductionFilter build() => const ProductionFilter();

  void setStatus(WorkOrderStatus? status) =>
      state = ProductionFilter(status: status, search: state.search);

  void setSearch(String? search) =>
      state = ProductionFilter(status: state.status, search: search);

  void clear() => state = const ProductionFilter();
}

final productionControllerProvider =
    AsyncNotifierProvider<ProductionController, PagedList<WorkOrder>>(
      ProductionController.new,
    );

class ProductionController extends PagedListController<WorkOrder> {
  @override
  Future<List<WorkOrder>> fetchPage({
    required int offset,
    required int pageSize,
  }) {
    final filter = ref.watch(productionFilterProvider);

    return ref
        .read(workOrderRepositoryProvider)
        .fetchPage(
          pageSize: pageSize,
          offset: offset,
          status: filter.status,
          search: filter.search,
        );
  }
}

/// The orders raised for one deal, for the deal's own screen.
// ignore: specify_nonobvious_property_types — the generics are right there.
final dealWorkOrdersProvider = FutureProvider.family<List<WorkOrder>, String>(
  (ref, deal) => ref.watch(workOrderRepositoryProvider).fetchForDeal(deal),
);
