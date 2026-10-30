import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/warehouses/domain/warehouse_models.dart';

final warehousesRepositoryProvider = Provider<WarehousesRepository>((ref) {
  return WarehousesRepository(ref.watch(frappeClientProvider));
});

/// Data access for factory warehouse locations and default shipping setup.
class WarehousesRepository {
  WarehousesRepository(this._client);

  final FrappeClient _client;

  static const listingEndpoint = 'korkem_manufacturing.api.warehouses.listing';
  static const createEndpoint = 'korkem_manufacturing.api.warehouses.create';
  static const setShippingDefaultEndpoint =
      'korkem_manufacturing.api.warehouses.set_shipping_default';
  static const setDisabledEndpoint =
      'korkem_manufacturing.api.warehouses.set_disabled';

  /// Загружает список складов компании с остатками и признаком склада отгрузки.
  Future<List<WarehouseEntry>> fetchWarehouses() async {
    final response = await _client.callMethod(listingEndpoint);
    final dynamic raw = response['message'] ?? response['data'];

    if (raw is! List) {
      throw const ServerFailure(
        'Сервер не вернул список складов.',
      );
    }

    return raw
        .whereType<Map<Object?, Object?>>()
        .map((e) => WarehouseEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Завести склад (название склада обязательно).
  Future<WarehouseEntry> createWarehouse({required String name}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationFailure(
        'У склада должно быть название: без него его не выбрать.',
      );
    }

    final response = await _client.callMethod(
      createEndpoint,
      post: true,
      params: {'name': cleanName},
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to create warehouse: unexpected response from server.',
      );
    }

    return WarehouseEntry.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Назначить склад, с которого уходит готовая мебель.
  Future<WarehouseEntry> setShippingDefault({required String warehouse}) async {
    final cleanWarehouse = warehouse.trim();
    if (cleanWarehouse.isEmpty) {
      throw const ValidationFailure('Warehouse ID is required.');
    }

    final response = await _client.callMethod(
      setShippingDefaultEndpoint,
      post: true,
      params: {'warehouse': cleanWarehouse},
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to set shipping default warehouse: '
        'unexpected response from server.',
      );
    }

    return WarehouseEntry.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Отключить склад (disabled = true) или вернуть в работу (disabled = false).
  Future<WarehouseEntry> setDisabled({
    required String warehouse,
    required bool disabled,
  }) async {
    final cleanWarehouse = warehouse.trim();
    if (cleanWarehouse.isEmpty) {
      throw const ValidationFailure('Warehouse ID is required.');
    }

    final response = await _client.callMethod(
      setDisabledEndpoint,
      post: true,
      params: {
        'warehouse': cleanWarehouse,
        'disabled': disabled,
      },
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to update warehouse status: unexpected response from server.',
      );
    }

    return WarehouseEntry.fromJson(Map<String, dynamic>.from(raw));
  }
}
