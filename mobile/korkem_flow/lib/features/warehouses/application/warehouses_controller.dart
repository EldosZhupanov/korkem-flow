import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/warehouses/data/warehouses_repository.dart';
import 'package:korkem_flow/features/warehouses/domain/warehouse_models.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final warehousesListProvider = FutureProvider.autoDispose<List<WarehouseEntry>>(
  (ref) async {
    return ref.watch(warehousesRepositoryProvider).fetchWarehouses();
  },
);
