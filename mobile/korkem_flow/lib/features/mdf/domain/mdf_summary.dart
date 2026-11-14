import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

/// «Итоги МДФ» (owner, 12.11.2026): the period against the one before it,
/// and what is coming — the month's plan, the shop's queue, who fell asleep,
/// whether the film will do.
@immutable
class MdfSummary {
  const MdfSummary({
    required this.now,
    required this.before,
    this.since = '',
    this.until = '',
    this.customers = 0,
    this.newCustomers = 0,
    this.plan = const MdfPlan(),
    this.shop = const MdfShop(),
    this.top = const [],
    this.asleep = const [],
    this.films = const [],
    this.millings = const [],
    this.deadlines = const MdfDeadlines(),
    this.quality = const MdfQuality(),
    this.debts = const MdfDebts(),
    this.managers = const [],
    this.stages = const [],
    this.atRisk = 0,
    this.days = const [],
  });

  factory MdfSummary.fromJson(Map<String, dynamic> json) => MdfSummary(
    since: '${json['since'] ?? ''}',
    until: '${json['until'] ?? ''}',
    now: MdfFigures.fromJson(json),
    before: MdfFigures.fromJson(_m(json['before'])),
    customers: _i(json['customers_count']),
    newCustomers: _i(json['new_customers']),
    plan: MdfPlan.fromJson(_m(json['plan'])),
    shop: MdfShop.fromJson(_m(json['shop'])),
    top: [
      for (final c in _l(json['top_customers'])) MdfTopCustomer.fromJson(c),
    ],
    asleep: [for (final c in _l(json['asleep'])) MdfAsleep.fromJson(c)],
    films: [for (final f in _l(json['films'])) MdfFilmDemand.fromJson(f)],
    millings: [
      for (final m in _l(json['millings']))
        (
          milling: '${m['milling'] ?? '—'}',
          areaM2: _d(m['area_m2']),
          share: _d(m['share']),
        ),
    ],
    deadlines: MdfDeadlines.fromJson(_m(json['deadlines'])),
    quality: MdfQuality.fromJson(_m(json['quality'])),
    debts: MdfDebts.fromJson(_m(json['debts'])),
    managers: [
      for (final m in _l(json['managers']))
        (
          name: '${m['name'] ?? m['user'] ?? ''}',
          orders: _i(m['orders']),
          areaM2: _d(m['area_m2']),
          total: _d(m['total']),
        ),
    ],
    stages: [
      for (final s in _l(json['stages']))
        if (MdfStage.parse(s['stage']) case final stage?)
          (stage: stage, orders: _i(s['orders']), areaM2: _d(s['area_m2'])),
    ],
    atRisk: _i(json['at_risk']),
    days: [
      for (final d in _l(json['days']))
        (
          date: '${d['date'] ?? ''}',
          orders: _i(d['orders']),
          areaM2: _d(d['area_m2']),
          total: _d(d['total']),
        ),
    ],
  );

  final String since;
  final String until;

  /// This period's figures, and the same-length period before it.
  final MdfFigures now;
  final MdfFigures before;
  final int customers;
  final int newCustomers;
  final MdfPlan plan;
  final MdfShop shop;
  final List<MdfTopCustomer> top;
  final List<MdfAsleep> asleep;
  final List<MdfFilmDemand> films;
  final List<({String milling, double areaM2, double share})> millings;
  final MdfDeadlines deadlines;
  final MdfQuality quality;
  final MdfDebts debts;
  final List<({String name, int orders, double areaM2, double total})> managers;

  /// Where the open orders wait now, stage by stage (owner, 14.11.2026).
  final List<({MdfStage stage, int orders, double areaM2})> stages;

  /// Open orders that will not make their date at the shop's pace.
  final int atRisk;

  /// What came in, day by day — month by month over a year.
  final List<({String date, int orders, double areaM2, double total})> days;
}

/// How much a period brought.
@immutable
class MdfFigures {
  const MdfFigures({
    this.orders = 0,
    this.areaM2 = 0,
    this.total = 0,
    this.paid = 0,
    this.debt = 0,
    this.avgTotal = 0,
    this.avgArea = 0,
    this.rateM2 = 0,
  });

