import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/material_stock/domain/material_stock.dart';

final materialStockRepositoryProvider = Provider<MaterialStockRepository>((
  ref,
) {
  return MaterialStockRepository(
    ref.watch(frappeClientProvider),
    ref.watch(mutationOutboxProvider),
  );
});

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final materialListsProvider = FutureProvider.autoDispose<MaterialLists>(
  (ref) => ref.watch(materialStockRepositoryProvider).lists(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final stockMaterialsProvider = FutureProvider.autoDispose<List<StockMaterial>>(
  (ref) => ref.watch(materialStockRepositoryProvider).materials(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final facadeMaterialsProvider = FutureProvider.autoDispose
    .family<FacadeMaterials, String>(
      (ref, order) =>
          ref.watch(materialStockRepositoryProvider).facadeMaterials(order),
    );

/// The materials store. Stock and average price are ERPNext's figures.
class MaterialStockRepository {
  MaterialStockRepository(this._client, [MutationOutbox? outbox])
    : _outbox = outbox ?? MutationOutbox();

  static const _base = 'korkem_manufacturing.api.material_stock';

  final FrappeClient _client;
  final MutationOutbox _outbox;

  Future<MaterialLists> lists() async =>
      MaterialLists.fromJson(_map(await _client.callMethod('$_base.lists')));

  Future<MaterialLists> addOption(String list, String value) async =>
      MaterialLists.fromJson(
        _map(
          await _client.callMethod(
            '$_base.add_option',
            post: true,
            params: {'kind': list, 'value': value},
          ),
        ),
      );

  Future<MaterialLists> removeOption(String option) async =>
      MaterialLists.fromJson(
        _map(
          await _client.callMethod(
            '$_base.remove_option',
            post: true,
            params: {'option': option},
          ),
        ),
      );

  Future<MaterialLists> addSupplier(String name) async =>
      MaterialLists.fromJson(
        _map(
          await _client.callMethod(
            '$_base.add_supplier',
            post: true,
            params: {'name': name},
          ),
        ),
      );

  Future<MaterialLists> disableSupplier(String supplier) async =>
      MaterialLists.fromJson(
        _map(
          await _client.callMethod(
            '$_base.disable_supplier',
            post: true,
            params: {'supplier': supplier},
          ),
        ),
      );

  /// «Текстурная»: the film's parts are laid out on the press unturned.
  Future<void> setFilmTextured(String item, {required bool textured}) async {
    await _client.callMethod(
      '$_base.set_film_textured',
      post: true,
      params: {'item': item, 'textured': textured ? 1 : 0},
    );
  }

  /// «Минимум на складе»: below it the owner is warned. 0 turns it off.
  Future<void> setMinStock(String item, double minimum) async {
    await _client.callMethod(
      '$_base.set_min_stock',
      post: true,
      params: {'item': item, 'minimum': minimum},
    );
  }

  Future<List<StockMaterial>> materials() async {
    final data = _map(await _client.callMethod('$_base.materials'));
    return [
      for (final row in data['materials'] as List? ?? const [])
        if (row is Map) StockMaterial.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// The material described by these values — created on first use.
  Future<StockMaterial> define({
    required String kind,
    required String unit,
    String? thickness,
    String? manufacturer,
    String? color,
    String? width,
    String? filmThickness,
    String? name,
  }) async => StockMaterial.fromJson(
    _map(
      await _client.callMethod(
        '$_base.define_material',
        post: true,
        params: {
          'kind': kind,
          'unit': unit,
          'thickness': ?thickness,
          'manufacturer': ?manufacturer,
          'color': ?color,
          'width': ?width,
          'film_thickness': ?filmThickness,
          'name': ?name,
        },
      ),
    ),
  );

  /// Posts a Material Receipt in ERPNext; one key per tap, so a retry
  /// never receives the same goods twice.
  Future<StockMaterial> receive({
    required String item,
    required double qty,
    required double pricePerUnit,
    required String supplier,
    ReceiptDelivery? delivery,
  }) async {
    final response = await _outbox.execute(
      _client,
      '$_base.receive',
      params: {
        'item': item,
        'qty': qty,
        'price_per_unit': pricePerUnit,
        'supplier': supplier,
        if (delivery != null)
          'delivery': jsonEncode({
            'amount': delivery.amount,
            'from_city': delivery.fromCity,
            'transport': delivery.transport,
          }),
      },
    );
    final data = _map(response);
    final material = data['material'];
    return StockMaterial.fromJson(
      material is Map ? Map<String, dynamic>.from(material) : const {},
    );
  }

  static const _facadeBase = 'korkem_manufacturing.api.facade_materials';

  /// What a facade order needs: MDF by thickness, film by decor.
  Future<FacadeMaterials> facadeMaterials(String salesOrder) async =>
      FacadeMaterials.fromJson(
        _map(
          await _client.callMethod(
            '$_facadeBase.need',
            params: {'sales_order': salesOrder},
          ),
        ),
      );

  /// Holds what is free for whatever the order still lacks. Safe to repeat,
  /// so it goes straight to the server rather than through the outbox.
  Future<FacadeMaterials> reserveFacadeMaterials(String salesOrder) async =>
      FacadeMaterials.fromJson(
        _map(
          await _client.callMethod(
            '$_facadeBase.reserve',
            params: {'sales_order': salesOrder},
            post: true,
          ),
        ),
      );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по складу.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
