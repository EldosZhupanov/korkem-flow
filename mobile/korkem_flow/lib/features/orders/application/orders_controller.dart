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
  const OrdersFilter({this.status, this.search, this.direction});

  final SalesOrderStatus? status;
  final String? search;

  /// `null` = both lines of business.
  final OrderDirection? direction;

  bool get isEmpty => status == null && search == null && direction == null;

  @override
  bool operator ==(Object other) =>
      other is OrdersFilter &&
      other.status == status &&
      other.search == search &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(status, search, direction);
}

class OrdersFilterNotifier extends Notifier<OrdersFilter> {
  @override
  OrdersFilter build() => const OrdersFilter();

  void setStatus(SalesOrderStatus? status) => state = OrdersFilter(
    status: status,
    search: state.search,
    direction: state.direction,
  );

  void setSearch(String? search) => state = OrdersFilter(
    status: state.status,
    search: search,
    direction: state.direction,
  );

  void setDirection(OrderDirection? direction) => state = OrdersFilter(
    status: state.status,
    search: state.search,
    direction: direction,
  );

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

    final repository = ref.watch(salesOrderRepositoryProvider);
    // The direction is only sent when one is chosen, so "both lines" is the
    // same request it always was.
    final page = filter.direction == null
        ? await repository.fetchPage(
            pageSize: pageSize,
            offset: offset,
            status: filter.status,
            search: filter.search,
          )
        : await repository.fetchPage(
            pageSize: pageSize,
            offset: offset,
            status: filter.status,
            search: filter.search,
            direction: filter.direction,
          );

    return page.orders;
  }
}
