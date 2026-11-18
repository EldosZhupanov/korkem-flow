import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

/// A piece of an MDF sheet put on the shelf for later (owner, 18.11.2026).
/// [lengthMm] is the longer side.
@immutable
class Offcut {
  const Offcut({
    required this.name,
    required this.thicknessMm,
    required this.lengthMm,
    required this.widthMm,
    this.areaM2 = 0,
    this.cell,
    this.note,
    this.sourceOrder,
    this.forOrder,
    this.createdOn,
  });

  factory Offcut.fromJson(Map<String, dynamic> json) => Offcut(
    name: '${json['offcut']}',
    thicknessMm: _d(json['thickness_mm']).round(),
    lengthMm: _d(json['length_mm']).round(),
    widthMm: _d(json['width_mm']).round(),
    areaM2: _d(json['area_m2']),
    cell: _s(json['cell']),
    note: _s(json['note']),
    sourceOrder: _s(json['source_order']),
    forOrder: _s(json['for_order']),
    createdOn: _s(json['created_on']),
  );

  final String name;
  final int thicknessMm;
  final int lengthMm;
  final int widthMm;
  final double areaM2;

  /// Where it lies: «A-3».
  final String? cell;
  final String? note;
  final String? sourceOrder;

  /// Put by for this order.
  final String? forOrder;
  final String? createdOn;

  String get size => '$lengthMm×$widthMm';
}

/// The shelf: every offcut, and the thicknesses one may put on it.
@immutable
class OffcutShelf {
  const OffcutShelf({
    this.offcuts = const [],
    this.thicknesses = const [],
    this.areaM2 = 0,
  });

  factory OffcutShelf.fromJson(Map<String, dynamic> json) => OffcutShelf(
    offcuts: [
      for (final o in json['offcuts'] as List? ?? const [])
        if (o is Map) Offcut.fromJson(Map<String, dynamic>.from(o)),
    ],
    thicknesses: [
      for (final t in json['thicknesses'] as List? ?? const [])
        _d(t).round(),
    ],
    areaM2: _d(json['area_m2']),
  );

  final List<Offcut> offcuts;
  final List<int> thicknesses;
  final double areaM2;
}

/// A part of an order that an offcut on the shelf holds.
@immutable
class OffcutPart {
  const OffcutPart({
    required this.position,
    required this.heightMm,
    required this.widthMm,
    required this.offcut,
  });

  factory OffcutPart.fromJson(Map<String, dynamic> json) => OffcutPart(
    position: _d(json['position']).round(),
    heightMm: _d(json['height_mm']).round(),
    widthMm: _d(json['width_mm']).round(),
    offcut: Offcut.fromJson(
      Map<String, dynamic>.from(json['offcut'] as Map? ?? const {}),
    ),
  );

  final int position;
  final int heightMm;
  final int widthMm;
  final Offcut offcut;
}

/// An order's parts that can be cut from offcuts, the smallest that holds
/// each.
@immutable
class OffcutSuggestion {
  const OffcutSuggestion({this.parts = const [], this.areaM2 = 0});

  factory OffcutSuggestion.fromJson(Map<String, dynamic> json) =>
      OffcutSuggestion(
        parts: [
          for (final p in json['parts'] as List? ?? const [])
            if (p is Map) OffcutPart.fromJson(Map<String, dynamic>.from(p)),
        ],
        areaM2: _d(json['area_m2']),
      );

  final List<OffcutPart> parts;
  final double areaM2;
}
