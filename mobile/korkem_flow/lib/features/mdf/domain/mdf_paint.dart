import 'package:flutter/foundation.dart';

/// What sets an order apart at the paint (owner, 14.11.2026): urgent, the
/// customer's own paint (and whether it is here yet), his own facades, both
/// sides painted.
typedef MdfPaintMarks = ({
  bool urgent,
  bool clientPaint,
  String? clientPaintNote,
  bool waitingPaint,
  bool clientParts,
  bool twoSided,
});

MdfPaintMarks _marks(Map<String, dynamic> o) => (
  urgent: o['urgent'] == true,
  clientPaint: o['client_paint'] == true,
  clientPaintNote: o['client_paint_note'] == null
      ? null
      : '${o['client_paint_note']}',
  waitingPaint: o['waiting_paint'] == true,
  clientParts: o['client_parts'] == true,
  twoSided: o['two_sided'] == true,
);

/// One order waiting to be painted in a colour.
typedef MdfPaintOrder = ({
  String name,
  String customer,
  String deliveryDate,
  double areaM2,
  bool overdue,
  MdfPaintMarks marks,
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
  MdfPaintMarks marks,
});

/// An order on its way to the paint, and the stage it is at now.
typedef MdfComing = ({
  String name,
  String customer,
  String deliveryDate,
  String stage,
  List<String> colours,
  double areaM2,
  MdfPaintMarks marks,
});

List<String> _strings(Object? v) => [
  for (final c in v is List ? v : const <Object?>[]) '$c',
];

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
    this.coming = const [],
    this.popular = const [],
    this.clientPaintDiscount = 0,
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
                marks: _marks(o),
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
          colours: _strings(d['colours']),
          areaM2: _d(d['area_m2']),
          marks: _marks(d),
        ),
    ],
    comingM2: _d(json['coming_m2']),
    coming: [
      for (final c in _maps(json['coming']))
        (
          name: '${c['name'] ?? ''}',
          customer: '${c['customer_name'] ?? ''}',
          deliveryDate: '${c['delivery_date'] ?? ''}',
          stage: '${c['stage'] ?? ''}',
          colours: _strings(c['colours']),
          areaM2: _d(c['area_m2']),
          marks: _marks(c),
        ),
    ],
    clientPaintDiscount: _d(json['client_paint_discount']),
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

  /// The orders still at the stages before it, each with its stage.
  final List<MdfComing> coming;

  /// How much less a m² costs with the customer's own paint.
  final double clientPaintDiscount;
  final List<({String colour, double areaM2, int orders})> popular;
}

List<Map<String, dynamic>> _maps(Object? v) => [
  for (final e in v is List ? v : const <Object?>[])
    if (e is Map) Map<String, dynamic>.from(e),
];

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
