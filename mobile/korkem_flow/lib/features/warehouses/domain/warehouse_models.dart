import 'package:flutter/foundation.dart';

/// A company warehouse (storage location, shop floor, or shipping warehouse).
@immutable
class WarehouseEntry {
  const WarehouseEntry({
    required this.warehouse,
    required this.name,
    required this.disabled,
    required this.positions,
    required this.isShippingDefault,
  });

  factory WarehouseEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    return WarehouseEntry(
      warehouse: '${raw['warehouse'] ?? raw['name'] ?? ''}'.trim(),
      name: '${raw['name'] ?? raw['warehouse_name'] ?? raw['warehouse'] ?? ''}'
          .trim(),
      disabled: raw['disabled'] == true || raw['disabled'] == 1,
      positions: switch (raw['positions']) {
        final num n => n.toInt(),
        final String s when int.tryParse(s) != null => int.parse(s),
        _ => 0,
      },
      isShippingDefault:
          raw['is_shipping_default'] == true || raw['is_shipping_default'] == 1,
    );
  }

  /// Full ERPNext docname, e.g. "Finished Goods - ED" or
  /// "Склад материалов - ED".
  final String warehouse;

  /// Display name, e.g. "Finished Goods" or "Склад материалов".
  final String name;

  /// Whether this warehouse is disabled (hidden from new documents).
  final bool disabled;

  /// Count of distinct item positions stored in this warehouse. 0 is normal.
  final int positions;

  /// Whether this warehouse is the default shipping warehouse (where finished
  /// furniture ships from).
  final bool isShippingDefault;

  WarehouseEntry copyWith({
    String? warehouse,
    String? name,
    bool? disabled,
    int? positions,
    bool? isShippingDefault,
  }) {
    return WarehouseEntry(
      warehouse: warehouse ?? this.warehouse,
      name: name ?? this.name,
      disabled: disabled ?? this.disabled,
      positions: positions ?? this.positions,
      isShippingDefault: isShippingDefault ?? this.isShippingDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarehouseEntry &&
          runtimeType == other.runtimeType &&
          warehouse == other.warehouse &&
          name == other.name &&
          disabled == other.disabled &&
          positions == other.positions &&
          isShippingDefault == other.isShippingDefault;

  @override
  int get hashCode => Object.hash(
    warehouse,
    name,
    disabled,
    positions,
    isShippingDefault,
  );
}
