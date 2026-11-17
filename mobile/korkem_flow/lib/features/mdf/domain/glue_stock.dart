import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/paint_stock.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(Object? v) => v == null ? null : _d(v);
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _rows(Object? v) => [
  for (final r in v is List ? v : const <Object>[])
    if (r is Map) Map<String, dynamic>.from(r),
];

/// What a m² of a glue really took over the last month (owner, 17.11.2026).
@immutable
class GlueFact {
  const GlueFact({
    required this.m2,
    required this.kgByNorm,
    required this.kgCounted,
    this.factGM2,
  });

  factory GlueFact.fromJson(Map<String, dynamic> j) => GlueFact(
    m2: _d(j['m2']),
    kgByNorm: _d(j['kg_by_norm']),
    kgCounted: _d(j['kg_counted']),
    factGM2: _dn(j['fact_g_m2']),
  );

  final double m2;
  final double kgByNorm;
  final double kgCounted;
  final double? factGM2;
}

/// A PVC glue: what it is and what it costs — apart from who sells it.
@immutable
class GlueItem {
  const GlueItem({
    required this.item,
    required this.title,
    required this.kgPerLitre,
    required this.normGM2,
    required this.onHandKg,
    this.origin,
    this.bucketKg,
    this.reserveKg = 0,
    this.markupBucket = 0,
    this.markupLitre = 0,
    this.inWork = false,
    this.costKg,
    this.costM2,
    this.sellBucket,
    this.sellLitre,
    this.fact,
  });

  factory GlueItem.fromJson(Map<String, dynamic> j) {
    final sell = j['sell'] is Map
        ? Map<String, dynamic>.from(j['sell'] as Map)
        : const <String, dynamic>{};
    return GlueItem(
      item: '${j['item']}',
      title: '${j['title'] ?? ''}',
      origin: _s(j['origin']),
      bucketKg: _dn(j['bucket_kg']),
      kgPerLitre: _d(j['kg_per_litre'] ?? 1),
      normGM2: _d(j['norm_g_m2'] ?? 100),
      reserveKg: _d(j['reserve_kg']),
      markupBucket: _d(j['markup_bucket']),
      markupLitre: _d(j['markup_litre']),
      inWork: j['in_work'] == true,
      onHandKg: _d(j['on_hand_kg']),
      costKg: _dn(j['cost_kg']),
      costM2: _dn(j['cost_m2']),
      sellBucket: _dn(sell['bucket']),
      sellLitre: _dn(sell['litre']),
      fact: j['fact'] is Map
          ? GlueFact.fromJson(Map<String, dynamic>.from(j['fact'] as Map))
          : null,
    );
  }

  final String item;
  final String title;
  final String? origin;
  final double? bucketKg;
  final double kgPerLitre;
  final double normGM2;
  final double reserveKg;
  final double markupBucket;
  final double markupLitre;
  final bool inWork;
  final double onHandKg;

  /// A kilo with its bringing, over recent receipts.
  final double? costKg;
  final double? costM2;
  final double? sellBucket;
  final double? sellLitre;
  final GlueFact? fact;
}

/// What a glue's card says, as written in the dialog.
typedef GlueCard = ({
  String name,
  String? origin,
  double? bucketKg,
  double kgPerLitre,
  double normGM2,
  double reserveKg,
  double markupBucket,
  double markupLitre,
});

/// The last receipt of a glue from a supplier: a kilo, its bringing, both.
@immutable
class GlueBought {
  const GlueBought({
    required this.item,
    required this.title,
    required this.date,
    this.priceKg,
    this.deliveryKg,
    this.landedKg,
    this.cheapest = false,
  });

  factory GlueBought.fromJson(Map<String, dynamic> j) => GlueBought(
    item: '${j['item']}',
    title: '${j['title'] ?? ''}',
    date: '${j['date'] ?? ''}',
    priceKg: _dn(j['price_kg']),
    deliveryKg: _dn(j['delivery_kg']),
    landedKg: _dn(j['landed_kg']),
    cheapest: j['cheapest'] == true,
  );

  final String item;
  final String title;
  final String date;
  final double? priceKg;
  final double? deliveryKg;
  final double? landedKg;
  final bool cheapest;
}

/// A company that sells glue — the same one may sell film too.
@immutable
class GlueSupplier {
  const GlueSupplier({
    required this.id,
    required this.name,
    this.city,
    this.contact,
    this.phone,
    this.whatsapp,
    this.minOrder,
    this.note,
    this.bought = const [],
  });

