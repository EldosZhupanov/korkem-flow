import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/items/domain/item.dart';

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return ItemsRepository(ref.watch(frappeClientProvider));
});

/// Data access for items catalog, units of measure, and prices.
class ItemsRepository {
  const ItemsRepository(this._client);

  static const _base = 'korkem_manufacturing.api.catalogue';
  static const unitsEndpoint = '$_base.units';
  static const itemsEndpoint = '$_base.items';
  static const createEndpoint = '$_base.create';
  static const setPriceEndpoint = '$_base.set_price';

  final FrappeClient _client;

  /// Fetches items matching the optional search query.
  ///
  /// Throws [ServerFailure] if the server returns an unexpected response.
  Future<List<Item>> list({String? query, int limit = 50}) async {
    final response = await _client.callMethod(
      itemsEndpoint,
      params: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        'limit': limit,
      },
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! List) {
      throw const ServerFailure(
        'Failed to load items: unexpected response from server.',
      );
    }

    return raw
        .whereType<Map<Object?, Object?>>()
        .map((e) => Item.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Creates a new item in the catalog.
  ///
  /// Requires [Item.unit] and [Item.name] to be non-empty.
  /// Throws [ValidationFailure] if unit or name is missing,
  /// and [ServerFailure] if the server does not confirm creation.
  Future<Item> create(Item item) async {
    final name = item.name.trim();
    final unit = item.unit.trim();
    if (name.isEmpty) {
      throw const ValidationFailure('Item name is required.');
    }
    if (unit.isEmpty) {
      throw const ValidationFailure('Unit of measure is required.');
    }

    final response = await _client.callMethod(
      createEndpoint,
      post: true,
      params: {
        'name': name,
        'unit': unit,
        if (item.code.trim().isNotEmpty) 'code': item.code.trim(),
        if (item.description.trim().isNotEmpty)
          'description': item.description.trim(),
        if (item.salePrice != null) 'price': item.salePrice,
      },
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to create item: unexpected response from server.',
      );
    }

    return Item.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Sets or updates the selling price for the given item code.
  ///
  /// Throws [ServerFailure] if the server does not confirm the price update.
  Future<Item> setPrice(String code, double price) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      throw const ValidationFailure('Item code is required.');
    }

    final response = await _client.callMethod(
      setPriceEndpoint,
      post: true,
      params: {
        'code': cleanCode,
        'price': price,
      },
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to update price: unexpected response from server.',
      );
    }

    return Item.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Fetches the configured units of measure from the server in priority order.
  ///
  /// Throws [ServerFailure] if the server returns an unexpected response.
  Future<List<UnitOption>> fetchUnits() async {
    final response = await _client.callMethod(unitsEndpoint);
    final dynamic raw = response['message'] ?? response['data'];

    if (raw == null || raw is! List) {
      throw const ServerFailure(
        'Failed to load units: unexpected response from server.',
      );
    }

    return raw
        .whereType<Map<Object?, Object?>>()
        .map((e) => UnitOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
