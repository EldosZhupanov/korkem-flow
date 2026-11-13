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
    this.supplierOwed = false,
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
        payer: _s(d['payer']),
        paidBy: _s(d['paid_by']),
        settled: d['settled'] == true,
        driver: _s(d['driver']),
        phone: _s(d['phone']),
      ),
      _ => null,
    },
    seller: _s(json['seller']),
    supplierOwed: json['supplier_owed'] == true,
  );

  /// Taken from the supplier on credit and not paid for yet.
  final bool supplierOwed;

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
  String? payer,
  String? paidBy,
  bool settled,
  String? driver,
  String? phone,
});

/// Who paid for bringing a roll (owner, 11.11.2026) — the server's words.
/// Where the money paying a supplier came from (owner, 14.11.2026).
abstract final class FilmPaySource {
  /// The film department's own money: out of its cash book.
  static const dept = 'dept';

  /// The owner's, the MDF side's: the film cash is not touched.
  static const elsewhere = 'elsewhere';
}

abstract final class FilmPayer {
  static const cash = 'cash';
  static const employee = 'employee';
  static const unpaid = 'unpaid';
  static const supplier = 'supplier';
}

/// The film department's own cash book over a period, and what is owed.
@immutable
class FilmCashBook {
  const FilmCashBook({
    required this.since,
    required this.until,
    this.ins = const [],
    this.inTotal = 0,
    this.outs = const [],
    this.outTotal = 0,
    this.balance = 0,
    this.logistics = 0,
    this.logisticsPerM,
    this.employees = const [],
    this.carriers = const [],
    this.suppliers = const [],
    this.sales = 0,
    this.spent = 0,
    this.where = const [],
    this.moves = const [],
    this.closed,
    this.days = const [],
    this.previous,
  });

  factory FilmCashBook.fromJson(Map<String, dynamic> json) {
    final owed = json['owed'] as Map<String, dynamic>? ?? const {};
    FilmOwed row(Map<String, dynamic> r) => (
      receipt: '${r['receipt']}',
      date: '${r['date'] ?? ''}',
      amount: _d(r['amount']) ?? 0,
      who: _s(r['name']) ?? _s(r['driver']) ?? _s(r['transport']),
      supplier: _s(r['supplier']),
      phone: _s(r['phone']),
    );
    return FilmCashBook(
      since: '${json['since'] ?? ''}',
      until: '${json['until'] ?? ''}',
      ins: [
        for (final r in json['in'] as List? ?? const [])
          if (r is Map<String, dynamic>)
            (way: '${r['way']}', amount: _d(r['amount']) ?? 0),
      ],
      inTotal: _d(json['in_total']) ?? 0,
      outs: [
        for (final r in json['out'] as List? ?? const [])
          if (r is Map<String, dynamic>)
            (
              date: '${r['date'] ?? ''}',
              what: '${r['what'] ?? ''}',
              amount: _d(r['amount']) ?? 0,
              way: _s(r['way']),
            ),
      ],
      outTotal: _d(json['out_total']) ?? 0,
      balance: _d(json['balance']) ?? 0,
      logistics: _d(json['logistics']) ?? 0,
      logisticsPerM: _d(json['logistics_per_m']),
      employees: [
        for (final r in owed['employees'] as List? ?? const [])
          if (r is Map<String, dynamic>) row(r),
      ],
      carriers: [
        for (final r in owed['carriers'] as List? ?? const [])
          if (r is Map<String, dynamic>) row(r),
      ],
      // Film taken on credit: the supplier, and what film.
      suppliers: [
        for (final r in owed['suppliers'] as List? ?? const [])
          if (r is Map<String, dynamic>)
            (
              receipt: '${r['receipt']}',
              date: '${r['date'] ?? ''}',
              amount: _d(r['amount']) ?? 0,
              who: _s(r['supplier']),
              supplier: _s(r['film']),
              phone: null,
            ),
      ],
      sales: (json['sales'] as num?)?.toInt() ?? 0,
      closed: switch (json['closed']) {
        final Map<String, dynamic> c => (
          expected: _d(c['expected']) ?? 0,
          counted: _d(c['counted']) ?? 0,
          gap: _d(c['gap']) ?? 0,
          reason: _s(c['reason']),
          by: _s(c['by']),
        ),
        _ => null,
      },
      spent: (json['spent'] as num?)?.toInt() ?? 0,
      where: [
        for (final r in json['where'] as List? ?? const [])
          if (r is Map<String, dynamic>)
            (way: '${r['way']}', amount: _d(r['amount']) ?? 0),
      ],
      days: [
        for (final r in json['days'] as List? ?? const [])
          if (r is Map<String, dynamic>)
            (
              date: '${r['date'] ?? ''}',
              incoming: _d(r['in']) ?? 0,
              outgoing: _d(r['out']) ?? 0,
            ),
      ],
      previous: switch (json['previous']) {
        final Map<String, dynamic> p => (
          inTotal: _d(p['in_total']) ?? 0,
          outTotal: _d(p['out_total']) ?? 0,
        ),
        _ => null,
      },
      moves: [
        for (final r in json['moves'] as List? ?? const [])
          if (r is Map<String, dynamic>)
            (
              date: '${r['date'] ?? ''}',
              at: _s(r['at']),
              incoming: r['in'] == true,
              amount: _d(r['amount']) ?? 0,
              way: _s(r['way']),
              what: '${r['what'] ?? ''}',
            ),
      ],
    );
  }

