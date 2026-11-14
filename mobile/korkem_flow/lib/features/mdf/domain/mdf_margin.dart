import 'package:flutter/foundation.dart';

/// What an MDF order earned (owner, 14.11.2026): its total less the material
/// and the work. Paint, glue, power and delivery are not counted — nobody
/// records them per order — so this is an upper bound, and the screen says so.
@immutable
class MdfMargin {
  const MdfMargin({
    required this.order,
    this.revenue = 0,
    this.material = 0,
    this.work = 0,
    this.margin = 0,
    this.share,
    this.estimate = false,
    this.missing = const [],
    this.materials = const [],
  });

  factory MdfMargin.fromJson(Map<String, dynamic> json) => MdfMargin(
    order: '${json['order'] ?? ''}',
    revenue: _d(json['revenue']),
    material: _d(json['material']),
    work: _d(json['work']),
    margin: _d(json['margin']),
    share: _dn(json['share']),
    estimate: json['estimate'] == true,
    missing: [for (final m in _list(json['missing'])) '$m'],
    materials: [
      for (final r in _list(json['material_rows']))
        if (r is Map)
          (
            title: '${r['title'] ?? r['item'] ?? ''}',
            unit: '${r['unit'] ?? ''}',
            qty: _d(r['qty']),
            cost: _d(r['cost']),
          ),
    ],
  );

  final String order;
  final double revenue;
  final double material;
  final double work;
  final double margin;

  /// Margin over revenue, 0..1; null for an order with no price (a rework).
  final double? share;

  /// Nothing written off yet: the material is the need at today's prices.
  final bool estimate;

  /// Materials with no price at all — counted as nothing.
  final List<String> missing;
  final List<({String title, String unit, double qty, double cost})> materials;
}

/// The orders handed over in a period, for «Итоги МДФ».
@immutable
class MdfMarginPeriod {
  const MdfMarginPeriod({
    this.orders = 0,
    this.revenue = 0,
    this.material = 0,
    this.work = 0,
    this.margin = 0,
    this.share,
    this.estimated = 0,
    this.missing = 0,
    this.lowest = const [],
  });

  factory MdfMarginPeriod.fromJson(Map<String, dynamic> json) =>
      MdfMarginPeriod(
        orders: _i(json['orders']),
        revenue: _d(json['revenue']),
        material: _d(json['material']),
        work: _d(json['work']),
        margin: _d(json['margin']),
        share: _dn(json['share']),
        estimated: _i(json['estimated']),
        missing: _i(json['missing']),
        lowest: [
          for (final r in _list(json['lowest']))
            if (r is Map)
              (
                name: '${r['name'] ?? ''}',
                customer: '${r['customer_name'] ?? ''}',
                margin: _d(r['margin']),
                share: _dn(r['share']),
              ),
        ],
      );

  final int orders;
  final double revenue;
  final double material;
  final double work;
  final double margin;
  final double? share;

  /// Orders whose material is an estimate — nothing was written off.
  final int estimated;

  /// Orders with a material nobody priced.
  final int missing;

  /// The orders that earned least, worst first.
  final List<({String name, String customer, double margin, double? share})>
  lowest;
}

List<Object?> _list(Object? v) => v is List ? v : const [];

double? _dn(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

double _d(Object? v) => _dn(v) ?? 0;

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
