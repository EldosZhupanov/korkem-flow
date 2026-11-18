import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';

/// One decor of a maker's catalogue (owner, 18.11.2026): the film «на глаз».
@immutable
class FilmDecor {
  const FilmDecor({
    required this.decor,
    required this.maker,
    required this.name,
    this.collection,
    this.code,
    this.thickness,
    this.hex,
    this.image,
    this.films = const [],
  });

  factory FilmDecor.fromJson(Map<String, dynamic> j) => FilmDecor(
    decor: '${j['decor']}',
    maker: '${j['maker'] ?? ''}',
    name: '${j['name'] ?? ''}',
    collection: _s(j['collection']),
    code: _s(j['code']),
    thickness: _s(j['thickness']),
    hex: _s(j['hex']),
    image: _s(j['image']),
    films: [
      for (final f in j['films'] is List ? j['films'] as List : const [])
        if (f is Map)
          (
            item: '${f['item']}',
            label: '${f['label'] ?? ''}',
            onHand: f['on_hand'] is num ? (f['on_hand'] as num).toDouble() : 0,
          ),
    ],
  );

  final String decor;
  final String maker;
  final String name;
  final String? collection;
  final String? code;
  final String? thickness;
  final String? hex;
  final String? image;

  /// The shop's films of this decor.
  final List<({String item, String label, double onHand})> films;

  int? get argb {
    final h = hex;
    if (h == null || h.length != 7) return null;
    final v = int.tryParse(h.substring(1), radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        (code?.toLowerCase().contains(q) ?? false) ||
        (collection?.toLowerCase().contains(q) ?? false);
  }
}

/// The makers' catalogues.
@immutable
class FilmDecors {
  const FilmDecors({
    required this.decors,
    required this.makers,
    this.canEdit = false,
  });

  factory FilmDecors.fromJson(Map<String, dynamic> j) => FilmDecors(
    decors: [
      for (final d in j['decors'] is List ? j['decors'] as List : const [])
        if (d is Map) FilmDecor.fromJson(Map<String, dynamic>.from(d)),
    ],
    makers: [
      for (final m in j['makers'] is List ? j['makers'] as List : const [])
        if (m is Map)
          (maker: '${m['maker']}', count: (m['count'] as num).toInt()),
    ],
    canEdit: j['can_edit'] == true,
  );

  final List<FilmDecor> decors;
  final List<({String maker, int count})> makers;
  final bool canEdit;

  List<String> collectionsOf(String maker) => {
    for (final d in decors)
      if (d.maker == maker && d.collection != null) d.collection!,
  }.toList();
}

String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

/// A picked file: a sample photo, a catalogue pack.
typedef PickedFile = ({String name, Uint8List bytes});

final filmDecorRepositoryProvider = Provider<FilmDecorRepository>(
  (ref) => FilmDecorRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmPickExtrasProvider = FutureProvider.autoDispose
    .family<FilmPickExtras, String?>((ref, customer) async {
      // Without them the window still has every film on the books: a
      // catalogue that would not load is no reason not to pick.
      try {
        return await ref
            .watch(filmDecorRepositoryProvider)
            .pickExtras(customer);
      } on Object {
        return const FilmPickExtras();
      }
    });

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmDecorsProvider = FutureProvider.autoDispose<FilmDecors>(
  (ref) => ref.watch(filmDecorRepositoryProvider).decors(),
);

/// Picks files from the computer or the phone — a seam for the tests.
final filmFilePickerProvider = Provider<FilmFilePicker>(
  (ref) => const FilmFilePicker(),
);

class FilmFilePicker {
  const FilmFilePicker();

  Future<List<PickedFile>> pick({
    required List<String> extensions,
    bool many = false,
  }) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    return [
      for (final f in many ? files : files.take(1))
        (name: f.name, bytes: await f.readAsBytes()),
    ];
  }
}

/// One decor close to a photo, or to another film (owner, 18.11.2026).
@immutable
class DecorMatch {
  const DecorMatch({
    required this.decor,
    required this.maker,
    required this.name,
    required this.distance,
    this.likeness = DecorLikeness.far,
    this.collection,
    this.code,
    this.hex,
    this.image,
    this.films = const [],
    this.onShelf = 0,
  });

  factory DecorMatch.fromJson(Map<String, dynamic> j) => DecorMatch(
    decor: '${j['decor']}',
    maker: '${j['maker'] ?? ''}',
    name: '${j['name'] ?? ''}',
    distance: j['distance'] is num ? (j['distance'] as num).toDouble() : 0,
    likeness: switch (j['likeness']) {
      'close' => DecorLikeness.close,
      'near' => DecorLikeness.near,
      _ => DecorLikeness.far,
    },
    collection: _s(j['collection']),
    code: _s(j['code']),
    hex: _s(j['hex']),
    image: _s(j['image']),
    films: [
      for (final f in j['films'] is List ? j['films'] as List : const [])
        if (f is Map)
          (
            item: '${f['item']}',
            label: '${f['label'] ?? ''}',
            free: f['free'] is num ? (f['free'] as num).toDouble() : 0.0,
          ),
    ],
    onShelf: j['on_shelf'] is num ? (j['on_shelf'] as num).toDouble() : 0,
  );

