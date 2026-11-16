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

/// A material the whole queue needs whatever its colours — primer,
/// hardener, thinner — against what is on hand (owner, 15.11.2026).
typedef PaintMaterialNeed = ({
  String name,
  double needKg,
  double onHandKg,
  double shortKg,
});

/// What goes into each kilogram of a layer: «Отвердитель 0,5 кг на 1 кг».
@immutable
class PaintPart {
  const PaintPart({required this.name, this.perKg = 0, this.priceKg = 0});

  factory PaintPart.fromJson(Map<String, dynamic> j) => PaintPart(
    name: '${j['name'] ?? ''}',
    perKg: _d(j['per_kg']),
    priceKg: _d(j['price_kg']),
  );

  final String name;
  final double perKg;

  /// What a kilo costs when none was ever bought.
  final double priceKg;

  Map<String, Object?> toJson() => {
    'name': name,
    'per_kg': perKg,
    'price_kg': priceKg,
  };
}

/// One layer of the shop's recipe: primer, enamel, lacquer — grams a m² a
/// coat, how many coats (none: not painted), what goes into it.
@immutable
class PaintLayer {
  const PaintLayer({
    required this.name,
    this.colour = false,
    this.gM2 = 0,
    this.coats = 0,
    this.priceKg = 0,
    this.parts = const [],
  });

  factory PaintLayer.fromJson(Map<String, dynamic> j) => PaintLayer(
    name: '${j['name'] ?? ''}',
    colour: j['colour'] == true,
    gM2: _d(j['g_m2']),
    coats: _d(j['coats']).round(),
    priceKg: _d(j['price_kg']),
    parts: [for (final r in _rows(j['parts'])) PaintPart.fromJson(r)],
  );

  final String name;

  /// The order's colour: the enamel.
  final bool colour;
  final double gM2;
  final int coats;
  final double priceKg;
  final List<PaintPart> parts;

  /// Kilograms a m² of this layer and all that goes into it.
  double get kgM2 =>
      gM2 / 1000 * coats * (1 + parts.fold<double>(0, (a, p) => a + p.perKg));

  Map<String, Object?> toJson() => {
    'name': name,
    'colour': colour,
    'g_m2': gM2,
    'coats': coats,
    'price_kg': priceKg,
    'parts': [for (final p in parts) p.toJson()],
  };
}

/// «Рецепт покраски» (owner, 15.11.2026).
@immutable
class PaintRecipe {
  const PaintRecipe({
    this.layers = const [],
    this.priceM2 = 0,
    this.markupPct = 0,
  });

  factory PaintRecipe.fromJson(Map<String, dynamic> j) => PaintRecipe(
    layers: [for (final r in _rows(j['layers'])) PaintLayer.fromJson(r)],
    priceM2: _d(j['price_m2']),
    markupPct: _d(j['markup_pct']),
  );

  final List<PaintLayer> layers;

  /// The shop's price a m² of painting, and the markup it asks on cost —
  /// for the calculator's «what is left» (owner, 15.11.2026).
  final double priceM2;
  final double markupPct;

  PaintRecipe withPrices({double? priceM2, double? markupPct}) => PaintRecipe(
    layers: layers,
    priceM2: priceM2 ?? this.priceM2,
    markupPct: markupPct ?? this.markupPct,
  );

  double get kgM2 => layers.fold<double>(0, (a, l) => a + l.kgM2);

  /// The names kept without a colour — primer, lacquer, hardener, thinner.
  List<String> get materials => {
    for (final l in layers) ...[
      if (!l.colour) l.name,
      for (final p in l.parts) p.name,
    ],
  }.toList();

  Map<String, Object?> toJson() => {
    'layers': [for (final l in layers) l.toJson()],
    'price_m2': priceM2,
    'markup_pct': markupPct,
  };
}

/// One material of a plan: so many kilograms, at what a kilo, for how much.
typedef PaintPlanLine = ({
  String name,
  String? colour,
  double kg,
  double? priceKg,
  double? cost,
});

/// What so many m² take by the recipe (owner, 15.11.2026: «вели м² —
/// сколько кг или грамм уйдёт, цена и окончательная цена»).
@immutable
class PaintPlan {
  const PaintPlan({
    required this.m2,
    this.colour,
    this.lines = const [],
    this.kg = 0,
    this.cost,
    this.costM2,
    this.priced = true,
    this.text = '',
    this.priceM2,
    this.markupPct = 0,
  });

