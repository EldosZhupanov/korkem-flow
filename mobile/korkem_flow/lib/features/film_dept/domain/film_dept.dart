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
    this.struck = false,
    this.fixReason,
    this.fixBy,
    this.fixAt,
    this.delivery,
    this.seller,
  });

  factory FilmMove.fromJson(Map<String, dynamic> json) => FilmMove(
    entry: '${json['entry'] ?? ''}',
    date: '${json['date'] ?? ''}',
    kind: FilmMoveKind.of(json['kind']),
    metres: _d(json['metres']) ?? 0,
    priceM: _d(json['price_m']),
    party: _s(json['party']),
    reason: _s(json['reason']),
    struck: json['struck'] == true,
    fixReason: switch (json['fix']) {
      final Map<String, dynamic> f => _s(f['reason']),
      _ => null,
    },
    fixBy: switch (json['fix']) {
      final Map<String, dynamic> f => _s(f['by']),
      _ => null,
    },
    fixAt: switch (json['fix']) {
      final Map<String, dynamic> f => _s(f['at']),
      _ => null,
    },
    delivery: switch (json['delivery']) {
      final Map<String, dynamic> d => (
        transport: _s(d['transport']),
        city: _s(d['city']),
        cost: _d(d['cost']),
        perM: _d(d['per_m']),
        urgent: d['urgent'] == true,
        receivedBy: _s(d['received_by']),
      ),
      _ => null,
    },
    seller: _s(json['seller']),
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

  /// Entered wrong and made again right: shown struck through (owner,
  /// 11.11.2026).
  final bool struck;

  /// On the movement that made a wrong one right: why, who, when.
  final String? fixReason;
  final String? fixBy;
  final String? fixAt;

  bool get fixed => fixAt != null;

  /// How a receipt came, what bringing it cost, who took it in (owner,
  /// 11.11.2026); null for any other movement.
  final FilmDelivery? delivery;

  /// Who sold it, on a sale.
  final String? seller;
}

typedef FilmDelivery = ({
  String? transport,
  String? city,
  double? cost,
  double? perM,
  bool urgent,
  String? receivedBy,
});

/// What a receipt asks about its delivery and a sale about its seller.
@immutable
class FilmDeliveryOptions {
  const FilmDeliveryOptions({
    this.transports = const [],
    this.cities = const [],
    this.last = const {},
    this.supplierCities = const {},
    this.staff = const [],
    this.me,
  });

  factory FilmDeliveryOptions.fromJson(Map<String, dynamic> json) =>
      FilmDeliveryOptions(
        transports: [for (final t in json['transports'] as List? ?? []) '$t'],
        cities: [for (final c in json['cities'] as List? ?? []) '$c'],
        last: {
          if (json['last'] case final Map<String, dynamic> last)
            for (final e in last.entries)
              if (e.value case final Map<String, dynamic> v)
                e.key: (
                  transport: _s(v['transport']),
                  city: _s(v['city']),
                ),
        },
        supplierCities: {
          if (json['supplier_cities'] case final Map<String, dynamic> by)
            for (final e in by.entries) e.key: '${e.value}',
        },
        staff: [
          for (final p in json['staff'] as List? ?? [])
            if (p is Map<String, dynamic>)
              (user: '${p['user']}', name: '${p['name'] ?? p['user']}'),
        ],
        me: _s(json['me']),
      );

  final List<String> transports;
  final List<String> cities;

  /// Supplier → how its last roll came.
  final Map<String, ({String? transport, String? city})> last;

  /// Supplier → its city, from its card.
  final Map<String, String> supplierCities;
  final List<({String user, String name})> staff;
  final String? me;
}

/// The film department's month by seller, and the team's bonus.
@immutable
class FilmTeam {
  const FilmTeam({
    required this.month,
    this.rows = const [],
    this.metres = 0,
    this.sales = 0,
    this.paid = 0,
    this.margin = 0,
    this.planM = 0,
    this.done,
    this.pct = 0,
    this.pot = 0,
    this.settings,
    this.canSet = false,
  });

  factory FilmTeam.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>? ?? const {};
    final conf = json['settings'];
    return FilmTeam(
      month: '${json['month'] ?? ''}',
      rows: [
        for (final r in json['rows'] as List? ?? [])
          if (r is Map<String, dynamic>)
            (
              seller: '${r['seller']}',
              name: '${r['name'] ?? r['seller']}',
              metres: _d(r['metres']) ?? 0,
              sales: (r['sales'] as num?)?.toInt() ?? 0,
              paid: _d(r['paid']) ?? 0,
              margin: _d(r['margin']) ?? 0,
              share: _d(r['share']) ?? 0,
              bonus: _d(r['bonus']) ?? 0,
            ),
      ],
      metres: _d(team['metres']) ?? 0,
      sales: (team['sales'] as num?)?.toInt() ?? 0,
      paid: _d(team['paid']) ?? 0,
      margin: _d(team['margin']) ?? 0,
      planM: _d(json['plan_m']) ?? 0,
      done: _d(json['done']),
      pct: _d(json['pct']) ?? 0,
      pot: _d(json['pot']) ?? 0,
      settings: conf is Map<String, dynamic>
          ? (
              planM: _d(conf['plan_m']) ?? 0,
              pct: _d(conf['pct']) ?? 0,
              pctBelow: _d(conf['pct_below']) ?? 0,
            )
          : null,
      canSet: json['can_set'] == true,
    );
  }

  final String month;
  final List<FilmTeamRow> rows;
  final double metres;
  final int sales;
  final double paid;
  final double margin;
  final double planM;

  /// Per cent of the plan made; null with no plan.
  final double? done;

  /// The pot's share this month — the plan's, or the lower one.
  final double pct;
  final double pot;

  /// The owner's own: the plan and the two shares.
  final ({double planM, double pct, double pctBelow})? settings;
  final bool canSet;
}

typedef FilmTeamRow = ({
  String seller,
  String name,
  double metres,
  int sales,
  double paid,
  double margin,
  double share,
  double bonus,
});

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
