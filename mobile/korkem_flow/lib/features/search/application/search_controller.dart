import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/search/domain/search_results.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';

/// Active query text in the universal search view.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  String get query => state;
  set query(String value) => state = value;
  void clear() => state = '';
}

// AutoDisposeNotifierProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

/// Aggregated multi-endpoint search results queried in parallel.
///
/// Executes 3 concurrent requests to `queries.sales_orders`,
/// `queries.work_orders`, and `queries.stock`. If one endpoint fails,
/// the others still succeed and render, while the failed domain displays
/// an isolated error state.
// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final globalSearchResultsProvider = FutureProvider.autoDispose
    .family<GlobalSearchResults, String>((
      ref,
      query,
    ) async {
      final clean = query.trim();
      if (clean.isEmpty) {
        return const GlobalSearchResults.empty();
      }

      Future<SearchResultSection<SalesOrder>> fetchOrders() async {
        try {
          final page = await ref
              .watch(salesOrderRepositoryProvider)
              .fetchPage(pageSize: 5, search: clean);
          return SearchResultSection(items: page.orders, total: page.total);
        } on Object catch (error) {
          return SearchResultSection<SalesOrder>.failure(error);
        }
      }

      Future<SearchResultSection<WorkOrder>> fetchWorkOrders() async {
        try {
          final list = await ref
              .watch(workOrderRepositoryProvider)
              .fetchPage(pageSize: 5, search: clean);
          return SearchResultSection(items: list, total: list.length);
        } on Object catch (error) {
          return SearchResultSection<WorkOrder>.failure(error);
        }
      }

      Future<SearchResultSection<StockPosition>> fetchStock() async {
        try {
          final page = await ref
              .watch(stockRepositoryProvider)
              .fetchStock(pageSize: 5, search: clean);
          return SearchResultSection(items: page.items, total: page.total);
        } on Object catch (error) {
          return SearchResultSection<StockPosition>.failure(error);
        }
      }

      // Film and its customers: matched here, from what the department
      // already lists. Somebody without the film department simply gets
      // none — not an error card.
      final needle = clean.toLowerCase();
      bool hit(Iterable<String?> fields) =>
          fields.any((f) => f != null && f.toLowerCase().contains(needle));

      Future<SearchResultSection<Film>> fetchFilms() async {
        try {
          final catalog = await ref.watch(filmDeptRepositoryProvider).stock();
          final found = [
            for (final f in catalog.films)
              if (hit([f.label, f.maker, f.colour, f.code, f.type])) f,
          ];
          return SearchResultSection(
            items: found.take(5).toList(),
            total: found.length,
          );
        } on Object {
          return const SearchResultSection<Film>.empty();
        }
      }

      Future<SearchResultSection<FilmCustomer>> fetchFilmCustomers() async {
        try {
          final all = await ref.watch(filmDeptRepositoryProvider).customers();
          final found = [
            for (final c in all)
              if (hit([c.name, c.phone])) c,
          ];
          return SearchResultSection(
            items: found.take(5).toList(),
            total: found.length,
          );
        } on Object {
          return const SearchResultSection<FilmCustomer>.empty();
        }
      }

      final results = await Future.wait<dynamic>([
        fetchOrders(),
        fetchWorkOrders(),
        fetchStock(),
        fetchFilms(),
        fetchFilmCustomers(),
      ]);

      return GlobalSearchResults(
        query: clean,
        orders: results[0] as SearchResultSection<SalesOrder>,
        workOrders: results[1] as SearchResultSection<WorkOrder>,
        stock: results[2] as SearchResultSection<StockPosition>,
        films: results[3] as SearchResultSection<Film>,
        filmCustomers: results[4] as SearchResultSection<FilmCustomer>,
      );
    });
