import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';

final filmDeptRepositoryProvider = Provider<FilmDeptRepository>(
  (ref) => FilmDeptRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmStockProvider = FutureProvider.autoDispose<FilmCatalog>(
  (ref) => ref.watch(filmDeptRepositoryProvider).stock(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmCustomersProvider = FutureProvider.autoDispose<List<FilmCustomer>>(
  (ref) => ref.watch(filmDeptRepositoryProvider).customers(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmSalesProvider = FutureProvider.autoDispose<List<FilmSale>>(
  (ref) => ref.watch(filmDeptRepositoryProvider).sales(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmHistoryProvider = FutureProvider.autoDispose
    .family<List<FilmMove>, String>(
      (ref, item) => ref.watch(filmDeptRepositoryProvider).history(item),
    );

/// The film department — `korkem_manufacturing.api.film_dept`.
class FilmDeptRepository {
  const FilmDeptRepository(this._client);

  static const _base = 'korkem_manufacturing.api.film_dept';

  final FrappeClient _client;

  /// Every film still made, with what is free; the low ones first.
  Future<FilmCatalog> stock() async =>
      FilmCatalog.fromJson(_map(await _client.callMethod('$_base.stock')));

  Future<List<FilmMove>> history(String item) async => [
    for (final r in _list(
      await _client.callMethod('$_base.history', params: {'item': item}),
    ))
      FilmMove.fromJson(r),
  ];

  Future<void> receive({
    required String item,
    required double metres,
    required double priceM,
    required String supplier,
  }) => _client.callMethod(
    '$_base.receive',
    post: true,
    params: {
      'item': item,
      'metres': metres,
      'price_m': priceM,
      'supplier': supplier,
    },
  );

  /// [lines] — the films, their metres and what a metre is charged at.
  Future<FilmSale> sell({
    required String customer,
    required List<({String item, double metres, double priceM})> lines,
    double paid = 0,
    String? method,
    String? bank,
  }) async => FilmSale.fromJson(
    _map(
      await _client.callMethod(
        '$_base.sell',
        post: true,
        params: {
          'customer': customer,
          'lines': jsonEncode([
            for (final l in lines)
              {'item': l.item, 'metres': l.metres, 'price_m': l.priceM},
          ]),
          'paid': paid,
          'method': ?method,
          'bank': ?bank,
        },
      ),
    ),
  );

  Future<void> toShop({
    required String item,
    required double metres,
    String? order,
  }) => _client.callMethod(
    '$_base.to_shop',
    post: true,
    params: {'item': item, 'metres': metres, 'order': ?order},
  );

  Future<void> writeOff({
    required String item,
    required double metres,
    required String reason,
  }) => _client.callMethod(
    '$_base.write_off',
    post: true,
    params: {'item': item, 'metres': metres, 'reason': reason},
  );

  Future<FilmSale> pay(
    String entry, {
    required double amount,
    required String method,
    String? bank,
  }) async => FilmSale.fromJson(
    _map(
      await _client.callMethod(
        '$_base.pay',
        post: true,
        params: {
          'entry': entry,
          'amount': amount,
          'method': method,
          'bank': ?bank,
        },
      ),
    ),
  );

  Future<void> cancel(String entry, String reason) => _client.callMethod(
    '$_base.cancel',
    post: true,
    params: {'entry': entry, 'reason': reason},
  );

  Future<List<FilmSale>> sales() async => [
    for (final r in _list(await _client.callMethod('$_base.sales')))
      FilmSale.fromJson(r),
  ];

  Future<FilmPrice> priceFor(String item, {String? customer}) async =>
      FilmPrice.fromJson(
        _map(
          await _client.callMethod(
            '$_base.price_for',
            params: {'item': item, 'customer': ?customer},
          ),
        ),
      );

  Future<List<FilmCustomer>> customers() async => [
    for (final r in _list(await _client.callMethod('$_base.customers')))
      FilmCustomer.fromJson(r),
  ];

  Future<void> setCustomer(
    String customer, {
    required bool wholesale,
    required double discount,
  }) => _client.callMethod(
    '$_base.set_customer',
    post: true,
    params: {
      'customer': customer,
      'tier': wholesale ? 'wholesale' : 'retail',
      'discount': discount,
    },
  );

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    return [
      for (final r in raw is List ? raw : const <Object>[])
        if (r is Map) Map<String, dynamic>.from(r),
    ];
  }
}