  factory MdfFigures.fromJson(Map<String, dynamic> json) => MdfFigures(
    orders: _i(json['orders']),
    areaM2: _d(json['area_m2']),
    total: _d(json['total']),
    paid: _d(json['paid']),
    debt: _d(json['debt']),
    avgTotal: _d(json['avg_total']),
    avgArea: _d(json['avg_area']),
    rateM2: _d(json['rate_m2']),
  );

  final int orders;
  final double areaM2;
  final double total;
  final double paid;
  final double debt;
  final double avgTotal;
  final double avgArea;
  final double rateM2;
}

/// Up or down against the period before, in percent; null when there was
/// nothing before to compare with.
int? mdfChange(double now, double before) =>
    before <= 0 ? null : ((now - before) / before * 100).round();

/// The month so far against the goal, and where it ends at this pace.
@immutable
class MdfPlan {
  const MdfPlan({
    this.targetM2,
    this.doneM2 = 0,
    this.doneTotal = 0,
    this.daysLeft = 0,
    this.forecastM2,
    this.forecastTotal,
    this.progress,
  });

  factory MdfPlan.fromJson(Map<String, dynamic> json) => MdfPlan(
    targetM2: _dn(json['target_m2']),
    doneM2: _d(json['done_m2']),
    doneTotal: _d(json['done_total']),
    daysLeft: _i(json['days_left']),
    forecastM2: _dn(json['forecast_m2']),
    forecastTotal: _dn(json['forecast_total']),
    progress: _dn(json['progress']),
  );

  final double? targetM2;
  final double doneM2;
  final double doneTotal;
  final int daysLeft;
  final double? forecastM2;
  final double? forecastTotal;
  final double? progress;
}

/// What is in work, the shop's pace, when a new order would be ready.
@immutable
class MdfShop {
  const MdfShop({
    this.inWorkM2 = 0,
    this.inWorkOrders = 0,
    this.paceM2Day = 0,
    this.queueDays,
    this.readyOn,
    this.overdue = 0,
  });

  factory MdfShop.fromJson(Map<String, dynamic> json) => MdfShop(
    inWorkM2: _d(json['in_work_m2']),
    inWorkOrders: _i(json['in_work_orders']),
    paceM2Day: _d(json['pace_m2_day']),
    queueDays: (json['queue_days'] as num?)?.toInt(),
    readyOn: _s(json['ready_on']),
    overdue: _i(json['overdue']),
  );

  final double inWorkM2;
  final int inWorkOrders;
  final double paceM2Day;
  final int? queueDays;
  final String? readyOn;
  final int overdue;
}

@immutable
class MdfTopCustomer {
  const MdfTopCustomer({
    required this.customer,
    required this.name,
    this.orders = 0,
    this.areaM2 = 0,
    this.total = 0,
    this.tags = const [],
    this.isNew = false,
  });

  factory MdfTopCustomer.fromJson(Map<String, dynamic> json) => MdfTopCustomer(
    customer: '${json['customer']}',
    name: '${json['customer_name'] ?? json['customer']}',
    orders: _i(json['orders']),
    areaM2: _d(json['area_m2']),
    total: _d(json['total']),
    tags: [for (final t in json['tags'] as List? ?? const []) '$t'],
    isNew: json['new'] == true,
  );

  final String customer;
  final String name;
  final int orders;
  final double areaM2;
  final double total;
  final List<String> tags;
  final bool isNew;
}

/// A customer silent longer than his own rhythm.
@immutable
class MdfAsleep {
  const MdfAsleep({
    required this.customer,
    required this.name,
    this.phone,
    this.orders = 0,
    this.rhythmDays,
    this.idleDays = 0,
    this.gone = false,
  });

