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
  });

  final double widthMm;
  final double heightMm;
  final int qty;
  final String milling;
  final String finish;
  final bool doubleSided;
  final bool customerMaterial;

  Map<String, dynamic> toJson() => {
    'width_mm': widthMm,
    'height_mm': heightMm,
    'qty': qty,
    'milling': milling,
    'finish': finish,
    'double_sided': doubleSided ? 1 : 0,
    'customer_material': customerMaterial ? 1 : 0,
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
  const FacadeCustomer({required this.name, required this.title, this.phone});

  factory FacadeCustomer.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? ''}';
    return FacadeCustomer(
      name: name,
      title: json['customer_name'] as String? ?? name,
      phone: json['phone'] as String?,
    );
  }

  final String name;
  final String title;
  final String? phone;
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
