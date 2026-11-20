import 'package:korkem_flow/core/phone/phone.dart';
import 'package:meta/meta.dart';

/// The company's rules for a facade order. `null` means "not offered":
/// the server refuses such a line rather than guessing its price.
@immutable
class FacadeRules {
  const FacadeRules({
    this.doubleSidedFactor,
    this.customerMaterialOffered = false,
    this.customerMaterialDiscountPercent = 0,
    this.demolitionUnit,
    this.demolitionRate,
    this.prepaymentPercent,
  });

  factory FacadeRules.fromJson(Map<String, dynamic> json) => FacadeRules(
    doubleSidedFactor: _num(json['double_sided_factor']),
    customerMaterialOffered: json['customer_material_offered'] == true,
    customerMaterialDiscountPercent:
        _num(json['customer_material_discount_percent']) ?? 0,
    demolitionUnit: json['demolition_unit'] as String?,
    demolitionRate: _num(json['demolition_rate']),
    prepaymentPercent: _num(json['prepayment_percent']),
  );

  /// The choices the server accepts for [demolitionUnit].
  static const demolitionUnits = ['За м²', 'За штуку', 'За заказ'];

  final double? doubleSidedFactor;
  final bool customerMaterialOffered;
  final double customerMaterialDiscountPercent;
  final String? demolitionUnit;
  final double? demolitionRate;
  final double? prepaymentPercent;

  bool get doubleSidedOffered => (doubleSidedFactor ?? 0) >= 1;
  bool get demolitionOffered =>
      demolitionUnit != null && (demolitionRate ?? 0) > 0;
}

/// One facade line as the manager enters it.
@immutable
class FacadeLineInput {
  const FacadeLineInput({
    required this.widthMm,
    required this.heightMm,
    required this.qty,
    required this.milling,
    required this.finish,
    this.doubleSided = false,
    this.customerMaterial = false,
    this.thicknessMm,
    this.decorTop,
    this.decorBottom,
    this.edgeProfile,
  });

  final double widthMm;
  final double heightMm;
  final int qty;
  final String milling;
  final String finish;
  final bool doubleSided;
  final bool customerMaterial;

  /// What the floor reads; none of it changes the price. Values come from the
  /// warehouse lists («Цвет плёнки», «Профиль кромки»).
  final int? thicknessMm;
  final String? decorTop;
  final String? decorBottom;
  final String? edgeProfile;

  Map<String, dynamic> toJson() => {
    'width_mm': widthMm,
    'height_mm': heightMm,
    'qty': qty,
    'milling': milling,
    'finish': finish,
    'double_sided': doubleSided ? 1 : 0,
    'customer_material': customerMaterial ? 1 : 0,
    'thickness_mm': ?thicknessMm,
    'decor_top': ?decorTop,
    'decor_bottom': ?decorBottom,
    'edge_profile': ?edgeProfile,
  };
}

/// The server's answer. Every figure is the server's; none is recomputed here.
@immutable
class FacadeQuote {
  const FacadeQuote({
    required this.pieces,
    required this.areaM2,
    required this.facadesTotal,
    required this.demolition,
    required this.total,
    required this.prepayment,
    required this.balance,
    required this.prepaymentSource,
    this.lineAmounts = const [],
  });

  factory FacadeQuote.fromJson(Map<String, dynamic> json) => FacadeQuote(
    pieces: (json['pieces'] as num?)?.toInt() ?? 0,
    areaM2: _num(json['area_m2']) ?? 0,
    facadesTotal: _num(json['facades_total']) ?? 0,
    demolition: _num(json['demolition']) ?? 0,
    total: _num(json['total']) ?? 0,
    prepayment: _num(json['prepayment']) ?? 0,
    balance: _num(json['balance']) ?? 0,
    prepaymentSource: json['prepayment_source'] as String? ?? 'not_set',
    lineAmounts: [
      for (final line in json['lines'] as List? ?? const [])
        if (line is Map) _num(line['amount']) ?? 0,
    ],
  );

  final int pieces;
  final double areaM2;
  final double facadesTotal;
  final double demolition;
  final double total;
  final double prepayment;
  final double balance;
  final String prepaymentSource;
  final List<double> lineAmounts;
}

