import 'package:flutter/foundation.dart';

/// One order waiting to be painted in a colour.
typedef MdfPaintOrder = ({
  String name,
  String customer,
  String deliveryDate,
  double areaM2,
  bool overdue,
  bool urgent,
});

/// An order put to dry, and when it will be.
typedef MdfDrying = ({
  String name,
  String customer,
  String dryAt,
  bool dry,
  int minutesLeft,
  List<String> colours,
  double areaM2,
});

/// The paint department's board (owner, 14.11.2026): what to paint, by
/// colour, the biggest batch first; what is drying; what is on its way; the
/// colours painted most.
@immutable
class MdfPaintBoard {
  const MdfPaintBoard({
    this.dryHours = 24,
    this.byColour = const [],
    this.waitingM2 = 0,
    this.drying = const [],
    this.comingM2 = 0,
    this.popular = const [],
  });

  factory MdfPaintBoard.fromJson(Map<String, dynamic> json) => MdfPaintBoard(
    dryHours: _i(json['dry_hours']),
    byColour: [
      for (final g in _maps(json['by_colour']))
        (
          colour: '${g['colour'] ?? '—'}',
          areaM2: _d(g['area_m2']),
          orders: [
            for (final o in _maps(g['orders']))
              (
                name: '${o['name'] ?? ''}',
                customer: '${o['customer_name'] ?? ''}',
                deliveryDate: '${o['delivery_date'] ?? ''}',
                areaM2: _d(o['area_m2']),
                overdue: o['overdue'] == true,
                urgent: o['urgent'] == true,
              ),
          ],
        ),
    ],
    waitingM2: _d(json['waiting_m2']),
    drying: [
      for (final d in _maps(json['drying']))
        (
          name: '${d['name'] ?? ''}',
          customer: '${d['customer_name'] ?? ''}',
          dryAt: '${d['dry_at'] ?? ''}',
          dry: d['dry'] == true,
          minutesLeft: _i(d['minutes_left']),
          colours: [
            for (final c in d['colours'] is List ? d['colours'] as List : [])
              '$c',
          ],
          areaM2: _d(d['area_m2']),
        ),
    ],
    comingM2: _d(json['coming_m2']),
    popular: [
      for (final p in _maps(json['popular']))
        (
          colour: '${p['colour'] ?? '—'}',
          areaM2: _d(p['area_m2']),
          orders: _i(p['orders']),
        ),
    ],
  );

  /// How long a coat dries here, in hours.
  final int dryHours;
  final List<({String colour, double areaM2, List<MdfPaintOrder> orders})>
  byColour;
  final double waitingM2;
  final List<MdfDrying> drying;

  /// m² of paint still at the stages before it.
  final double comingM2;
  final List<({String colour, double areaM2, int orders})> popular;
}

List<Map<String, dynamic>> _maps(Object? v) => [
  for (final e in v is List ? v : const <Object?>[])
    if (e is Map) Map<String, dynamic>.from(e),
];

double _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