  final String since;
  final String until;
  final List<({String way, double amount})> ins;
  final double inTotal;
  final List<({String date, String what, double amount, String? way})> outs;
  final double outTotal;
  final double balance;

  /// What bringing film cost in the period — shown, not in the bonus.
  final double logistics;
  final double? logisticsPerM;

  /// Owed back to employees who paid out of their pocket.
  final List<FilmOwed> employees;

  /// Owed to carriers not paid yet.
  final List<FilmOwed> carriers;

  /// In and out day by day, every day of the period — for the chart.
  final List<({String date, double incoming, double outgoing})> days;

  /// The period of the same length just before, to compare with.
  final ({double inTotal, double outTotal})? previous;

  /// Film taken from suppliers on credit, not paid for yet: `who` is the
  /// supplier, `supplier` the film.
  final List<FilmOwed> suppliers;

  /// The day closed: the cash counted against what should be there.
  final ({
    double expected,
    double counted,
    double gap,
    String? reason,
    String? by,
  })?
  closed;

  /// How many sales paid in, how many things paid out (12.11.2026).
  final int sales;
  final int spent;

  /// Where the money is now: cash in the drawer, each bank apart.
  final List<({String way, double amount})> where;

  /// Every payment in and out, newest first.
  final List<
    ({
      String date,
      String? at,
      bool incoming,
      double amount,
      String? way,
      String what,
    })
  >
  moves;
}

