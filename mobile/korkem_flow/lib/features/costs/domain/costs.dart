import 'package:flutter/foundation.dart';

/// How a cost item is counted (owner, 25.11.2026): a bill once a month, a
/// consumable on the shelf, or money spent as it comes.
enum CostMode {
  bill,
  stock,
  other;

  static CostMode parse(Object? v) => switch ('$v') {
    'bill' => bill,
    'stock' => stock,
    _ => other,
  };
}

/// One cost item — «Электричество», «Стрейч-плёнка»: its group, how it is
/// counted, whether it grows with the m², where in the shop it is spent.
@immutable
class CostItem {
  const CostItem({
    required this.name,
    required this.title,
    required this.group,
    this.mode = CostMode.other,
    this.fixed = false,
    this.area = '',
    this.unit = '',
    this.monthlyLimit = 0,
    this.archived = false,
    this.isNew = false,
  });

  factory CostItem.fromJson(Map<String, dynamic> j) => CostItem(
    name: '${j['name']}',
    title: '${j['title'] ?? ''}',
    group: '${j['group'] ?? ''}',
    mode: CostMode.parse(j['mode']),
    fixed: j['behaviour'] == 'fixed',
    area: '${j['area'] ?? ''}',
    unit: '${j['unit'] ?? ''}',
    monthlyLimit: _d(j['monthly_limit']),
    archived: j['archived'] == true,
    isNew: j['new'] == true,
  );

  final String name;
  final String title;
  final String group;
  final CostMode mode;

  /// The same whatever the shop makes (аренда); else it grows with the m².
  final bool fixed;
  final String area;
  final String unit;

  /// 0 — no limit.
  final double monthlyLimit;
  final bool archived;

  /// Added from the floor, for the owner to look at.
  final bool isNew;
}

/// The cost items, and the groups and areas they may have.
@immutable
class CostCatalog {
  const CostCatalog({
    this.items = const [],
    this.groups = const [],
    this.areas = const [],
    this.newCount = 0,
  });

  factory CostCatalog.fromJson(Map<String, dynamic> j) => CostCatalog(
    items: [for (final i in _l(j['items'])) CostItem.fromJson(_m(i))],
    groups: [for (final g in _l(j['groups'])) '$g'],
    areas: [for (final a in _l(j['areas'])) '$a'],
    newCount: _d(j['new']).round(),
  );

  final List<CostItem> items;
  final List<String> groups;
  final List<String> areas;
  final int newCount;
}

/// A month's bill line: its sum, or last month's as a hint, and the meter.
@immutable
class CostBillRow {
  const CostBillRow({
    required this.item,
    required this.title,
    this.group = '',
    this.unit = '',
    this.amount,
    this.lastAmount,
    this.meterFrom,
    this.meterTo,
    this.meterStart,
    this.used,
    this.lastUsed,
    this.note,
    this.monthlyLimit = 0,
  });

  factory CostBillRow.fromJson(Map<String, dynamic> j) => CostBillRow(
    item: '${j['item']}',
    title: '${j['title'] ?? ''}',
    group: '${j['group'] ?? ''}',
    unit: '${j['unit'] ?? ''}',
    amount: _n(j['amount']),
    lastAmount: _n(j['last_amount']),
    meterFrom: _n(j['meter_from']),
    meterTo: _n(j['meter_to']),
    meterStart: _n(j['meter_start']),
    used: _n(j['used']),
    lastUsed: _n(j['last_used']),
    note: j['note'] == null ? null : '${j['note']}',
    monthlyLimit: _d(j['monthly_limit']),
  );

  final String item;
  final String title;
  final String group;
  final String unit;

  /// Null — not entered for this month yet.
  final double? amount;
  final double? lastAmount;
  final double? meterFrom;
  final double? meterTo;

  /// Where last month's meter ended.
  final double? meterStart;
  final double? used;
  final double? lastUsed;
  final String? note;
  final double monthlyLimit;
}

/// The month's bills.
@immutable
class CostBills {
  const CostBills({
    required this.month,
    this.bills = const [],
    this.total = 0,
    this.filled = 0,
  });

  factory CostBills.fromJson(Map<String, dynamic> j) => CostBills(
    month: '${j['month'] ?? ''}',
    bills: [for (final b in _l(j['bills'])) CostBillRow.fromJson(_m(b))],
    total: _d(j['total']),
    filled: _d(j['filled']).round(),
  );

  final String month;
  final List<CostBillRow> bills;
  final double total;
  final int filled;
}

/// A consumable on the shelf.
@immutable
class Consumable {
  const Consumable({
    required this.item,
    required this.title,
    this.unit = '',
    this.area = '',
    this.onHand = 0,
    this.minimum = 0,
    this.low = false,
    this.taken30d = 0,
    this.isNew = false,
    this.price,
  });

  factory Consumable.fromJson(Map<String, dynamic> j) => Consumable(
    item: '${j['item']}',
    title: '${j['title'] ?? ''}',
    unit: '${j['unit'] ?? ''}',
    area: '${j['area'] ?? ''}',
    onHand: _d(j['on_hand']),
    minimum: _d(j['minimum']),
    low: j['low'] == true,
    taken30d: _d(j['taken_30d']),
    isNew: j['new'] == true,
    price: _n(j['price']),
  );

  final String item;
  final String title;
  final String unit;
  final String area;
  final double onHand;
  final double minimum;
  final bool low;
  final double taken30d;
  final bool isNew;

