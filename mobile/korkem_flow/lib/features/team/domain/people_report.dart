import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/team/domain/team_moves.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) of) => [
  for (final r in raw as List? ?? const [])
    if (r is Map) of(Map<String, dynamic>.from(r)),
];

/// A day, a Monday-to-Sunday week, or a month.
enum PeopleSpan { day, week, month }

/// The first and the last day of the [span] that [day] falls in — the
/// server's own rule (`people_report.span`), so the label is right before
/// the answer comes.
(DateTime, DateTime) peopleSpanOf(PeopleSpan span, DateTime day) {
  final at = DateTime(day.year, day.month, day.day);
  return switch (span) {
    PeopleSpan.day => (at, at),
    PeopleSpan.week => (
      at.subtract(Duration(days: at.weekday - 1)),
      at.add(Duration(days: 7 - at.weekday)),
    ),
    PeopleSpan.month => (
      DateTime(at.year, at.month),
      DateTime(at.year, at.month + 1, 0),
    ),
  };
}

/// The same span one step before or after.
DateTime peopleShift(PeopleSpan span, DateTime day, int step) => switch (span) {
  PeopleSpan.day => DateTime(day.year, day.month, day.day + step),
  PeopleSpan.week => DateTime(day.year, day.month, day.day + 7 * step),
  PeopleSpan.month => DateTime(day.year, day.month + step),
};

String peopleIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// What a person did at one stage: orders and m².
@immutable
class PersonStage {
  const PersonStage({
    required this.stage,
    required this.orders,
    required this.m2,
  });

  factory PersonStage.fromJson(Map<String, dynamic> json) => PersonStage(
    stage: '${json['stage']}',
    orders: _i(json['orders']),
    m2: _d(json['m2']),
  );

  final String stage;
  final int orders;
  final double m2;
}

/// A person's money for the period — `payroll`'s statement row.
@immutable
class PersonMoney {
  const PersonMoney({
    this.earned = 0,
    this.piece = 0,
    this.pending = 0,
    this.bonus = 0,
    this.salesBonus = 0,
    this.fine = 0,
    this.advance = 0,
    this.toPay = 0,
    this.paid = 0,
    this.left = 0,
  });

  factory PersonMoney.fromJson(Map<String, dynamic> json) => PersonMoney(
    earned: _d(json['earned']),
    piece: _d(json['piece']),
    pending: _d(json['pending']),
    bonus:
        _d(json['bonus']) + _d(json['daily_bonus']) + _d(json['monthly_bonus']),
    salesBonus: _d(json['sales_bonus']),
    fine: _d(json['fine']),
    advance: _d(json['advance']),
    toPay: _d(json['to_pay']),
    paid: _d(json['paid']),
    left: _d(json['left']),
  );

  /// Piece pay and bonuses, before the advance and the fine.
  final double earned;
  final double piece;

  /// Piece work not yet approved — not in [earned].
  final double pending;
  final double bonus;

  /// His part of the film sellers' pot — a calendar month's.
  final double salesBonus;
  final double fine;
  final double advance;
  final double toPay;
  final double paid;
  final double left;
}

/// One person in «Сотрудники».
@immutable
class PersonRow {
  const PersonRow({
    required this.employee,
    required this.name,
    this.user,
    this.posts = const [],
    this.stages = const [],
    this.stagesDone = 0,
    this.m2 = 0,
    this.orders = 0,
    this.days = 0,
    this.money,
    this.intake,
    this.sales,
    this.received,
  });

  factory PersonRow.fromJson(Map<String, dynamic> json) => PersonRow(
    employee: '${json['employee']}',
    name: '${json['name'] ?? json['employee']}',
    user: _s(json['user']),
    posts: [for (final p in json['post_titles'] as List? ?? const []) '$p'],
    stages: _list(json['stages'], PersonStage.fromJson),
    stagesDone: _i(json['stages_done']),
    m2: _d(json['m2']),
    orders: _i(json['orders']),
    days: _i(json['days']),
    money: json['money'] is Map
        ? PersonMoney.fromJson(Map<String, dynamic>.from(json['money'] as Map))
        : null,
    intake: switch (json['intake']) {
      final Map<String, dynamic> v => (
        orders: _i(v['orders']),
        m2: _d(v['m2']),
        amount: _d(v['amount']),
      ),
      _ => null,
    },
    sales: switch (json['sales']) {
      final Map<String, dynamic> v => (
        sales: _i(v['sales']),
        metres: _d(v['metres']),
        amount: _d(v['amount']),
      ),
      _ => null,
    },
    received: switch (json['received']) {
      final Map<String, dynamic> v => _i(v['count']),
      _ => null,
    },
  );