  factory PaintPlan.fromJson(Map<String, dynamic> j) => PaintPlan(
    m2: _d(j['m2']),
    colour: _s(j['colour']),
    lines: [
      for (final r in _rows(j['lines']))
        (
          name: '${r['name'] ?? ''}',
          colour: _s(r['colour']),
          kg: _d(r['kg']),
          priceKg: _dn(r['price_kg']),
          cost: _dn(r['cost']),
        ),
    ],
    kg: _d(j['kg']),
    cost: _dn(j['cost']),
    costM2: _dn(j['cost_m2']),
    priced: j['priced'] != false,
    text: '${j['text'] ?? ''}',
    priceM2: _dn(j['price_m2']),
    markupPct: _d(j['markup_pct']),
  );

  final double m2;
  final String? colour;
  final List<PaintPlanLine> lines;
  final double kg;
  final double? cost;
  final double? costM2;

  /// Every material had a price; else the cost is short.
  final bool priced;

  /// For the supplier who tints, or the customer who brings his own.
  final String text;

  /// The shop's price a m² and its markup, as the recipe keeps them.
  final double? priceM2;
  final double markupPct;
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

/// Bringing paint someone paid out of his pocket, or nobody yet.
typedef PaintDeliveryOwed = ({
  String receipt,
  String date,
  double? amount,
  String? employee,
  String? transport,
  String? driver,
  String? phone,
  String? supplier,
});

/// A paint supplier — a company or a person, paint's own, apart from film
/// (owner, 15.11.2026) — with its card.
typedef PaintSupplier = ({
  String id,
  String name,
  String? city,
  bool paint,
  String? contact,
  String? phone,
  String? whatsapp,
  String? minOrder,
  String? note,
});

/// What a paint supplier's card says, as written in the dialog.
typedef PaintSupplierCard = ({
  String name,
  String? city,
  String? contact,
  String? phone,
  String? whatsapp,
  String? minOrder,
  String? note,
});

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
    this.kgPerM2 = 0.66,
    this.owed = const [],
    this.suppliers = const [],
    this.usage,
    this.deliveryOwed = const [],
    this.materials = const [],
    this.recipe = const PaintRecipe(),
  });

  factory PaintStock.fromJson(Map<String, dynamic> j) => PaintStock(
    paints: [for (final r in _rows(j['paints'])) PaintItem.fromJson(r)],
    queue: [for (final r in _rows(j['queue'])) PaintNeed.fromJson(r)],
    kgPerM2: _d(j['kg_per_m2']),
    materials: [
      for (final r in _rows(j['materials']))
        (
          name: '${r['name'] ?? ''}',
          needKg: _d(r['need_kg']),
          onHandKg: _d(r['on_hand_kg']),
          shortKg: _d(r['short_kg']),
        ),
    ],
    recipe: j['recipe'] is Map
        ? PaintRecipe.fromJson(Map<String, dynamic>.from(j['recipe'] as Map))
        : const PaintRecipe(),
    owed: [for (final r in _rows(j['owed'])) PaintOwed.fromJson(r)],
    suppliers: [
      for (final r in _rows(j['suppliers']))
        (
          id: '${r['supplier']}',
          name: '${r['name'] ?? r['supplier']}',
          city: _s(r['city']),
          paint: r['paint'] == true,
          contact: _s(r['contact']),
          phone: _s(r['phone']),
          whatsapp: _s(r['whatsapp']),
          minOrder: _s(r['min_order']),
          note: _s(r['note']),
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
    deliveryOwed: [
      for (final r in _rows(j['delivery_owed']))
        (
          receipt: '${r['receipt']}',
          date: '${r['date'] ?? ''}',
          amount: _dn(r['amount']),
          employee: _s(r['employee']),
          transport: _s(r['transport']),
          driver: _s(r['driver']),
          phone: _s(r['phone']),
          supplier: _s(r['supplier']),
        ),
    ],
  );

  final List<PaintItem> paints;
  final List<PaintNeed> queue;
  final double kgPerM2;
  final List<PaintOwed> owed;
  final List<PaintSupplier> suppliers;
  final PaintUsage? usage;
  final List<PaintDeliveryOwed> deliveryOwed;

  /// Primer, hardener, thinner the queue needs, whatever its colours.
  final List<PaintMaterialNeed> materials;
  final PaintRecipe recipe;

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
    for (final p in paints) ?p.base,
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