  factory MdfAsleep.fromJson(Map<String, dynamic> json) => MdfAsleep(
    customer: '${json['customer']}',
    name: '${json['customer_name'] ?? json['customer']}',
    phone: _s(json['phone']),
    orders: _i(json['orders']),
    rhythmDays: (json['rhythm_days'] as num?)?.toInt(),
    idleDays: _i(json['idle_days']),
    gone: json['gone'] == true,
  );

  final String customer;
  final String name;
  final String? phone;
  final int orders;

  /// How often he orders, in days; null — one order only.
  final int? rhythmDays;
  final int idleDays;

  /// Gone (twice his rhythm), not just dozing.
  final bool gone;
}

/// A film the orders were in, and whether there is enough of it.
@immutable
class MdfFilmDemand {
  const MdfFilmDemand({
    required this.decor,
    this.item,
    this.orders = 0,
    this.areaM2 = 0,
    this.toBuyM = 0,
    this.freeM,
  });

  factory MdfFilmDemand.fromJson(Map<String, dynamic> json) => MdfFilmDemand(
    decor: '${json['decor'] ?? '—'}',
    item: _s(json['item']),
    orders: _i(json['orders']),
    areaM2: _d(json['area_m2']),
    toBuyM: _d(json['to_buy_m']),
    freeM: _dn(json['free_m']),
  );

  final String decor;
  final String? item;
  final int orders;
  final double areaM2;

  /// Metres the open orders still lack — to order.
  final double toBuyM;
  final double? freeM;
}

@immutable
class MdfDeadlines {
  const MdfDeadlines({
    this.handedOver = 0,
    this.onTime = 0,
    this.onTimeShare,
    this.lateDaysAvg,
  });

  factory MdfDeadlines.fromJson(Map<String, dynamic> json) => MdfDeadlines(
    handedOver: _i(json['handed_over']),
    onTime: _i(json['on_time']),
    onTimeShare: _dn(json['on_time_share']),
    lateDaysAvg: _dn(json['late_days_avg']),
  );

  final int handedOver;
  final int onTime;
  final double? onTimeShare;
  final double? lateDaysAvg;
}

@immutable
class MdfQuality {
  const MdfQuality({
    this.orders = 0,
    this.areaM2 = 0,
    this.share = 0,
    this.returned = 0,
    this.reasons = const [],
  });

  factory MdfQuality.fromJson(Map<String, dynamic> json) => MdfQuality(
    orders: _i(json['orders']),
    areaM2: _d(json['area_m2']),
    share: _d(json['share']),
    returned: _i(json['returned']),
    reasons: [
      for (final r in _l(json['reasons']))
        (reason: '${r['reason'] ?? ''}', count: _i(r['count'])),
    ],
  );

  /// Reworks and warranty jobs — our cost.
  final int orders;
  final double areaM2;
  final double share;

  /// Orders brought back, and the commonest reasons.
  final int returned;
  final List<({String reason, int count})> reasons;
}

/// What is owed, by how old the order is.
@immutable
class MdfDebts {
  const MdfDebts({
    this.week = 0,
    this.month = 0,
    this.older = 0,
    this.olderCustomers = 0,
    this.oldest = const [],
  });

  factory MdfDebts.fromJson(Map<String, dynamic> json) => MdfDebts(
    week: _d(_m(json['week'])['amount']),
    month: _d(_m(json['month'])['amount']),
    older: _d(_m(json['older'])['amount']),
    olderCustomers: _i(_m(json['older'])['customers']),
    oldest: [
      for (final d in _l(json['oldest']))
        (
          name: '${d['customer_name'] ?? d['customer']}',
          debt: _d(d['debt']),
          days: _i(d['days']),
          phone: _s(d['phone']),
        ),
    ],
  );

  final double week;
  final double month;
  final double older;
  final int olderCustomers;
  final List<({String name, double debt, int days, String? phone})> oldest;
}

Map<String, dynamic> _m(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

List<Map<String, dynamic>> _l(Object? v) => [
  for (final x in v is List ? v : const <Object>[])
    if (x is Map<String, dynamic>) x,
];

double _d(Object? v) => _dn(v) ?? 0;

double? _dn(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

String? _s(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}