  final String employee;
  final String name;

  /// His login; none — the manager ticks for him and no piece pay is booked.
  final String? user;
  final List<String> posts;
  final List<PersonStage> stages;
  final int stagesDone;
  final double m2;
  final int orders;

  /// Days on which a stage of his was ticked.
  final int days;

  /// None without a login, or for one who does not see pay.
  final PersonMoney? money;

  /// Facade orders he accepted («Принять»).
  final ({int orders, double m2, double amount})? intake;

  /// Film he sold.
  final ({int sales, double metres, double amount})? sales;

  /// Deliveries he took in.
  final int? received;
}

/// An advance, a fine or a bonus waiting for somebody's «Да».
@immutable
class PayWaiting {
  const PayWaiting({
    required this.adjustment,
    required this.name,
    required this.kind,
    required this.amount,
    this.reason,
    this.by,
    this.canApprove = false,
  });

  factory PayWaiting.fromJson(Map<String, dynamic> json) => PayWaiting(
    adjustment: '${json['adjustment']}',
    name: '${json['employee_name'] ?? json['employee']}',
    kind: _kind(json['kind']),
    amount: _d(json['amount']),
    reason: _s(json['reason']),
    by: _s(json['created_by']),
    canApprove: json['can_approve'] == true,
  );

  final String adjustment;
  final String name;
  final PersonAdjustmentKind kind;
  final double amount;
  final String? reason;
  final String? by;
  final bool canApprove;
}

PersonAdjustmentKind _kind(Object? kind) => switch (kind) {
  'Штраф' => PersonAdjustmentKind.fine,
  'Премия' => PersonAdjustmentKind.bonus,
  _ => PersonAdjustmentKind.advance,
};

/// The server's word for [kind] (`payroll.KINDS`).
String payKindName(PersonAdjustmentKind kind) => switch (kind) {
  PersonAdjustmentKind.advance => 'Аванс',
  PersonAdjustmentKind.fine => 'Штраф',
  PersonAdjustmentKind.bonus => 'Премия',
};

/// Everyone for a period.
@immutable
class PeopleReport {
  const PeopleReport({
    required this.people,
    this.m2 = 0,
    this.stagesDone = 0,
    this.earned = 0,
    this.advance = 0,
    this.left = 0,
    this.seesPay = false,
    this.canAdjust = false,
    this.canPay = false,
    this.pending = const [],
  });

  factory PeopleReport.fromJson(Map<String, dynamic> json) {
    final total = json['total'] is Map
        ? Map<String, dynamic>.from(json['total'] as Map)
        : const <String, dynamic>{};
    return PeopleReport(
      people: _list(json['people'], PersonRow.fromJson),
      m2: _d(total['m2']),
      stagesDone: _i(total['stages_done']),
      earned: _d(total['earned']),
      advance: _d(total['advance']),
      left: _d(total['left']),
      seesPay: json['sees_pay'] == true,
      canAdjust: json['can_adjust'] == true,
      canPay: json['can_pay'] == true,
      pending: _list(json['pending'], PayWaiting.fromJson),
    );
  }

  final List<PersonRow> people;
  final double m2;
  final int stagesDone;
  final double earned;
  final double advance;
  final double left;

  /// The one looking sees pay: the money tab is his.
  final bool seesPay;

  /// He may enter an advance, a fine or a bonus.
  final bool canAdjust;

  /// He may mark pay given — the period is over.
  final bool canPay;

  /// Waiting for somebody's «Да».
  final List<PayWaiting> pending;
}

/// One day of a person's card.
@immutable
class PersonDay {
  const PersonDay({required this.day, this.m2 = 0, this.earned = 0});

  factory PersonDay.fromJson(Map<String, dynamic> json) => PersonDay(
    day: '${json['day']}',
    m2: _d(json['m2']),
    earned: _d(json['earned']),
  );

  /// `yyyy-MM-dd`.
  final String day;
  final double m2;
  final double earned;
}

/// A stage he did on an order.
@immutable
class PersonWork {
  const PersonWork({
    required this.order,
    required this.stage,
    required this.on,
    this.number,
    this.customer,
    this.m2 = 0,
  });

