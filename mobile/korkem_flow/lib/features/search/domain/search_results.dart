import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
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
    this.films = const SearchResultSection.empty(),
    this.filmCustomers = const SearchResultSection.empty(),
  });

  const GlobalSearchResults.empty({this.query = ''})
    : orders = const SearchResultSection.empty(),
      workOrders = const SearchResultSection.empty(),
      stock = const SearchResultSection.empty(),
      films = const SearchResultSection.empty(),
      filmCustomers = const SearchResultSection.empty();

  final String query;
  final SearchResultSection<SalesOrder> orders;
  final SearchResultSection<WorkOrder> workOrders;
  final SearchResultSection<StockPosition> stock;

  /// Films by name, code, maker, surface — and the film department's
  /// customers by name or phone (owner, 12.11.2026).
  final SearchResultSection<Film> films;
  final SearchResultSection<FilmCustomer> filmCustomers;

  bool get isEmpty =>
      orders.isEmpty &&
      workOrders.isEmpty &&
      stock.isEmpty &&
      films.isEmpty &&
      filmCustomers.isEmpty;
  bool get hasAnyResults =>
      orders.isNotEmpty ||
      workOrders.isNotEmpty ||
      stock.isNotEmpty ||
      films.isNotEmpty ||
      filmCustomers.isNotEmpty;
}
