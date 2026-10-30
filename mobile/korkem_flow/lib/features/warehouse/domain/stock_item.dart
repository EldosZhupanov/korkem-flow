import 'package:meta/meta.dart';

/// An ERPNext `Item` — a thing the factory buys, makes or sells.
@immutable
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    this.itemGroup,
    this.stockUom,
    this.isStockItem = true,
    this.disabled = false,
    this.valuationRate,
  });

  /// `Item` is named `field:item_code`, so the id is the item code.
  final String id;

  final String name;
  final String? itemGroup;
  final String? stockUom;

  /// A service or a non-stock item has no quantities to show, so the warehouse
  /// breakdown is meaningless for it rather than merely empty.
  final bool isStockItem;

  final bool disabled;
  final double? valuationRate;

  @override
  bool operator ==(Object other) => other is StockItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One `Bin` row: how much of an item sits in one warehouse.
///
/// Bin is ERPNext's per-item-per-warehouse balance. It exists only where stock
/// has moved, so an item with no Bin rows has genuinely never been stocked —
/// which is different from having a zero balance.
@immutable
class StockBalance {
  const StockBalance({
    required this.warehouse,
    required this.actualQty,
    this.reservedQty = 0,
    this.projectedQty = 0,
    this.stockUom,
  });

  final String warehouse;

  /// What is physically there.
  final double actualQty;

  /// Committed to orders. `actual - reserved` is what can still be promised.
  final double reservedQty;

  /// ERPNext's forward projection: actual − reserved + ordered + planned.
  final double projectedQty;

  final String? stockUom;

  double get availableQty => actualQty - reservedQty;
}