  final String decor;
  final String maker;
  final String name;

  /// ΔE with the texture's weight: under 6 the eye barely tells them apart.
  final double distance;
  final DecorLikeness likeness;
  final String? collection;
  final String? code;
  final String? hex;
  final String? image;

  /// The shop's films of this decor, with the metres free.
  final List<({String item, String label, double free})> films;
  final double onShelf;

  int? get argb {
    final h = hex;
    if (h == null || h.length != 7) return null;
    final v = int.tryParse(h.substring(1), radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }
}

/// What the order's film window shows besides the films on the books
/// (owner, 18.11.2026): the makers' catalogue decors not taken in yet, and
/// the customer's films of late.
@immutable
class FilmPickExtras {
  const FilmPickExtras({this.decors = const [], this.recent = const []});

  factory FilmPickExtras.fromJson(Map<String, dynamic> j) => FilmPickExtras(
    decors: [
      for (final d in j['decors'] is List ? j['decors'] as List : const [])
        if (d is Map) FilmDecor.fromJson(Map<String, dynamic>.from(d)),
    ],
    recent: [
      for (final r in j['recent'] is List ? j['recent'] as List : const [])
        '$r',
    ],
  );

  final List<FilmDecor> decors;
  final List<String> recent;
}

/// How close a match is, in words a seller can say to a customer.
enum DecorLikeness { close, near, far }

/// `korkem_manufacturing.api.film_decors`.
class FilmDecorRepository {
  const FilmDecorRepository(this._client);

  static const _base = 'korkem_manufacturing.api.film_decors';

  final FrappeClient _client;

  /// The decors closest to a photo of a customer's sample.
  Future<List<DecorMatch>> matchPhoto(Uint8List photo) async => _matches(
    _map(
      await _client.callMethod(
        '$_base.match_photo',
        post: true,
        params: {'content_b64': base64Encode(photo)},
      ),
    ),
    'matches',
  );

  /// A decor's or a film's look-alikes at the other makers.
  Future<List<DecorMatch>> analogues({String? decor, String? item}) async =>
      _matches(
        _map(
          await _client.callMethod(
            '$_base.analogues',
            params: {'decor': ?decor, 'item': ?item},
          ),
        ),
        'analogues',
      );

  static List<DecorMatch> _matches(Map<String, dynamic> j, String key) => [
    for (final m in j[key] is List ? j[key] as List : const [])
      if (m is Map) DecorMatch.fromJson(Map<String, dynamic>.from(m)),
  ];

  /// The film window's catalogue decors and the customer's films of late.
  Future<FilmPickExtras> pickExtras(String? customer) async =>
      FilmPickExtras.fromJson(
        _map(
          await _client.callMethod(
            'korkem_manufacturing.api.film_picker.extras',
            params: {'customer': ?customer},
          ),
        ),
      );

  /// A catalogue decor picked for an order: its film's name, taken in.
  Future<String> takeDecor(String decor) async {
    final j = _map(
      await _client.callMethod(
        'korkem_manufacturing.api.film_picker.take',
        post: true,
        params: {'decor': decor},
      ),
    );
    return '${j['label']}';
  }

  Future<FilmDecors> decors() async =>
      FilmDecors.fromJson(_map(await _client.callMethod('$_base.decors')));

  Future<Map<String, dynamic>> importPack(Uint8List zip) async => _map(
    await _client.callMethod(
      '$_base.import_pack',
      post: true,
      params: {'content_b64': base64Encode(zip)},
    ),
  );

  Future<Film> fromDecor(
    String decor, {
    String? thickness,
    String? width,
  }) async => Film.fromJson(
    _map(
      await _client.callMethod(
        '$_base.from_decor',
        post: true,
        params: {
          'decor': decor,
          'thickness': ?thickness,
          'width': ?width,
        },
      ),
    ),
  );

  Future<Film> setFilmImage(String item, PickedFile file) async =>
      Film.fromJson(
        _map(
          await _client.callMethod(
            '$_base.set_film_image',
            post: true,
            params: {
              'item': item,
              'file_name': file.name,
              'content_b64': base64Encode(file.bytes),
            },
          ),
        ),
      );

  Future<Film> clearFilmImage(String item) async => Film.fromJson(
    _map(
      await _client.callMethod(
        '$_base.clear_film_image',
        post: true,
        params: {'item': item},
      ),
    ),
  );

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
