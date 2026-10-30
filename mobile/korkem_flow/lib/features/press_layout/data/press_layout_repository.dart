import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';

final pressLayoutRepositoryProvider = Provider<PressLayoutRepository>(
  (ref) => PressLayoutRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final orderPressLayoutProvider = FutureProvider.autoDispose
    .family<OrderPressLayout, String>(
      (ref, order) => ref.watch(pressLayoutRepositoryProvider).layout(order),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final pressSettingsProvider = FutureProvider.autoDispose<PressSettings>(
  (ref) => ref.watch(pressLayoutRepositoryProvider).settings(),
);

/// The press map of an order and the press's settings
/// (`korkem_manufacturing.api.press_layout`). The server lays it out; nothing
/// is packed here.
class PressLayoutRepository {
  PressLayoutRepository(this._client);

  static const _base = 'korkem_manufacturing.api.press_layout';

  final FrappeClient _client;

  Future<OrderPressLayout> layout(String salesOrder) async =>
      OrderPressLayout.fromJson(
        _map(
          await _client.callMethod(
            '$_base.order_layout',
            params: {'sales_order': salesOrder},
          ),
        ),
      );

  /// A manager's metres for one decor, with the reason; `null` metres puts
  /// the layout's back.
  Future<OrderPressLayout> setFilmMetres(
    String salesOrder,
    String decor, {
    double? metres,
    String? reason,
  }) async => OrderPressLayout.fromJson(
    _map(
      await _client.callMethod(
        '$_base.set_film_metres',
        post: true,
        params: {
          'sales_order': salesOrder,
          'decor': decor,
          'film_m': ?metres,
          'reason': ?reason,
        },
      ),
    ),
  );

  Future<PressSettings> settings() async =>
      PressSettings.fromJson(_map(await _client.callMethod('$_base.settings')));

  Future<PressSettings> saveSettings({
    required double lengthMm,
    required double widthMm,
    required double marginMm,
    required double gapMm,
    required List<({double filmM, double lengthMm})> sections,
  }) async => PressSettings.fromJson(
    _map(
      await _client.callMethod(
        '$_base.save_settings',
        post: true,
        params: {
          'press_length_mm': lengthMm.round(),
          'press_width_mm': widthMm.round(),
          'press_margin_mm': marginMm.round(),
          'press_gap_mm': gapMm.round(),
          'press_sections': jsonEncode([
            for (final s in sections)
              {'film_m': s.filmM, 'length_mm': s.lengthMm.round()},
          ]),
        },
      ),
    ),
  );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по раскладке пресса.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
