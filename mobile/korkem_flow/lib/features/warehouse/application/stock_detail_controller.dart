import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:meta/meta.dart';

@immutable
class StockItemDetail {
  const StockItemDetail({
    required this.itemCode,
    required this.itemName,
    required this.positions,
    this.stockUom,
  });

  final String itemCode;
  final String itemName;
  final String? stockUom;
  final List<StockPosition> positions;

  /// Sum of physical stock across all warehouses.
  double get totalActualQty => positions.fold(0, (sum, p) => sum + p.actualQty);

  /// Sum of reserved stock across all warehouses.
  double get totalReservedQty =>
      positions.fold(0, (sum, p) => sum + p.reservedQty);

  /// Sum of projected stock across all warehouses.
  double get totalProjectedQty =>
      positions.fold(0, (sum, p) => sum + p.projectedQty);

  bool get hasDeficit => positions.any((p) => p.projectedQty < 0);
}

/// One stock item, fetched through the same permission-aware endpoint the list
/// uses.
// The generics are right there, and `FutureProviderFamily` is not exported,
// so the type this lint asks for cannot be written down.
// ignore: specify_nonobvious_property_types
final stockItemDetailProvider = FutureProvider.family<StockItemDetail, String>(
  _fetchStockItemDetail,
);

/// There is no `get_one` on the server: search filter returns rows the caller
/// may see, and exact item_code matching turns search into lookup.
Future<StockItemDetail> _fetchStockItemDetail(Ref ref, String itemCode) async {
  final page = await ref
      .watch(stockRepositoryProvider)
      .fetchStock(search: itemCode);

  final exactMatches = page.items
      .where((p) => p.itemCode == itemCode)
      .toList(growable: false);

  if (exactMatches.isEmpty) {
    throw NotFoundFailure('Stock item $itemCode not found');
  }

  final first = exactMatches.first;
  return StockItemDetail(
    itemCode: itemCode,
    itemName: first.itemName ?? itemCode,
    stockUom: first.stockUom,
    positions: exactMatches,
  );
}
