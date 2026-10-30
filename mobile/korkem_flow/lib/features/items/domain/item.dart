import 'package:flutter/foundation.dart';

/// A unit of measure option fetched dynamically from the server.
@immutable
class UnitOption {
  const UnitOption({
    required this.unit,
    required this.label,
  });

  factory UnitOption.fromJson(Map<String, dynamic> json) {
    return UnitOption(
      unit: '${json['unit'] ?? ''}',
      label: '${json['label'] ?? json['unit'] ?? ''}',
    );
  }

  /// The ERPNext UOM identifier (e.g. `Nos`, `Set`, `Meter`).
  final String unit;

  /// The human-friendly display label (e.g. `шт`, `комплект`).
  final String label;

  Map<String, dynamic> toJson() => {
    'unit': unit,
    'label': label,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitOption &&
          runtimeType == other.runtimeType &&
          unit == other.unit &&
          label == other.label;

  @override
  int get hashCode => Object.hash(unit, label);

  @override
  String toString() => 'UnitOption(unit: $unit, label: $label)';
}

/// An item/product in the master catalog.
@immutable
class Item {
  const Item({
    required this.code,
    required this.name,
    required this.unit,
    this.description = '',
    this.salePrice,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    final rawPrice =
        json['price'] ??
        json['sale_price'] ??
        json['rate'] ??
        json['standard_rate'];

    final parsedPrice = switch (rawPrice) {
      final num n => n.toDouble(),
      final String s when double.tryParse(s) != null => double.parse(s),
      _ => null,
    };

    final code = '${json['code'] ?? json['item_code'] ?? json['name'] ?? ''}';
    final name = '${json['name'] ?? json['item_name'] ?? json['code'] ?? ''}';
    final unit = '${json['unit'] ?? json['stock_uom'] ?? json['uom'] ?? ''}';
    final description = '${json['description'] ?? ''}';

    return Item(
      code: code,
      name: name,
      unit: unit,
      description: description,
      salePrice: parsedPrice,
    );
  }

  /// The unique item code / SKU (e.g. `ITEM-001` or `CAB-01`).
  final String code;

  /// The human-readable name of the item.
  final String name;

  /// The unit of measure code (e.g. `Nos`, `Set`, `Meter`).
  ///
  /// Mandatory in ERPNext item creation.
  final String unit;

  /// Detailed description, specifications, or notes.
  final String description;

  /// Optional selling/catalog price.
  ///
  /// `null` means the price has not been worked out yet — normal for
  /// made-to-order furniture, where the number follows the measurement. Zero
  /// means free: a sample, a fitting thrown in with an order. They are not the
  /// same answer and must not collapse into one.
  ///
  /// Nothing enforced that until a mutation test broke it deliberately: turning
  /// every zero into `null` left all 740 tests green, because no fixture in the
  /// project used a price of zero. Three tests in
  /// `items_repository_test.dart` hold the line now.
  final double? salePrice;

  Item copyWith({
    String? code,
    String? name,
    String? unit,
    String? description,
    double? salePrice,
    bool clearSalePrice = false,
  }) {
    return Item(
      code: code ?? this.code,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      salePrice: clearSalePrice ? null : (salePrice ?? this.salePrice),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'unit': unit,
    if (description.isNotEmpty) 'description': description,
    if (salePrice != null) 'price': salePrice,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name &&
          unit == other.unit &&
          description == other.description &&
          salePrice == other.salePrice;

  @override
  int get hashCode => Object.hash(code, name, unit, description, salePrice);

  @override
  String toString() =>
      'Item(code: $code, name: $name, unit: $unit, price: $salePrice)';
}
