import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(Object? v) => v == null ? null : _d(v);
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _rows(Object? v) => [
  for (final r in v is List ? v : const <Object>[])
    if (r is Map) Map<String, dynamic>.from(r),
];

/// The last receipt of a paint: when, how much, at what price, from whom.
@immutable
class PaintLast {
  const PaintLast({
    required this.date,
    required this.kg,
    this.priceKg,
    this.supplier,
    this.supplierName,
    this.city,
    this.transport,
  });

  factory PaintLast.fromJson(Map<String, dynamic> j) => PaintLast(
    date: '${j['date'] ?? ''}',
    kg: _d(j['kg']),
    priceKg: _dn(j['price_kg']),
    supplier: _s(j['supplier']),
    supplierName: _s(j['supplier_name']),
    city: _s(j['city']),
    transport: _s(j['transport']),
  );

  final String date;
  final double kg;
  final double? priceKg;
  final String? supplier;
  final String? supplierName;
  final String? city;
  final String? transport;
}

/// One paint in the store: a colour and what it is — «эмаль ПУ матовая».
@immutable
class PaintItem {
  const PaintItem({
    required this.item,
    required this.title,
    required this.colour,
    required this.onHandKg,
    this.base,
    this.averagePrice,
    this.last,
  });

  factory PaintItem.fromJson(Map<String, dynamic> j) => PaintItem(
    item: '${j['item']}',
    title: '${j['title'] ?? ''}',
    colour: '${j['colour'] ?? ''}',
    base: _s(j['base']),
    onHandKg: _d(j['on_hand_kg']),
    averagePrice: _dn(j['average_price']),
    last: j['last'] is Map
        ? PaintLast.fromJson(Map<String, dynamic>.from(j['last'] as Map))
        : null,
  );

  final String item;
  final String title;
  final String colour;
  final String? base;
  final double onHandKg;
  final double? averagePrice;
  final PaintLast? last;
}

/// What the queue needs of a colour against what is on hand.
@immutable
class PaintNeed {
  const PaintNeed({
    required this.colour,
    required this.queueM2,
    required this.needKg,
    required this.onHandKg,
    required this.shortKg,
  });

  factory PaintNeed.fromJson(Map<String, dynamic> j) => PaintNeed(
    colour: '${j['colour']}',
    queueM2: _d(j['queue_m2']),
    needKg: _d(j['need_kg']),
    onHandKg: _d(j['on_hand_kg']),
    shortKg: _d(j['short_kg']),
  );

  final String colour;
  final double queueM2;
  final double needKg;
  final double onHandKg;
  final double shortKg;
}

/// Paint bought on credit or by invoice and not paid yet.
@immutable
class PaintOwed {
  const PaintOwed({
    required this.receipt,
    required this.date,
    required this.paint,
    required this.kg,
    required this.supplier,
    this.amount,
    this.invoiceNo,
    this.dueOn,
    this.overdue = false,
  });

  factory PaintOwed.fromJson(Map<String, dynamic> j) => PaintOwed(
    receipt: '${j['receipt']}',
    date: '${j['date'] ?? ''}',
    paint: '${j['paint'] ?? ''}',
    kg: _d(j['kg']),
    amount: _dn(j['amount']),
    supplier: '${j['supplier'] ?? ''}',
    invoiceNo: _s(j['invoice_no']),
    dueOn: _s(j['due_on']),
    overdue: j['overdue'] == true,
  );

  final String receipt;
  final String date;
  final String paint;
  final double kg;
  final double? amount;
  final String supplier;
  final String? invoiceNo;
  final String? dueOn;
  final bool overdue;
}

typedef PaintSupplier = ({String id, String name, String? city, bool paint});

/// The last month: m² painted, kilograms the figure took for them, what
/// counts found missing — and what a m² really took (owner, 15.11.2026).
typedef PaintUsage = ({
  int days,
  double m2,
  double kgByNorm,
  double kgCounted,
  double? factKgM2,
});

/// «Склад краски» (owner, 15.11.2026).
@immutable
class PaintStock {
  const PaintStock({
    this.paints = const [],
    this.queue = const [],
    this.kgPerM2 = 0.3,
    this.owed = const [],
    this.suppliers = const [],
    this.usage,
  });

  factory PaintStock.fromJson(Map<String, dynamic> j) => PaintStock(
    paints: [for (final r in _rows(j['paints'])) PaintItem.fromJson(r)],
    queue: [for (final r in _rows(j['queue'])) PaintNeed.fromJson(r)],
    kgPerM2: _d(j['kg_per_m2']),
    owed: [for (final r in _rows(j['owed'])) PaintOwed.fromJson(r)],
    suppliers: [
      for (final r in _rows(j['suppliers']))
        (
          id: '${r['supplier']}',
          name: '${r['name'] ?? r['supplier']}',
          city: _s(r['city']),
          paint: r['paint'] == true,
        ),
    ],
    usage: j['usage'] is Map
        ? (
            days: (j['usage'] as Map)['days'] is num
                ? ((j['usage'] as Map)['days'] as num).toInt()
                : 30,
            m2: _d((j['usage'] as Map)['m2']),
            kgByNorm: _d((j['usage'] as Map)['kg_by_norm']),
            kgCounted: _d((j['usage'] as Map)['kg_counted']),
            factKgM2: _dn((j['usage'] as Map)['fact_kg_m2']),
          )
        : null,
  );

  final List<PaintItem> paints;
  final List<PaintNeed> queue;
  final double kgPerM2;
  final List<PaintOwed> owed;
  final List<PaintSupplier> suppliers;
  final PaintUsage? usage;

  /// The last receipt of a colour, of any kind of it — what to start from.
  PaintLast? lastOf(String colour, {String? base}) {
    PaintLast? best;
    for (final p in paints) {
      if (p.colour != colour || p.last == null) continue;
      if (base != null && p.base != base) continue;
      if (best == null || p.last!.date.compareTo(best.date) > 0) best = p.last;
    }
    return best;
  }

  /// What a colour has been bought as — «эмаль ПУ матовая», «грунт».
  List<String> get bases => {
    for (final p in paints)
      if (p.base case final b?) b,
  }.toList();
}

/// One receipt of a paint, for its history.
@immutable
class PaintReceipt {
  const PaintReceipt({
    required this.receipt,
    required this.date,
    required this.kg,
    this.priceKg,
    this.landedKg,
    this.deliveryCost,
    this.supplier,
    this.city,
    this.transport,
    this.receivedBy,
    this.owed = false,
    this.cancelled = false,
  });

  factory PaintReceipt.fromJson(Map<String, dynamic> j) => PaintReceipt(
    receipt: '${j['receipt']}',
    date: '${j['date'] ?? ''}',
    kg: _d(j['kg']),
    priceKg: _dn(j['price_kg']),
    landedKg: _dn(j['landed_kg']),
    deliveryCost: _dn(j['delivery_cost']),
    supplier: _s(j['supplier']),
    city: _s(j['city']),
    transport: _s(j['transport']),
    receivedBy: _s(j['received_by']),
    owed: j['owed'] == true,
    cancelled: j['cancelled'] == true,
  );

  final String receipt;
  final String date;
  final double kg;
  final double? priceKg;
  final double? landedKg;
  final double? deliveryCost;
  final String? supplier;
  final String? city;
  final String? transport;
  final String? receivedBy;
  final bool owed;
  final bool cancelled;
}