  /// The owner's only; null for the floor.
  final double? price;
}

/// The consumables, and whether this person may buy them in.
@immutable
class Consumables {
  const Consumables({
    this.items = const [],
    this.low = 0,
    this.canReceive = false,
  });

  factory Consumables.fromJson(Map<String, dynamic> j) => Consumables(
    items: [for (final i in _l(j['items'])) Consumable.fromJson(_m(i))],
    low: _d(j['low']).round(),
    canReceive: j['can_receive'] == true,
  );

  final List<Consumable> items;
  final int low;

  /// The owner and accounting: they buy, set minimums, keep the items.
  final bool canReceive;
}

/// A cost group's part of the month.
typedef MoneyGroup = ({String group, double amount, double? share});

/// A line of the month: a cost item, raw material, piece work, or an urgent
/// expense's own category.
@immutable
class MoneyItem {
  const MoneyItem({
    required this.key,
    required this.title,
    required this.group,
    this.item,
    this.area,
    this.fixed = false,
    this.amount = 0,
    this.usual = 0,
    this.limit = 0,
    this.used,
  });

  factory MoneyItem.fromJson(Map<String, dynamic> j) => MoneyItem(
    key: '${j['key']}',
    title: '${j['title'] ?? ''}',
    group: '${j['group'] ?? ''}',
    item: j['item'] == null ? null : '${j['item']}',
    area: j['area'] == null ? null : '${j['area']}',
    fixed: j['behaviour'] == 'fixed',
    amount: _d(j['amount']),
    usual: _d(j['usual']),
    limit: _d(j['limit']),
    used: _n(j['used']),
  );

  final String key;
  final String title;
  final String group;
  final String? item;
  final String? area;
  final bool fixed;
  final double amount;

  /// Its last three months' average; 0 — nothing to compare with.
  final double usual;
  final double limit;

  /// kWh, for a bill with a meter.
  final double? used;
}

/// What plan-against-fact has to say.
enum MoneyAlertKind { limit, jump, unfilled }

@immutable
class MoneyAlert {
  const MoneyAlert({
    required this.kind,
    required this.title,
    this.amount = 0,
    this.limit = 0,
    this.over = 0,
    this.times = 0,
  });

  factory MoneyAlert.fromJson(Map<String, dynamic> j) => MoneyAlert(
    kind: switch ('${j['kind']}') {
      'limit' => MoneyAlertKind.limit,
      'jump' => MoneyAlertKind.jump,
      _ => MoneyAlertKind.unfilled,
    },
    title: '${j['title'] ?? ''}',
    amount: _d(j['amount']),
    limit: _d(j['limit']),
    over: _d(j['over']).round(),
    times: _d(j['times']),
  );

  final MoneyAlertKind kind;
  final String title;
  final double amount;
  final double limit;

  /// Over the limit, %.
  final int over;

  /// Times its usual.
  final double times;
}

/// «Куда идут деньги» for a month.
@immutable
class MoneyFlow {
  const MoneyFlow({
    required this.month,
    this.revenue = 0,
    this.orders = 0,
    this.m2 = 0,
    this.costs = 0,
    this.profit = 0,
    this.profitShare,
    this.groups = const [],
    this.items = const [],
    this.areas = const [],
    this.costPerM2,
    this.overheadPerM2,
    this.fixed = 0,
    this.variable = 0,
    this.breakEvenM2,
    this.alerts = const [],
  });

  factory MoneyFlow.fromJson(Map<String, dynamic> j) => MoneyFlow(
    month: '${j['month'] ?? ''}',
    revenue: _d(j['revenue']),
    orders: _d(j['orders']).round(),
    m2: _d(j['m2']),
    costs: _d(j['costs']),
    profit: _d(j['profit']),
    profitShare: _n(j['profit_share']),
    groups: [
      for (final g in _l(j['groups']))
        (
          group: '${_m(g)['group'] ?? ''}',
          amount: _d(_m(g)['amount']),
          share: _n(_m(g)['share']),
        ),
    ],
    items: [for (final i in _l(j['items'])) MoneyItem.fromJson(_m(i))],
    areas: [
      for (final a in _l(j['areas']))
        (area: '${_m(a)['area'] ?? ''}', amount: _d(_m(a)['amount'])),
    ],
    costPerM2: _n(j['cost_per_m2']),
    overheadPerM2: _n(j['overhead_per_m2']),
    fixed: _d(j['fixed']),
    variable: _d(j['variable']),
    breakEvenM2: _n(j['break_even_m2']),
    alerts: [for (final a in _l(j['alerts'])) MoneyAlert.fromJson(_m(a))],
  );

  /// `yyyy-MM-01`.
  final String month;

  /// The orders made ready in the month, at their totals.
  final double revenue;
  final int orders;
  final double m2;
  final double costs;
  final double profit;

  /// Of the revenue, %.
  final double? profitShare;
  final List<MoneyGroup> groups;
  final List<MoneyItem> items;
  final List<({String area, double amount})> areas;
  final double? costPerM2;
  final double? overheadPerM2;
  final double fixed;
  final double variable;

  /// The m² a month at which the shop covers everything; null — not known.
  final double? breakEvenM2;
  final List<MoneyAlert> alerts;
}

List<Object?> _l(Object? v) => v is List ? v : const [];

Map<String, dynamic> _m(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

double? _n(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
