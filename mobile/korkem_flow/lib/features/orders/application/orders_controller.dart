import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:meta/meta.dart';

final ordersFilterProvider =
    NotifierProvider<OrdersFilterNotifier, OrdersFilter>(
      OrdersFilterNotifier.new,
    );

@immutable
class OrdersFilter {
  const OrdersFilter({this.status, this.search});

  final SalesOrderStatus? status;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is OrdersFilter && other.status == status && other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

class OrdersFilterNotifier extends Notifier<OrdersFilter> {
  @override
  OrdersFilter build() => const OrdersFilter();

  void setStatus(SalesOrderStatus? status) =>
      state = OrdersFilter(status: status, search: state.search);

  void setSearch(String? search) =>
      state = OrdersFilter(status: state.status, search: search);

  void clear() => state = const OrdersFilter();
}

final ordersControllerProvider =
    AsyncNotifierProvider<OrdersController, PagedList<SalesOrder>>(
      OrdersController.new,
    );

class OrdersController extends PagedListController<SalesOrder> {
  @override
  Future<List<SalesOrder>> fetchPage({
    required int offset,
    required int pageSize,
  }) async {
    final filter = ref.watch(ordersFilterProvider);

    final page = await ref
        .watch(salesOrderRepositoryProvider)
        .fetchPage(
          pageSize: pageSize,
          offset: offset,
          status: filter.status,
          search: filter.search,
        );

    return page.orders;
  }
}
