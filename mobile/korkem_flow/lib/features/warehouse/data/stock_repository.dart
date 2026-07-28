import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/warehouse/domain/stock_item.dart';

/// Reads `Item` and its per-warehouse `Bin` balances.
class StockRepository {
  const StockRepository(this._client);

  static const itemDoctype = 'Item';
  static const binDoctype = 'Bin';

  static const itemFields = [
    'name',
    'item_name',
    'item_group',
    'stock_uom',
    'is_stock_item',
    'disabled',
    'valuation_rate',
  ];

  static const binFields = [
    'warehouse',
    'actual_qty',
    'reserved_qty',
    'projected_qty',
    'stock_uom',
  ];

  final FrappeClient _client;

  Future<List<StockItem>> fetchItems({
    required int pageSize,
    int offset = 0,
    String? search,
    bool includeDisabled = false,
  }) async {
    final rows = await _client.getList(
      itemDoctype,
      FrappeQuery(
        fields: itemFields,
        filters: [
          // A disabled item is retired. Listing it alongside live stock invites
          // someone to promise a customer something the factory stopped making.
          if (!includeDisabled) const FrappeFilter.equals('disabled', 0),
          if (search != null && search.trim().isNotEmpty)
            FrappeFilter.like('item_name', '%${search.trim()}%'),
        ],
        orderBy: 'modified desc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(itemFromJson).toList(growable: false);
  }

  /// Where one item is, and how much of it.
  ///
  /// Warehouses holding nothing at all are dropped: ERPNext keeps a Bin row
  /// after stock leaves, and a list of zeroes buries the one warehouse that
  /// actually has the panels.
  Future<List<StockBalance>> fetchBalances(String itemCode) async {
    final rows = await _client.getList(
      binDoctype,
      FrappeQuery(
        fields: binFields,
        filters: [FrappeFilter.equals('item_code', itemCode)],
        orderBy: 'actual_qty desc',
      ),
    );

    return rows
        .map(balanceFromJson)
        .where((b) => b.actualQty != 0 || b.projectedQty != 0)
        .toList(growable: false);
  }

  static StockItem itemFromJson(Map<String, dynamic> json) {
    final id = '${json['name']}';

    return StockItem(
      id: id,
      name: _text(json['item_name']) ?? id,
      itemGroup: _text(json['item_group']),
      stockUom: _text(json['stock_uom']),
      isStockItem: _flag(json['is_stock_item'], fallback: true),
      disabled: _flag(json['disabled']),
      valuationRate: _number(json['valuation_rate']),
    );
  }

  static StockBalance balanceFromJson(Map<String, dynamic> json) {
    return StockBalance(
      warehouse: '${json['warehouse']}',
      actualQty: _number(json['actual_qty']) ?? 0,
      reservedQty: _number(json['reserved_qty']) ?? 0,
      projectedQty: _number(json['projected_qty']) ?? 0,
      stockUom: _text(json['stock_uom']),
    );
  }

  /// Frappe Check fields arrive as 0/1, and occasionally as "0"/"1".
  static bool _flag(Object? value, {bool fallback = false}) => switch (value) {
    final bool flag => flag,
    final int number => number != 0,
    final String text => text == '1',
    _ => fallback,
  };

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