  factory GlueSupplier.fromJson(Map<String, dynamic> j) => GlueSupplier(
    id: '${j['supplier']}',
    name: '${j['name'] ?? j['supplier']}',
    city: _s(j['city']),
    contact: _s(j['contact']),
    phone: _s(j['phone']),
    whatsapp: _s(j['whatsapp']),
    minOrder: _s(j['min_order']),
    note: _s(j['note']),
    bought: [for (final b in _rows(j['bought'])) GlueBought.fromJson(b)],
  );

  final String id;
  final String name;
  final String? city;
  final String? contact;
  final String? phone;
  final String? whatsapp;
  final String? minOrder;
  final String? note;
  final List<GlueBought> bought;

  /// The card dialog is the paint supplier's: the same fields.
  PaintSupplier get asCard => (
    id: id,
    name: name,
    city: city,
    paint: false,
    contact: contact,
    phone: phone,
    whatsapp: whatsapp,
    minOrder: minOrder,
    note: note,
  );
}

/// Glue bought on credit or by invoice, not paid yet.
typedef GlueOwed = ({
  String receipt,
  String date,
  String glue,
  double kg,
  double? amount,
  String supplier,
  String? invoiceNo,
  String? dueOn,
  bool overdue,
});

/// «Клей для ПВХ» (owner, 17.11.2026): each glue, who sells it, what the
/// vacuum queue needs, what is owed.
@immutable
class GlueStock {
  const GlueStock({
    required this.glues,
    this.inWork,
    this.queueKg = 0,
    this.queueM2 = 0,
    this.queueOrders = 0,
    this.queueShortKg = 0,
    this.milling = const {},
    this.edgeCoats = 2,
    this.suppliers = const [],
    this.owed = const [],
    this.pricesVisible = false,
    this.canEdit = false,
  });

  factory GlueStock.fromJson(Map<String, dynamic> j) {
    final queue = j['queue'] is Map
        ? Map<String, dynamic>.from(j['queue'] as Map)
        : const <String, dynamic>{};
    return GlueStock(
      glues: [for (final g in _rows(j['glues'])) GlueItem.fromJson(g)],
      inWork: _s(j['in_work']),
      queueKg: _d(queue['kg']),
      queueM2: _d(queue['m2']),
      queueOrders: _d(queue['orders']).round(),
      queueShortKg: _d(queue['short_kg']),
      milling: {
        for (final m in _rows(j['milling']))
          '${m['name']}': _d(m['factor'] ?? 1),
      },
      edgeCoats: _d(j['edge_coats'] ?? 2).round(),
      suppliers: [
        for (final s in _rows(j['suppliers'])) GlueSupplier.fromJson(s),
      ],
      owed: [
        for (final o in _rows(j['owed']))
          (
            receipt: '${o['receipt']}',
            date: '${o['date'] ?? ''}',
            glue: '${o['glue'] ?? ''}',
            kg: _d(o['kg']),
            amount: _dn(o['amount']),
            supplier: '${o['supplier'] ?? ''}',
            invoiceNo: _s(o['invoice_no']),
            dueOn: _s(o['due_on']),
            overdue: o['overdue'] == true,
          ),
      ],
      pricesVisible: j['prices_visible'] == true,
      canEdit: j['can_edit'] == true,
    );
  }

  final List<GlueItem> glues;
  final String? inWork;
  final double queueKg;
  final double queueM2;
  final int queueOrders;
  final double queueShortKg;

  /// A milling's factor: how much more glue than a smooth face.
  final Map<String, double> milling;
  final int edgeCoats;
  final List<GlueSupplier> suppliers;
  final List<GlueOwed> owed;
  final bool pricesVisible;
  final bool canEdit;

  GlueItem? get working => glues.where((g) => g.inWork).firstOrNull;
}

/// The glue an order takes, by the glue in work (owner, 17.11.2026).
@immutable
class OrderGlue {
  const OrderGlue({
    required this.kg,
    required this.m2,
    required this.normGM2,
    this.title,
  });

  factory OrderGlue.fromJson(Map<String, dynamic> j) => OrderGlue(
    kg: _d(j['kg']),
    m2: _d(j['m2']),
    normGM2: _d(j['norm_g_m2'] ?? 100),
    title: _s(j['title']),
  );

  final double kg;
  final double m2;
  final double normGM2;
  final String? title;
}

/// The units a glue is counted in, bought and sold by.
enum GlueUnit {
  kg('кг'),
  litre('л'),
  bucket('ведро');

  const GlueUnit(this.wire);

  final String wire;
}
