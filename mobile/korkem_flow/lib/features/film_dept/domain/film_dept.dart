import 'package:flutter/foundation.dart';

/// What moved a film's metres: a receipt, a sale, a hand-over to our own
/// shop, a write-off (owner, 10.11.2026 — the film department).
enum FilmMoveKind {
  receipt,
  sale,
  shop,
  writeOff,
  other;

  static FilmMoveKind of(Object? wire) => switch ('$wire') {
    'receipt' => FilmMoveKind.receipt,
    'sale' => FilmMoveKind.sale,
    'shop' => FilmMoveKind.shop,
    'write_off' => FilmMoveKind.writeOff,
    _ => FilmMoveKind.other,
  };
}

/// One line of a film's history: metres in (plus) or out (minus).
@immutable
class FilmMove {
  const FilmMove({
    required this.entry,
    required this.date,
    required this.kind,
    required this.metres,
    this.priceM,
    this.party,
    this.reason,
  });

  factory FilmMove.fromJson(Map<String, dynamic> json) => FilmMove(
    entry: '${json['entry'] ?? ''}',
    date: '${json['date'] ?? ''}',
    kind: FilmMoveKind.of(json['kind']),
    metres: _d(json['metres']) ?? 0,
    priceM: _d(json['price_m']),
    party: _s(json['party']),
    reason: _s(json['reason']),
  );

  final String entry;
  final String date;
  final FilmMoveKind kind;
  final double metres;

  /// Bought at, or sold at, per metre; null when hidden or not money.
  final double? priceM;

  /// The supplier, the customer, or the order it went to the shop for.
  final String? party;
  final String? reason;
}

/// A film in a sale: so many metres at so much a metre.
@immutable
class FilmSaleLine {
  const FilmSaleLine({
    required this.item,
    required this.title,
    required this.metres,
    this.priceM,
  });

  factory FilmSaleLine.fromJson(Map<String, dynamic> json) => FilmSaleLine(
    item: '${json['item'] ?? ''}',
    title: '${json['title'] ?? ''}',
    metres: _d(json['metres']) ?? 0,
    priceM: _d(json['price_m']),
  );

  final String item;
  final String title;
  final double metres;
  final double? priceM;
}

/// A sale of film to a customer — paid, or partly, the rest a debt.
@immutable
class FilmSale {
  const FilmSale({
    required this.entry,
    required this.date,
    this.customer,
    this.customerName,
    this.amount,
    this.paid,
    this.debt,
    this.method,
    this.bank,
    this.lines = const [],
    this.payments = const [],
  });

  factory FilmSale.fromJson(Map<String, dynamic> json) => FilmSale(
    entry: '${json['entry'] ?? ''}',
    date: '${json['date'] ?? ''}',
    customer: _s(json['customer']),
    customerName: _s(json['customer_name']),
    amount: _d(json['amount']),
    paid: _d(json['paid']),
    debt: _d(json['debt']),
    method: _s(json['method']),
    bank: _s(json['bank']),
    lines: [
      for (final l in json['lines'] as List? ?? const [])
        if (l is Map<String, dynamic>) FilmSaleLine.fromJson(l),
    ],
    payments: [
      for (final p in json['payments'] as List? ?? const [])
        if (p is Map<String, dynamic>)
          (
            date: '${p['date'] ?? ''}',
            amount: _d(p['amount']) ?? 0,
            method: '${p['method'] ?? ''}',
            bank: _s(p['bank']),
          ),
    ],
  );

  final String entry;
  final String date;
  final String? customer;
  final String? customerName;
  final double? amount;
  final double? paid;
  final double? debt;
  final String? method;
  final String? bank;
  final List<FilmSaleLine> lines;

  /// Every payment of the sale — at the sale and against its debt, each
  /// way of its own (owner, 11.11.2026: cash and a transfer at once).
  final List<FilmPayment> payments;

  double get metres => lines.fold(0, (sum, l) => sum + l.metres);
}

/// What a metre of a film costs a customer: the tier's price less the
/// customer's own discount.
@immutable
class FilmPrice {
  const FilmPrice({
    this.wholesale = false,
    this.discount = 0,
    this.baseM,
    this.priceM,
  });

  factory FilmPrice.fromJson(Map<String, dynamic> json) => FilmPrice(
    wholesale: json['tier'] == 'wholesale',
    discount: _d(json['discount']) ?? 0,
    baseM: _d(json['base_m']),
    priceM: _d(json['price_m']),
  );

  final bool wholesale;
  final double discount;
  final double? baseM;
  final double? priceM;
}

/// Who buys film: this month, in all, when last — and who fell asleep.
@immutable
class FilmCustomer {
  const FilmCustomer({
    required this.customer,
    required this.name,
    this.phone,
    this.wholesale = false,
    this.discount = 0,
    this.monthM = 0,
    this.totalM = 0,
    this.total = 0,
    this.debt = 0,
    this.last,
    this.idleDays,
    this.asleep = false,
  });

  factory FilmCustomer.fromJson(Map<String, dynamic> json) => FilmCustomer(
    customer: '${json['customer'] ?? ''}',
    name: '${json['name'] ?? json['customer'] ?? ''}',
    phone: _s(json['phone']),
    wholesale: json['tier'] == 'wholesale',
    discount: _d(json['discount']) ?? 0,
    monthM: _d(json['month_m']) ?? 0,
    totalM: _d(json['total_m']) ?? 0,
    total: _d(json['total']) ?? 0,
    debt: _d(json['debt']) ?? 0,
    last: _s(json['last']),
    idleDays: (json['idle_days'] as num?)?.toInt(),
    asleep: json['asleep'] == true,
  );

  final String customer;
  final String name;
  final String? phone;
  final bool wholesale;
  final double discount;
  final double monthM;
  final double totalM;
  final double total;
  final double debt;
  final String? last;
  final int? idleDays;

  /// Bought before and has not for two months: worth a call.
  final bool asleep;
}

/// Metres as the shop says them: «84», «1,5».
String filmMetres(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}

double? _d(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s.replaceAll(',', '.')),
  _ => null,
};

String? _s(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// One part of a payment: how much, how, and the bank of a transfer or a
/// card.
typedef FilmPayment = ({
  String date,
  double amount,
  String method,
  String? bank,
});
