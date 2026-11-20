import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';

final paintCatalogueRepositoryProvider = Provider<PaintCatalogueRepository>(
  (ref) => PaintCatalogueRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final paintCatalogueProvider = FutureProvider.autoDispose<PaintCatalogue>(
  (ref) => ref.watch(paintCatalogueRepositoryProvider).catalogue(),
);

/// The catalogue for an order's paint window: with what its customer had
/// painted before.
// ignore: specify_nonobvious_property_types
final paintCatalogueForProvider = FutureProvider.autoDispose
    .family<PaintCatalogue, String?>(
      (ref, customer) => ref
          .watch(paintCatalogueRepositoryProvider)
          .catalogue(customer: customer),
    );

/// The colours nearest one colour — «Похожие».
// ignore: specify_nonobvious_property_types
final paintSimilarProvider = FutureProvider.autoDispose
    .family<List<PaintColour>, String>(
      (ref, colour) =>
          ref.watch(paintCatalogueRepositoryProvider).similar(colour: colour),
    );

/// What to offer for a colour of an order no supplier has.
typedef PaintSwapOptions = ({String? hex, List<PaintColour> similar});

/// The words for the customer and whom to send them.
typedef PaintSwapAsked = ({String message, String? phone});

/// «Каталог красок» and «Замена цвета» —
/// `korkem_manufacturing.api.paint_catalogue`, `…api.paint_swap`.
class PaintCatalogueRepository {
  const PaintCatalogueRepository(this._client);

  static const _base = 'korkem_manufacturing.api.paint_catalogue';
  static const _swap = 'korkem_manufacturing.api.paint_swap';

  final FrappeClient _client;

  Future<PaintCatalogue> catalogue({String? customer}) async =>
      PaintCatalogue.fromJson(
        _map(
          await _client.callMethod(
            '$_base.catalogue',
            params: {'customer': ?customer},
          ),
        ),
      );

  /// A colour picked for an order: into work on the way; the name the
  /// «Краска» list keeps it under.
  Future<String> pick(String value, {String? system}) async {
    final m = _map(
      await _client.callMethod(
        '$_base.pick',
        post: true,
        params: {'value': value, 'system': ?system},
      ),
    );
    return '${m['value']}';
  }

  /// A catalogue colour into work: onto the «Краска» list.
  Future<String> take(String value, {String? system}) async {
    final m = _map(
      await _client.callMethod(
        '$_base.take',
        post: true,
        params: {'value': value, 'system': ?system},
      ),
    );
    return '${m['value']}';
  }

  Future<void> addColour({
    required String name,
    required String system,
    String? code,
    String? hex,
    String? note,
  }) => _client.callMethod(
    '$_base.add_colour',
    post: true,
    params: {
      'name': name,
      'system': system,
      'code': ?code,
      'hex': ?hex,
      'note': ?note,
    },
  );

  /// A colour's own card; a field left null stays as it is.
  Future<void> setColour(
    String key, {
    String? title,
    String? hex,
    bool? starred,
    bool? hidden,
    String? note,
  }) => _client.callMethod(
    '$_base.set_colour',
    post: true,
    params: {
      'key': key,
      'title': ?title,
      'hex': ?hex,
      if (starred != null) 'starred': starred ? 1 : 0,
      if (hidden != null) 'hidden': hidden ? 1 : 0,
      'note': ?note,
    },
  );

  Future<List<PaintColour>> similar({String? colour, String? hex}) async =>
      _colours(
        _map(
          await _client.callMethod(
            '$_base.similar',
            params: {'colour': ?colour, 'hex': ?hex},
          ),
        )['similar'],
      );

  Future<List<PaintColour>> matchPhoto(Uint8List photo) async => _colours(
    _map(
      await _client.callMethod(
        '$_base.match_photo',
        post: true,
        params: {'content_b64': base64Encode(photo)},
      ),
    )['similar'],
  );

  Future<PaintSwapOptions> swapOptions(String order, String colour) async {
    final m = _map(
      await _client.callMethod(
        '$_swap.options',
        params: {'order': order, 'colour': colour},
      ),
    );
    final hex = m['hex'];
    return (
      hex: hex is String && hex.isNotEmpty ? hex : null,
      similar: _colours(m['similar']),
    );
  }

  Future<PaintSwapAsked> proposeSwap(
    String order,
    String colour,
    PaintSwapWay way, {
    String? to,
    String? waitUntil,
  }) async {
    final m = _map(
      await _client.callMethod(
        '$_swap.propose',
        post: true,
        params: {
          'order': order,
          'colour': colour,
          'how': way.name,
          'to': ?to,
          'wait_until': ?waitUntil,
        },
      ),
    );
    final phone = m['phone'];
    return (
      message: '${m['message'] ?? ''}',
      phone: phone is String && phone.isNotEmpty ? phone : null,
    );
  }

  Future<void> agreeSwap(
    String order,
    String colour, {
    String via = 'phone',
    String? who,
  }) => _client.callMethod(
    '$_swap.agree',
    post: true,
    params: {'order': order, 'colour': colour, 'via': via, 'who': ?who},
  );

  Future<void> cancelSwap(String order, String colour) => _client.callMethod(
    '$_swap.cancel',
    post: true,
    params: {'order': order, 'colour': colour},
  );

  static List<PaintColour> _colours(Object? raw) => [
    for (final c in raw is List ? raw : const [])
      if (c is Map<String, dynamic>) PaintColour.fromJson(c),
  ];

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
