import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_sources/domain/film_source.dart';
import 'package:korkem_flow/features/film_sources/domain/film_supplier_board.dart';

final filmSourcesRepositoryProvider = Provider<FilmSourcesRepository>(
  (ref) => FilmSourcesRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmSourcesProvider = FutureProvider.autoDispose<FilmSources>(
  (ref) => ref.watch(filmSourcesRepositoryProvider).sources(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmMakerProvider = FutureProvider.autoDispose.family<FilmMaker, String>(
  (ref, name) => ref.watch(filmSourcesRepositoryProvider).maker(name),
);

/// The suppliers' board — this month's (`false`) or all time's (`true`).
// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmSupplierBoardProvider = FutureProvider.autoDispose
    .family<FilmSupplierBoard, bool>(
      (ref, allTime) =>
          ref.watch(filmSourcesRepositoryProvider).board(allTime: allTime),
    );

/// Where film is bought — `korkem_manufacturing.api.film_sources`.
class FilmSourcesRepository {
  const FilmSourcesRepository(this._client);

  static const _base = 'korkem_manufacturing.api.film_sources';

  final FrappeClient _client;

  Future<FilmSources> sources() async =>
      FilmSources.fromJson(_map(await _client.callMethod('$_base.sources')));

  /// Whose film sells best, what lies, what is on its way, what to order.
  Future<FilmSupplierBoard> board({bool allTime = false}) async =>
      FilmSupplierBoard.fromJson(
        _map(
          await _client.callMethod(
            '$_base.board',
            params: {'period': allTime ? 'all' : 'month'},
          ),
        ),
      );

  /// A new source, or — with [id] — the card of one there is. Every field
  /// of [card] is written; an empty one is cleared.
  Future<FilmSource> save({
    required String name,
    required Map<String, String> card,
    required List<String> makers,
    String? id,
  }) async => FilmSource.fromJson(
    _map(
      await _client.callMethod(
        id == null ? '$_base.add' : '$_base.set_card',
        post: true,
        params: {
          'supplier': ?id,
          'name': name,
          ...card,
          'makers': jsonEncode(makers),
        },
      ),
    ),
  );

  /// Takes a source off the list; the receipts that name it keep it.
  Future<void> remove(String id) =>
      _client.callMethod('$_base.remove', post: true, params: {'supplier': id});

  Future<FilmMaker> maker(String name) async => FilmMaker.fromJson(
    _map(await _client.callMethod('$_base.maker', params: {'name': name})),
  );

  Future<void> setMaker(String name, {String? site, String? note}) =>
      _client.callMethod(
        '$_base.set_maker',
        post: true,
        params: {'name': name, 'site': site ?? '', 'note': note ?? ''},
      );

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
