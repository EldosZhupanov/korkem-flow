import 'package:meta/meta.dart';

/// A submitted `Delivery Note` recorded against a sales order in ERPNext.
@immutable
class SalesOrderDelivery {
  const SalesOrderDelivery({
    required this.name,
    this.postingDate,
    this.status,
    this.grandTotal = 0,
    this.items = const [],
  });

  factory SalesOrderDelivery.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return SalesOrderDelivery(
      name: json['name'] as String? ?? '',
      postingDate: _date(json['posting_date']),
      status: json['status'] as String?,
      grandTotal: _number(json['grand_total']) ?? 0,
      items: [
        for (final raw in rawItems)
          if (raw is Map<String, dynamic>)
            SalesOrderDeliveryItem.fromJson(raw)
          else if (raw is Map)
            SalesOrderDeliveryItem.fromJson(Map<String, dynamic>.from(raw)),
      ],
    );
  }

  final String name;
  final DateTime? postingDate;
  final String? status;
  final double grandTotal;
  final List<SalesOrderDeliveryItem> items;

  @override
  bool operator ==(Object other) =>
      other is SalesOrderDelivery && other.name == name;

  @override
  int get hashCode => name.hashCode;

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : DateTime.tryParse(trimmed);
  }
}

/// One line in a submitted `Delivery Note`.
@immutable
class SalesOrderDeliveryItem {
  const SalesOrderDeliveryItem({
    this.itemCode,
    this.itemName,
    this.qty = 0,
    this.uom,
  });

  factory SalesOrderDeliveryItem.fromJson(Map<String, dynamic> json) {
    return SalesOrderDeliveryItem(
      itemCode: json['item_code'] as String?,
      itemName: json['item_name'] as String?,
      qty:
          (json['qty'] as num?)?.toDouble() ??
          double.tryParse(json['qty']?.toString() ?? '') ??
          0,
      uom: json['uom'] as String?,
    );
  }

  final String? itemCode;
  final String? itemName;
  final double qty;
  final String? uom;

  @override
  bool operator ==(Object other) =>
      other is SalesOrderDeliveryItem &&
      other.itemCode == itemCode &&
      other.itemName == itemName &&
      other.qty == qty &&
      other.uom == uom;

  @override
  int get hashCode => Object.hash(itemCode, itemName, qty, uom);
}
