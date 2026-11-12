import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_dept/domain/film_orders.dart';

final filmOrdersRepositoryProvider = Provider<FilmOrdersRepository>(
  (ref) => FilmOrdersRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmWantedProvider = FutureProvider.autoDispose<FilmWanted>(
  (ref) => ref.watch(filmOrdersRepositoryProvider).wanted(),
);

/// A film of a delivery: so many metres at so much a metre; for a
/// customer; answering lines of the list.
typedef FilmDeliveryLine = ({
  String item,
  double metres,
  double priceM,
  bool updatePrice,
  String? customer,
  List<String> orders,
});

/// «К заказу» and a delivery of several films —
/// `korkem_manufacturing.api.film_orders`.
class FilmOrdersRepository {
  const FilmOrdersRepository(this._client);

  static const _base = 'korkem_manufacturing.api.film_orders';

  final FrappeClient _client;

  /// The list, by supplier.
  Future<FilmWanted> wanted() async =>
      FilmWanted.fromJson(_map(await _client.callMethod('$_base.wanted')));

  /// A film to order: for a customer, or — none — for the shelf.
  Future<void> add({
    required String item,
    required double metres,
    String? customer,
    String? supplier,
  }) => _client.callMethod(
    '$_base.add',
    post: true,
    params: {
      'item': item,
      'metres': metres,
      'customer': ?customer,
      'supplier': ?supplier,
    },
  );

  /// Another number of metres.
  Future<void> update(String line, {required double metres}) =>
      _client.callMethod(
        '$_base.update',
        post: true,
        params: {'line': line, 'metres': metres},
      );

  /// Off the list: a line by its id, a film offered by itself by its item.
  Future<void> drop({String? line, String? item}) => _client.callMethod(
    '$_base.drop',
    post: true,
    params: {'line': ?line, 'item': ?item},
  );

  /// The supplier's list went out.
  Future<void> sent(String? supplier) => _client.callMethod(
    '$_base.sent',
    post: true,
    params: {'supplier': ?supplier},
  );

  /// One supplier, several films: a roll each, one delivery.
  Future<void> receiveMany({
    required String supplier,
    required List<FilmDeliveryLine> lines,
    Map<String, Object?>? delivery,
    String? receivedBy,
    String? arrivesOn,
  }) => _client.callMethod(
    '$_base.receive_many',
    post: true,
    params: {
      'supplier': supplier,
      'lines': jsonEncode([
        for (final l in lines)
          {
            'item': l.item,
            'metres': l.metres,
            'price_m': l.priceM,
            'update_price': l.updatePrice,
            'customer': ?l.customer,
            if (l.orders.isNotEmpty) 'orders': l.orders,
          },
      ]),
      if (delivery != null) 'delivery': jsonEncode(delivery),
      'received_by': ?receivedBy,
      'arrives_on': ?arrivesOn,
    },
  );

  /// The whole delivery is here.
  Future<void> arrivedBatch(String batch) => _client.callMethod(
    '$_base.arrived_batch',
    post: true,
    params: {'batch': batch},
  );

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
