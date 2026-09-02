import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:meta/meta.dart';

/// One categorized section of the global search results.
@immutable
class SearchResultSection<T> {
  const SearchResultSection({
    required this.items,
    required this.total,
    this.error,
  });

  const SearchResultSection.empty() : items = const [], total = 0, error = null;

  const SearchResultSection.failure(Object this.error)
    : items = const [],
      total = 0;

  final List<T> items;
  final int total;
  final Object? error;

  bool get hasError => error != null;
  bool get isEmpty => items.isEmpty && !hasError;
  bool get isNotEmpty => items.isNotEmpty;
}

/// Aggregated multi-domain search result across orders, production, and
/// warehouse.
@immutable
class GlobalSearchResults {
  const GlobalSearchResults({
    required this.query,
    required this.orders,
    required this.workOrders,
    required this.stock,
  });

  const GlobalSearchResults.empty({this.query = ''})
    : orders = const SearchResultSection.empty(),
      workOrders = const SearchResultSection.empty(),
      stock = const SearchResultSection.empty();

  final String query;
  final SearchResultSection<SalesOrder> orders;
  final SearchResultSection<WorkOrder> workOrders;
  final SearchResultSection<StockPosition> stock;

  bool get isEmpty => orders.isEmpty && workOrders.isEmpty && stock.isEmpty;
  bool get hasAnyResults =>
      orders.isNotEmpty || workOrders.isNotEmpty || stock.isNotEmpty;
}
