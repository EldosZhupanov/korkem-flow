import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';

final filmCatalogRepositoryProvider = Provider<FilmCatalogRepository>(
  (ref) => FilmCatalogRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmCatalogProvider = FutureProvider.autoDispose<FilmCatalog>(
  (ref) => ref.watch(filmCatalogRepositoryProvider).catalog(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmChangesProvider = FutureProvider.autoDispose
    .family<List<FilmChange>, String>(
      (ref, item) => ref.watch(filmCatalogRepositoryProvider).changes(item),
    );

/// The PVC film catalogue — `korkem_manufacturing.api.film_catalog`.
class FilmCatalogRepository {
  const FilmCatalogRepository(this._client);

  static const _base = 'korkem_manufacturing.api.film_catalog';

  final FrappeClient _client;

  Future<FilmCatalog> catalog() async =>
      FilmCatalog.fromJson(_map(await _client.callMethod('$_base.catalog')));

  /// A new film of this maker; a roll is 1400 mm wide unless said.
  Future<Film> add({
    required String maker,
    required String colour,
    String? thickness,
    String? width,
    String? collection,
    Map<String, String> card = const {},
  }) async => Film.fromJson(
    _map(
      await _client.callMethod(
        '$_base.add',
        post: true,
        params: {
          'maker': maker,
          'colour': colour,
          'thickness': ?thickness,
          'width': ?width,
          'collection': ?collection,
          // Code, surface, supplier, prices — taken at once (11.11.2026).
          for (final e in card.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        },
      ),
    ),
  );

  /// Writes the fields given; a null one is cleared, a missing one kept.
  Future<Film> setCard(String item, Map<String, Object?> card) async =>
      Film.fromJson(
        _map(
          await _client.callMethod(
            '$_base.set_card',
            post: true,
            params: {
              'item': item,
              for (final e in card.entries) e.key: e.value ?? '',
            },
          ),
        ),
      );

  /// A maker's own collections: add, rename (its films follow), remove
  /// (its films stay, without one).
  Future<void> addCollection(String maker, String name) => _client.callMethod(
    '$_base.add_collection',
    post: true,
    params: {'maker': maker, 'name': name},
  );

  Future<void> renameCollection(String maker, String name, String newName) =>
      _client.callMethod(
        '$_base.rename_collection',
        post: true,
        params: {'maker': maker, 'name': name, 'new_name': newName},
      );

  Future<void> removeCollection(String maker, String name) =>
      _client.callMethod(
        '$_base.remove_collection',
        post: true,
        params: {'maker': maker, 'name': name},
      );

  /// Into the archive: off the lists, history and metres kept.
  Future<void> archive(String item) =>
      _client.callMethod('$_base.archive', post: true, params: {'item': item});

  Future<void> restore(String item) =>
      _client.callMethod('$_base.restore', post: true, params: {'item': item});

  /// Deletes a film nothing was done with; the server refuses any other.
  Future<void> delete(String item) =>
      _client.callMethod('$_base.delete', post: true, params: {'item': item});

  /// Who changed what on the film, the newest first.
  Future<List<FilmChange>> changes(String item) async {
    final response = await _client.callMethod(
      '$_base.changes',
      params: {'item': item},
    );
    return [
      for (final c in response['message'] as List? ?? const [])
        if (c is Map<String, dynamic>) FilmChange.fromJson(c),
    ];
  }

  /// Takes a colour of the old list off «не указан».
  Future<void> dropUnassigned(String colour) => _client.callMethod(
    '$_base.drop_unassigned',
    post: true,
    params: {'colour': colour},
  );

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