double? _num(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// An ERPNext customer an order can be written for.
@immutable
class FacadeCustomer {
  const FacadeCustomer({
    required this.name,
    required this.title,
    this.phone,
    this.organization,
    this.tags = const [],
    this.orders = 0,
    this.debt = 0,
    this.inWork = 0,
    this.lastOrder,
    this.lastOn,
    this.lastGroups = const [],
    this.lastMillings = const [],
    this.objects = const [],
    this.orderNames = const [],
    this.terms = const MdfCustomerTerms(),
    this.limit = 0,
  });

  factory FacadeCustomer.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? ''}';
    List<String> strings(Object? v) => [
      for (final s in v is List ? v : const <Object>[]) '$s',
    ];
    return FacadeCustomer(
      name: name,
      title: json['customer_name'] as String? ?? name,
      phone: Phone.prettyOrNull(json['phone'] as String?),
      organization: json['organization'] as String?,
      tags: strings(json['tags']),
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
      inWork: (json['in_work'] as num?)?.toInt() ?? 0,
      lastOrder: json['last_order'] as String?,
      lastOn: json['last_on'] as String?,
      lastGroups: [
        for (final g in json['last_groups'] as List? ?? const [])
          if (g is Map)
            (
              coating: g['coating'] as String?,
              film: g['film'] as String?,
            ),
      ],
      lastMillings: strings(json['last_millings']),
      objects: strings(json['objects']),
      orderNames: strings(json['order_names']),
      terms: MdfCustomerTerms.fromJson(json),
      limit: (json['limit'] as num?)?.toDouble() ?? 0,
    );
  }

  final String name;
  final String title;
  final String? phone;

  /// «ИП Куат», «Дом Мебели» — OnayBaza's third column.
  final String? organization;

  /// The customer's tag codes (vip, prepay_only …) — the MDF order's
  /// customer list sets them.
  final List<String> tags;

  // What the order form's customer window says of him before he is chosen
  // (owner, 20.11.2026); empty for a customer without facade orders.

  /// His facade orders, all of them.
  final int orders;

  /// What he owes, ₸.
  final double debt;

  /// His orders not handed over yet.
  final int inWork;

  /// His latest order and its day (yyyy-mm-dd).
  final String? lastOrder;
  final String? lastOn;

  /// What the latest order was: its coatings with their colours (the
  /// coating as its wire — pvc, paint, raw) and its millings.
  final List<({String? coating, String? film})> lastGroups;
  final List<String> lastMillings;

  /// What he is found by besides his name: his objects, his order numbers.
  final List<String> objects;
  final List<String> orderNames;

  /// His own terms: prices, debt limit, where he came from.
  final MdfCustomerTerms terms;

  /// His debt limit — his own, else the shop's; 0 — none.
  final double limit;
}

/// Where a customer came from (owner, 20.11.2026: «в основном сарафанное,
/// инстаграм, 2гис»).
enum MdfCustomerSource {
  word('word'),
  instagram('instagram'),
  twoGis('2gis'),
  repeat('repeat'),
  other('other');

  const MdfCustomerSource(this.wire);

  final String wire;

  static MdfCustomerSource? parse(Object? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return null;
  }
}

/// A customer's own terms (owner, 20.11.2026): a furniture maker pays «по
/// разному» — a discount off the price list, or his own price a m² by
/// coating; a debt limit of his own; where he came from. Zero is «none».
@immutable
class MdfCustomerTerms {
  const MdfCustomerTerms({
    this.discountPct = 0,
    this.pricePvcM2 = 0,
    this.pricePaintM2 = 0,
    this.debtLimit = 0,
    this.source,
  });

  factory MdfCustomerTerms.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => v is num ? v.toDouble() : 0;
    return MdfCustomerTerms(
      discountPct: d(j['discount_pct']),
      pricePvcM2: d(j['price_pvc_m2']),
      pricePaintM2: d(j['price_paint_m2']),
      debtLimit: d(j['debt_limit']),
      source: MdfCustomerSource.parse(j['source']),
    );
  }

  final double discountPct;
  final double pricePvcM2;
  final double pricePaintM2;
  final double debtLimit;
  final MdfCustomerSource? source;

  /// He pays otherwise than the price list.
  bool get ownPrice => discountPct > 0 || pricePvcM2 > 0 || pricePaintM2 > 0;

  Map<String, Object?> toJson() => {
    'discount_pct': discountPct,
    'price_pvc_m2': pricePvcM2,
    'price_paint_m2': pricePaintM2,
    'debt_limit': debtLimit,
    'source': source?.wire,
  };
}

/// The order the server created from a quote.
@immutable
class FacadeOrderResult {
  const FacadeOrderResult({
    required this.salesOrder,
    required this.total,
    required this.prepayment,
    required this.balance,
  });

  factory FacadeOrderResult.fromJson(Map<String, dynamic> json) =>
      FacadeOrderResult(
        salesOrder: '${json['sales_order'] ?? ''}',
        total: _num(json['total']) ?? 0,
        prepayment: _num(json['prepayment']) ?? 0,
        balance: _num(json['balance']) ?? 0,
      );

  final String salesOrder;
  final double total;
  final double prepayment;
  final double balance;
}
