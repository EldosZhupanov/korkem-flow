import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/mdf/domain/film_where.dart';

final filmWhereRepositoryProvider = Provider<FilmWhereRepository>(
  (ref) => FilmWhereRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmWhereProvider = FutureProvider.autoDispose
    .family<FilmWhere, String>(
      (ref, order) => ref.watch(filmWhereRepositoryProvider).where(order),
    );

/// Where to get a film the order lacks; `api/film_sourcing.py`.
class FilmWhereRepository {
  FilmWhereRepository(this._client);

  static const _base = 'korkem_manufacturing.api.film_sourcing';

  final FrappeClient _client;

  Future<FilmWhere> where(String order) async => FilmWhere.fromJson(
    _map(await _client.callMethod('$_base.where', params: {'order': order})),
  );

  /// «Есть — заказать»: so many metres from this source for the order.
  Future<FilmWhere> order({
    required String order,
    required String item,
    required String supplier,
    required double metres,
    double? priceM,
    String? comesOn,
    String? saidBy,
  }) async => FilmWhere.fromJson(
    _map(
      await _client.callMethod(
        '$_base.order',
        post: true,
        params: {
          'order': order,
          'item': item,
          'supplier': supplier,
          'metres': metres,
          'price_m': ?priceM,
          'comes_on': ?comesOn,
          'said_by': ?saidBy,
        },
      ),
    ),
  );

  /// Everyone was rung — no one has it.
  Future<FilmWhere> nowhere(String order, String item) async =>
      FilmWhere.fromJson(
        _map(
          await _client.callMethod(
            '$_base.nowhere',
            post: true,
            params: {'order': order, 'item': item},
          ),
        ),
      );

  /// The customer agreed to a look-alike: the order's film is [to] now.
  Future<FilmWhere> replace({
    required String order,
    required String from,
    required String to,
    String? reason,
  }) async => FilmWhere.fromJson(
    _map(
      await _client.callMethod(
        '$_base.replace',
        post: true,
        params: {'order': order, 'old': from, 'new': to, 'reason': ?reason},
      ),
    ),
  );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил, где взять плёнку.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