typedef FilmOwed = ({
  String receipt,
  String date,
  double amount,
  String? who,
  String? supplier,
  String? phone,
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
    this.drivers = const [],
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
        drivers: [
          for (final d in json['drivers'] as List? ?? [])
            if (d is Map<String, dynamic>)
              (
                driver: '${d['driver']}',
                phone: _s(d['phone']),
                transport: _s(d['transport']),
              ),
        ],
      );

  final List<String> transports;
  final List<String> cities;

  /// Supplier → how its last roll came.
  final Map<String, ({String? transport, String? city})> last;

  /// Supplier → its city, from its card.
  final Map<String, String> supplierCities;
  final List<({String user, String name})> staff;
  final String? me;

  /// Drivers who brought film before, newest first (owner, 12.11.2026).
  final List<({String driver, String? phone, String? transport})> drivers;
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
    this.maker,
    this.colour,
    this.code,
    this.type,
    this.thicknessMm,
  });

  factory FilmSaleLine.fromJson(Map<String, dynamic> json) => FilmSaleLine(
    item: '${json['item'] ?? ''}',
    title: '${json['title'] ?? ''}',
    metres: _d(json['metres']) ?? 0,
    priceM: _d(json['price_m']),
    maker: _s(json['maker']),
    colour: _s(json['colour']),
    code: _s(json['code']),
    type: _s(json['type']),
    thicknessMm: _d(json['thickness_mm']),
  );

  final String item;
  final String title;
  final double metres;
  final double? priceM;

  /// What the film is, for the customer's receipt (owner, 12.11.2026).
  final String? maker;
  final String? colour;
  final String? code;
  final String? type;
  final double? thicknessMm;
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
    this.seller,
    this.sellerPhone,
    this.issuedBy,
    this.time,
    this.wholesale = false,
    this.cost,
    this.note,
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
    seller: _s(json['seller']),
    sellerPhone: _s(json['seller_phone']),
    issuedBy: _s(json['issued_by']),
    time: _s(json['time']),
    wholesale: json['wholesale'] == true,
    cost: _d(json['cost']),
    note: _s(json['note']),
  );

  final String entry;
  final String date;

  /// «14:20» — the hour of the sale (owner, 13.11.2026).
  final String? time;

  /// The customer buys at the trade price.
  final bool wholesale;

  /// What the film cost at the shelf — for those who see prices.
  final double? cost;
  final String? note;

  /// What the sale earned over the film's cost.
  double? get profit =>
      amount != null && cost != null && cost! > 0 ? amount! - cost! : null;
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

  /// Who served the customer — and answers for the sale.
  final String? seller;
  final String? sellerPhone;

  /// Who handed the film out of the stock.
  final String? issuedBy;

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
    this.debtDays,
    this.asleep = false,
    this.sales = 0,
    this.favourite,
    this.rhythmDays,
    this.call,
    this.debtLimit,
    this.debtLimitDays,
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
    debtDays: (json['debt_days'] as num?)?.toInt(),
    asleep: json['asleep'] == true,
    sales: (json['sales'] as num?)?.toInt() ?? 0,
    favourite: _s(json['favourite']),
    rhythmDays: (json['rhythm_days'] as num?)?.toInt(),
    call: _s(json['call']),
    debtLimit: _d(json['debt_limit']),
    debtLimitDays: (json['debt_limit_days'] as num?)?.toInt(),
  );

  final String customer;

  /// How often he buys, in days (owner, 13.11.2026).
  final int? rhythmDays;

  /// «Пора позвонить»: `debt` — owing too long, `rhythm` — silent past
  /// his own rhythm; null — nothing to call about.
  final String? call;

  /// How far he may owe for film, and for how many days; null — no limit.
  final double? debtLimit;
  final int? debtLimitDays;

  /// What a sale of [more] owing would break: the sum, the days — or null.
  ({bool sum, bool days})? overLimit(double more) {
    final sum = debtLimit != null && debtLimit! > 0 && debt + more > debtLimit!;
    final days =
        debtLimitDays != null &&
        debtLimitDays! > 0 &&
        (debtDays ?? 0) > debtLimitDays!;
    return sum || days ? (sum: sum, days: days) : null;
  }

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

  /// How long the oldest unpaid sale has waited, in days.
  final int? debtDays;

  /// Bought before and has not for two months: worth a call.
  final bool asleep;

  /// How many sales, and the film bought most (owner, 12.11.2026).
  final int sales;
  final String? favourite;
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

/// The film department's month on one page: what sold most and what each
/// film earned over its cost; what lies on the shelf unmoved.
@immutable
class FilmReport {
  const FilmReport({
    required this.month,
    this.metres = 0,
    this.amount = 0,
    this.margin = 0,
    this.top = const [],
    this.idle = const [],
    this.idleDays = 60,
  });

  factory FilmReport.fromJson(Map<String, dynamic> json) => FilmReport(
    month: '${json['month'] ?? ''}',
    metres: _d(json['metres']) ?? 0,
    amount: _d(json['amount']) ?? 0,
    margin: _d(json['margin']) ?? 0,
    top: [
      for (final r in json['top'] as List? ?? const [])
        if (r is Map<String, dynamic>)
          (
            item: '${r['item']}',
            title: '${r['title'] ?? r['item']}',
            metres: _d(r['metres']) ?? 0,
            amount: _d(r['amount']) ?? 0,
            margin: _d(r['margin']) ?? 0,
            marginM: _d(r['margin_m']),
          ),
    ],
    idle: [
      for (final r in json['idle'] as List? ?? const [])
        if (r is Map<String, dynamic>)
          (
            item: '${r['item']}',
            title: '${r['title'] ?? r['item']}',
            onHand: _d(r['on_hand']) ?? 0,
            days: (r['days'] as num?)?.toInt() ?? 0,
            value: _d(r['value']),
          ),
    ],
    idleDays: (json['idle_days'] as num?)?.toInt() ?? 60,
  );

  final String month;
  final double metres;
  final double amount;
  final double margin;
  final List<
    ({
      String item,
      String title,
      double metres,
      double amount,
      double margin,
      double? marginM,
    })
  >
  top;
  final List<
    ({String item, String title, double onHand, int days, double? value})
  >
  idle;
  final int idleDays;
}

/// How often a customer buys, in days — from three sales on; null before
/// (owner, 13.11.2026: «раз в неделю»).
int? filmRhythmDays(List<FilmSale> sales) {
  final days = {for (final s in sales) ?DateTime.tryParse(s.date)}.toList()
    ..sort();
  if (days.length < 3) return null;
  final span = days.last.difference(days.first).inDays;
  return (span / (days.length - 1)).round().clamp(1, 365);
}