  factory PersonWork.fromJson(Map<String, dynamic> json) => PersonWork(
    order: '${json['order']}',
    stage: '${json['stage']}',
    on: '${json['on']}',
    number: json['number'] == null ? null : _i(json['number']),
    customer: _s(json['customer']),
    m2: _d(json['m2']),
  );

  final String order;
  final String stage;
  final String on;
  final int? number;
  final String? customer;
  final double m2;
}

/// A piece-work line.
@immutable
class PersonEntry {
  const PersonEntry({
    required this.on,
    required this.operation,
    this.quantity = 0,
    this.unit,
    this.amount = 0,
    this.pending = false,
  });

  factory PersonEntry.fromJson(Map<String, dynamic> json) => PersonEntry(
    on: '${json['on']}',
    operation: '${json['operation'] ?? ''}',
    quantity: _d(json['quantity']),
    unit: _s(json['unit']),
    amount: _d(json['amount']),
    pending: json['status'] == 'Pending Approval',
  );

  final String on;
  final String operation;
  final double quantity;
  final String? unit;
  final double amount;
  final bool pending;
}

/// An advance, a fine or a bonus.
enum PersonAdjustmentKind { advance, fine, bonus }

@immutable
class PersonAdjustment {
  const PersonAdjustment({
    required this.on,
    required this.kind,
    required this.amount,
    this.reason,
    this.approved = true,
    this.adjustment,
    this.canApprove = false,
    this.canReverse = false,
  });

  factory PersonAdjustment.fromJson(Map<String, dynamic> json) =>
      PersonAdjustment(
        on: '${json['on']}',
        kind: _kind(json['kind']),
        amount: _d(json['amount']),
        reason: _s(json['reason']),
        approved: json['status'] == 'Approved',
        adjustment: _s(json['adjustment']),
        canApprove: json['can_approve'] == true,
        canReverse: json['can_reverse'] == true,
      );

  final String on;
  final PersonAdjustmentKind kind;
  final double amount;
  final String? reason;
  final bool approved;
  final String? adjustment;
  final bool canApprove;
  final bool canReverse;
}

/// Money paid out to him.
@immutable
class PersonPayout {
  const PersonPayout({required this.on, required this.amount});

  factory PersonPayout.fromJson(Map<String, dynamic> json) =>
      PersonPayout(on: '${json['on']}', amount: _d(json['amount']));

  final String on;
  final double amount;
}

/// One person's card for a period.
@immutable
class PersonCard {
  const PersonCard({
    required this.row,
    this.days = const [],
    this.works = const [],
    this.entries = const [],
    this.adjustments = const [],
    this.payouts = const [],
    this.me = false,
    this.postKeys = const [],
    this.active = true,
    this.canEdit = false,
    this.history = const [],
    this.seesPay = false,
    this.canAdjust = false,
    this.canPay = false,
  });

  factory PersonCard.fromJson(Map<String, dynamic> json) => PersonCard(
    row: PersonRow.fromJson(json),
    postKeys: [for (final p in json['posts'] as List? ?? const []) '$p'],
    active: json['active'] != false,
    canEdit: json['can_edit'] == true,
    history: _list(json['history'], TeamEvent.fromJson),
    seesPay: json['sees_pay'] == true,
    canAdjust: json['can_adjust'] == true,
    canPay: json['can_pay'] == true,
    days: _list(json['by_day'], PersonDay.fromJson),
    works: _list(json['works'], PersonWork.fromJson),
    entries: _list(json['entries'], PersonEntry.fromJson),
    adjustments: _list(json['adjustments'], PersonAdjustment.fromJson),
    payouts: _list(json['payouts'], PersonPayout.fromJson),
    me: json['me'] == true,
  );

  final PersonRow row;
  final List<PersonDay> days;
  final List<PersonWork> works;
  final List<PersonEntry> entries;
  final List<PersonAdjustment> adjustments;
  final List<PersonPayout> payouts;

  /// The one looking is this person.
  final bool me;

  /// His posts as keys (`cut.cutter`) — [row]'s are titles.
  final List<String> postKeys;
  final bool active;

  /// The one looking may change his posts and let him go.
  final bool canEdit;

  /// Posts given and taken, hired and left — newest first.
  final List<TeamEvent> history;

  /// The money on the card is for the one looking.
  final bool seesPay;

  /// He may enter an advance, a fine or a bonus for him.
  final bool canAdjust;

  /// He may mark the period's pay given.
  final bool canPay;
}
