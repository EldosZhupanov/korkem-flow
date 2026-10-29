import 'package:meta/meta.dart';

double _number(Object? value) => value is num ? value.toDouble() : 0;

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// One delivery: what bringing material in cost, from where, by what.
@immutable
class Delivery {
  const Delivery({
    required this.delivery,
    required this.deliveredOn,
    required this.category,
    required this.amount,
    required this.fromCity,
    required this.transport,
    this.orderedOn,
    this.days,
    this.carrier,
    this.urgent = false,
    this.supplierName,
    this.salesOrder,
    this.receipt,
    this.what,
    this.qty,
    this.unit,
    this.note,
    this.cancelled = false,
    this.cancelReason,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    delivery: '${json['delivery'] ?? ''}',
    deliveredOn: '${json['delivered_on'] ?? ''}',
    orderedOn: _text(json['ordered_on']),
    days: (json['days'] as num?)?.toInt(),
    category: '${json['category'] ?? ''}',
    amount: _number(json['amount']),
    fromCity: '${json['from_city'] ?? ''}',
    transport: '${json['transport'] ?? ''}',
    carrier: _text(json['carrier']),
    urgent: json['urgent'] == true,
    supplierName: _text(json['supplier_name']) ?? _text(json['supplier']),
    salesOrder: _text(json['sales_order']),
    receipt: _text(json['receipt']),
    what: _text(json['what']),
    qty: (json['qty'] as num?)?.toDouble(),
    unit: _text(json['unit']),
    note: _text(json['note']),
    cancelled: json['cancelled'] == true,
    cancelReason: _text(json['cancel_reason']),
  );

  final String delivery;
  final String deliveredOn;
  final String? orderedOn;

  /// From ordered to arrived — how long the road took.
  final int? days;
  final String category;
  final double amount;
  final String fromCity;
  final String transport;
  final String? carrier;
  final bool urgent;
  final String? supplierName;
  final String? salesOrder;
  final String? receipt;
  final String? what;
  final double? qty;
  final String? unit;
  final String? note;
  final bool cancelled;
  final String? cancelReason;
}

/// One line of a breakdown: a category, a city, a way of delivery.
typedef LogisticsGroup = ({
  String name,
  double amount,
  int count,
  double? averageDays,
});

/// ₸ per sheet, ₸ per metre.
typedef PerUnit = ({
  String category,
  String unit,
  double amount,
  double qty,
  double perUnit,
});

/// A receipt nobody has written the delivery of yet.
typedef UnlinkedReceipt = ({
  String receipt,
  String date,
  String? title,
  double? qty,
  String? unit,
});

List<LogisticsGroup> _groups(Object? raw) => [
  for (final g in raw as List? ?? const [])
    if (g is Map)
      (
        name: '${g['name'] ?? ''}',
        amount: _number(g['amount']),
        count: (g['count'] as num?)?.toInt() ?? 0,
        averageDays: (g['average_days'] as num?)?.toDouble(),
      ),
];

/// The month's logistics, counted on the server (`services/logistics.py`).
@immutable
class LogisticsSummary {
  const LogisticsSummary({
    required this.month,
    required this.total,
    required this.count,
    required this.previousTotal,
    required this.byCategory,
    required this.byCity,
    required this.byTransport,
    required this.byCarrier,
    required this.perUnit,
    required this.urgentCount,
    required this.urgentAmount,
    required this.unlinked,
  });

  factory LogisticsSummary.fromJson(Map<String, dynamic> json) {
    final urgent = json['urgent'] is Map
        ? Map<String, dynamic>.from(json['urgent'] as Map)
        : const <String, dynamic>{};
    return LogisticsSummary(
      month: '${json['month'] ?? ''}',
      total: _number(json['total']),
      count: (json['count'] as num?)?.toInt() ?? 0,
      previousTotal: _number(json['previous_total']),
      byCategory: _groups(json['by_category']),
      byCity: _groups(json['by_city']),
      byTransport: _groups(json['by_transport']),
      byCarrier: _groups(json['by_carrier']),
      perUnit: [
        for (final p in json['per_unit'] as List? ?? const [])
          if (p is Map)
            (
              category: '${p['category'] ?? ''}',
              unit: '${p['unit'] ?? ''}',
              amount: _number(p['amount']),
              qty: _number(p['qty']),
              perUnit: _number(p['per_unit']),
            ),
      ],
      urgentCount: (urgent['count'] as num?)?.toInt() ?? 0,
      urgentAmount: _number(urgent['amount']),
      unlinked: [
        for (final r in json['unlinked_receipts'] as List? ?? const [])
          if (r is Map)
            (
              receipt: '${r['receipt'] ?? ''}',
              date: '${r['date'] ?? ''}',
              title: _text(r['title']),
              qty: (r['qty'] as num?)?.toDouble(),
              unit: _text(r['unit']),
            ),
      ],
    );
  }

  final String month;
  final double total;
  final int count;
  final double previousTotal;
  final List<LogisticsGroup> byCategory;
  final List<LogisticsGroup> byCity;
  final List<LogisticsGroup> byTransport;
  final List<LogisticsGroup> byCarrier;
  final List<PerUnit> perUnit;
  final int urgentCount;
  final double urgentAmount;
  final List<UnlinkedReceipt> unlinked;
}

/// What the form offers: the usual ones, then what the shop has used.
@immutable
class LogisticsSuggestions {
  const LogisticsSuggestions({
    required this.cities,
    required this.transports,
    required this.carriers,
    required this.categories,
  });

  factory LogisticsSuggestions.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? raw) => [
      for (final v in raw as List? ?? const []) '$v',
    ];
    return LogisticsSuggestions(
      cities: strings(json['cities']),
      transports: strings(json['transports']),
      carriers: strings(json['carriers']),
      categories: strings(json['categories']),
    );
  }

  final List<String> cities;
  final List<String> transports;
  final List<String> carriers;
  final List<String> categories;
}

/// A delivery being written down.
@immutable
class NewDelivery {
  const NewDelivery({
    required this.amount,
    required this.fromCity,
    required this.transport,
    required this.category,
    this.deliveredOn,
    this.orderedOn,
    this.carrier,
    this.urgent = false,
    this.salesOrder,
    this.receipt,
    this.what,
    this.qty,
    this.unit,
    this.note,
  });

  final double amount;
  final String fromCity;
  final String transport;
  final String category;
  final DateTime? deliveredOn;
  final DateTime? orderedOn;
  final String? carrier;
  final bool urgent;
  final String? salesOrder;
  final String? receipt;
  final String? what;
  final double? qty;
  final String? unit;
  final String? note;

  Map<String, Object> toParams() => {
    'amount': amount,
    'from_city': fromCity,
    'transport': transport,
    'category': category,
    'urgent': urgent ? 1 : 0,
    'delivered_on': ?_day(deliveredOn),
    'ordered_on': ?_day(orderedOn),
    'carrier': ?carrier,
    'sales_order': ?salesOrder,
    'receipt': ?receipt,
    'what': ?what,
    'qty': ?qty,
    'unit': ?unit,
    'note': ?note,
  };
}

String? _day(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

/// «2026-10» for a month.
String monthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-'
    '${month.month.toString().padLeft(2, '0')}';
