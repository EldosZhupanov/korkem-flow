import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:meta/meta.dart';

/// How the server read what was typed.
enum SearchKind {
  text,
  phone,
  number;

  static SearchKind parse(Object? raw) => switch (raw) {
    'phone' => phone,
    'number' => number,
    _ => text,
  };
}

/// What this person may open — the actions follow it.
@immutable
class SearchAllowed {
  const SearchAllowed({
    this.facades = false,
    this.cnc = false,
    this.film = false,
    this.filmEdit = false,
  });

  factory SearchAllowed.fromJson(Map<String, dynamic> j) => SearchAllowed(
    facades: j['facades'] == true,
    cnc: j['cnc'] == true,
    film: j['film'] == true,
    filmEdit: j['film_edit'] == true,
  );

  final bool facades;
  final bool cnc;
  final bool film;
  final bool filmEdit;
}

/// A customer found: his facade and CNC orders, what he owes, and — for the
/// film department — his card there.
@immutable
class SearchCustomer {
  const SearchCustomer({
    required this.customer,
    required this.name,
    this.phone,
    this.organization,
    this.orders = 0,
    this.debt = 0,
    this.film,
  });

  factory SearchCustomer.fromJson(Map<String, dynamic> j) => SearchCustomer(
    customer: '${j['customer']}',
    name: '${j['name'] ?? j['customer']}',
    phone: Phone.prettyOrNull(_s(j['phone'])),
    organization: _s(j['organization']),
    orders: j['orders'] is num ? (j['orders'] as num).toInt() : 0,
    debt: _d(j['debt']),
    film: j['film'] is Map
        ? FilmCustomer.fromJson(Map<String, dynamic>.from(j['film'] as Map))
        : null,
  );

  final String customer;
  final String name;
  final String? phone;
  final String? organization;
  final int orders;
  final double debt;
  final FilmCustomer? film;
}

/// A facade or CNC order found.
@immutable
class SearchOrder {
  const SearchOrder({
    required this.name,
    required this.customerName,
    required this.status,
    this.number,
    this.customer,
    this.decor,
    this.due,
    this.overdue = false,
    this.total = 0,
    this.debt = 0,
    this.cnc = false,
  });

  factory SearchOrder.fromJson(Map<String, dynamic> j, {bool cnc = false}) =>
      SearchOrder(
        name: '${j['name']}',
        number: j['number'] is num ? (j['number'] as num).toInt() : null,
        customer: _s(j['customer']),
        customerName: '${j['customer_name'] ?? ''}',
        status: '${j['status'] ?? ''}',
        decor: _s(j['decor']),
        due: _s(j['due']),
        overdue: j['overdue'] == true,
        total: _d(j['total']),
        debt: _d(j['debt']),
        cnc: cnc,
      );

  final String name;
  final int? number;
  final String? customer;
  final String customerName;

  /// The wire status: `MdfStatus` or `CncStatus` by [cnc].
  final String status;
  final String? decor;
  final String? due;
  final bool overdue;
  final double total;
  final double debt;
  final bool cnc;
}

/// A payment of a customer found.
@immutable
class SearchPayment {
  const SearchPayment({
    required this.date,
    required this.order,
    required this.customerName,
    required this.amount,
    this.method,
    this.cnc = false,
  });

  factory SearchPayment.fromJson(Map<String, dynamic> j) => SearchPayment(
    date: '${j['date'] ?? ''}',
    order: '${j['order']}',
    customerName: '${j['customer_name'] ?? ''}',
    amount: _d(j['amount']),
    method: _s(j['method']),
    cnc: j['cnc'] == true,
  );

  final String date;
  final String order;
  final String customerName;
  final double amount;
  final String? method;
  final bool cnc;
}

/// One answer of `korkem_manufacturing.api.smart_search.find`.
@immutable
class SmartSearch {
  const SmartSearch({
    this.query = '',
    this.kind = SearchKind.text,
    this.allowed = const SearchAllowed(),
    this.customers = const [],
    this.facadeOrders = const [],
    this.cncOrders = const [],
    this.payments = const [],
    this.films = const [],
    this.decors = const [],
    this.orders = const [],
    this.workOrders = const [],
    this.stock = const [],
  });

  factory SmartSearch.fromJson(Map<String, dynamic> j) {
    final parts = j['parts'] is Map
        ? Map<String, dynamic>.from(j['parts'] as Map)
        : const <String, dynamic>{};
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) => [
      for (final row in parts[key] is List ? parts[key] as List : const [])
        if (row is Map) read(Map<String, dynamic>.from(row)),
    ];
    return SmartSearch(
      query: '${j['query'] ?? ''}',
      kind: SearchKind.parse(j['kind']),
      allowed: j['allowed'] is Map
          ? SearchAllowed.fromJson(
              Map<String, dynamic>.from(j['allowed'] as Map),
            )
          : const SearchAllowed(),
      customers: list('customers', SearchCustomer.fromJson),
      facadeOrders: list('facade_orders', SearchOrder.fromJson),
      cncOrders: list('cnc_orders', (r) => SearchOrder.fromJson(r, cnc: true)),
      payments: list('payments', SearchPayment.fromJson),
      films: list('films', Film.fromJson),
      decors: list('decors', FilmDecor.fromJson),
      orders: list('orders', SalesOrder.fromJson),
      workOrders: list('work_orders', WorkOrderRepository.fromJson),
      stock: list('stock', StockPosition.fromJson),
    );
  }

  final String query;
  final SearchKind kind;
  final SearchAllowed allowed;
  final List<SearchCustomer> customers;
  final List<SearchOrder> facadeOrders;
  final List<SearchOrder> cncOrders;
  final List<SearchPayment> payments;
  final List<Film> films;
  final List<FilmDecor> decors;
  final List<SalesOrder> orders;
  final List<WorkOrder> workOrders;
  final List<StockPosition> stock;

  bool get isEmpty =>
      customers.isEmpty &&
      facadeOrders.isEmpty &&
      cncOrders.isEmpty &&
      payments.isEmpty &&
      films.isEmpty &&
      decors.isEmpty &&
      orders.isEmpty &&
      workOrders.isEmpty &&
      stock.isEmpty;
}

String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
