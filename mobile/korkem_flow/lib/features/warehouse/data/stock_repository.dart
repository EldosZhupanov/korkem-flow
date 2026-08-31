import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/warehouse/domain/stock_item.dart';

/// Reads warehouse stock balances and items through the company-scoped
/// query endpoint.
class StockRepository {
  const StockRepository(this._client);

  static const queryPath = 'korkem_manufacturing.api.queries.stock';

  final FrappeClient _client;

  /// Fetches warehouse stock balances through the company-scoped query
  /// endpoint.
  Future<StockPage> fetchStock({
    int pageSize = 50,
    int offset = 0,
    String? warehouse,
    String? search,
  }) async {
    final response = await _client.callMethod(
      queryPath,
      params: {
        'limit': pageSize,
        'offset': offset,
        if (warehouse != null && warehouse.trim().isNotEmpty)
          'warehouse': warehouse.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final raw = response['message'] ?? response;
    return StockPage.fromJson(raw);
  }

  /// Fetches unique items for warehouse display.
  Future<List<StockItem>> fetchItems({
    required int pageSize,
    int offset = 0,
    String? search,
    bool includeDisabled = false,
  }) async {
    final page = await fetchStock(
      pageSize: pageSize,
      offset: offset,
      search: search,
    );

    final seen = <String>{};
    final items = <StockItem>[];
    for (final row in page.items) {
      if (seen.add(row.itemCode)) {
        items.add(
          StockItem(
            id: row.itemCode,
            name: row.itemName ?? row.itemCode,
            stockUom: row.stockUom,
          ),
        );
      }
    }
    return items;
  }

  /// Where one item is, and how much of it.
  Future<List<StockBalance>> fetchBalances(String itemCode) async {
    final page = await fetchStock(search: itemCode);

    return page.items
        .where((r) => r.itemCode == itemCode)
        .map(
          (r) => StockBalance(
            warehouse: r.warehouse,
            actualQty: r.actualQty,
            reservedQty: r.reservedQty,
            projectedQty: r.projectedQty,
            stockUom: r.stockUom,
          ),
        )
        .where((b) => b.actualQty != 0 || b.projectedQty != 0)
        .toList(growable: false);
  }

  static StockItem itemFromJson(Map<String, dynamic> json) {
    final id = '${json['item_code'] ?? json['name']}';

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

class StockPosition {
  const StockPosition({
    required this.itemCode,
    required this.warehouse,
    required this.actualQty,
    this.itemName,
    this.reservedQty = 0,
    this.projectedQty = 0,
    this.stockUom,
  });

  factory StockPosition.fromJson(Map<String, dynamic> json) => StockPosition(
    itemCode: _text(json['item_code'] ?? json['name']) ?? '',
    warehouse: _text(json['warehouse']) ?? '',
    actualQty: _number(json['actual_qty']) ?? 0,
    itemName: _text(json['item_name']),
    reservedQty: _number(json['reserved_qty']) ?? 0,
    projectedQty: _number(json['projected_qty']) ?? 0,
    stockUom: _text(json['stock_uom']),
  );

  final String itemCode;
  final String? itemName;
  final String warehouse;
  final double actualQty;
  final double reservedQty;
  final double projectedQty;
  final String? stockUom;

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

class StockPage {
  const StockPage({
    required this.items,
    required this.total,
  });

  factory StockPage.fromJson(Object? raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final list = json['items'];
    final items = list is List
        ? list
              .whereType<Map<String, dynamic>>()
              .map(StockPosition.fromJson)
              .toList(growable: false)
        : const <StockPosition>[];
    final total = json['total'] is num
        ? (json['total'] as num).toInt()
        : items.length;

    return StockPage(items: items, total: total);
  }

  final List<StockPosition> items;
  final int total;
}
