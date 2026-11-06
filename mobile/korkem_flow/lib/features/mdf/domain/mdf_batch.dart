import 'package:flutter/foundation.dart';

/// One part size across the orders of a batch; a part turned 90° is the
/// same part, so it is written long side first.
@immutable
class BatchPart {
  const BatchPart({
    required this.longMm,
    required this.shortMm,
    required this.qty,
    required this.areaM2,
    required this.orders,
    this.milling,
  });

  factory BatchPart.fromJson(Map<String, dynamic> json) => BatchPart(
    longMm: (json['long_mm'] as num?)?.toInt() ?? 0,
    shortMm: (json['short_mm'] as num?)?.toInt() ?? 0,
    qty: (json['qty'] as num?)?.toInt() ?? 0,
    areaM2: (json['area_m2'] as num?)?.toDouble() ?? 0,
    milling: json['milling'] as String?,
    orders: [for (final o in json['orders'] as List? ?? const []) '$o'],
  );

  final int longMm;
  final int shortMm;
  final int qty;
  final double areaM2;
  final String? milling;
  final List<String> orders;
}

/// OnayBaza's «Тапсырыс Кестесі»: the parts of every open order of one film
/// (and milling), as one list to cut and press together.
@immutable
class MdfBatch {
  const MdfBatch({
    required this.orders,
    required this.parts,
    required this.pieces,
    required this.areaM2,
  });

  factory MdfBatch.fromJson(Map<String, dynamic> json) => MdfBatch(
    orders: [
      for (final o in json['orders'] as List? ?? const [])
        if (o is Map) '${o['name']} · ${o['customer_name'] ?? ''}',
    ],
    parts: [
      for (final p in json['parts'] as List? ?? const [])
        if (p is Map) BatchPart.fromJson(Map<String, dynamic>.from(p)),
    ],
    pieces: (json['pieces'] as num?)?.toInt() ?? 0,
    areaM2: (json['area_m2'] as num?)?.toDouble() ?? 0,
  );

  final List<String> orders;
  final List<BatchPart> parts;
  final int pieces;
  final double areaM2;
}
