import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// One stage's load: what waits, and how many days of its work that is.
typedef TodayLoad = ({
  MdfStage stage,
  double waitingM2,
  int waitingOrders,
  double? days,
  bool jam,
  bool nobody,
});

/// One thing to decide, the worst first: what kind, and what it is about.
@immutable
class TodayDecision {
  const TodayDecision(this.kind, this.data);

  /// jam · at_risk · film · post_empty · unassigned · no_prepay
  final String kind;
  final Map<String, dynamic> data;

  int get count => _i(data['count']);
}

/// One thing just done in the shop.
typedef TodayRecent = ({
  String action,
  String order,
  String at,
  String by,
  MdfStage? stage,
  bool done,
  double amount,
});

/// «Сегодня» — the facade shop's home (owner, 27.11.2026).
@immutable
class MdfToday {
  const MdfToday({
    required this.day,
    required this.overdue,
    required this.atRisk,
    required this.dueSoon,
    required this.ready,
    required this.readyMoney,
    required this.debt,
    required this.debtors,
    this.load = const [],
    this.decide = const [],
    this.recent = const [],
  });

  factory MdfToday.fromJson(Map<String, dynamic> json) {
    final f = Map<String, dynamic>.from(json['figures'] as Map? ?? const {});
    return MdfToday(
      day: '${json['day'] ?? ''}',
      overdue: _i(f['overdue']),
      atRisk: _i(f['at_risk']),
      dueSoon: _i(f['due_soon']),
      ready: _i(f['ready']),
      readyMoney: _d(f['ready_money']),
      debt: _d(f['debt']),
      debtors: _i(f['debtors']),
      load: [
        for (final l in json['load'] as List? ?? const [])
          if (l is Map)
            if (MdfStage.parse(l['stage']) case final stage?)
              (
                stage: stage,
                waitingM2: _d(l['waiting_m2']),
                waitingOrders: _i(l['waiting_orders']),
                days: l['days'] is num ? (l['days'] as num).toDouble() : null,
                jam: l['jam'] == true,
                nobody: l['nobody'] == true,
              ),
      ],
      decide: [
        for (final d in json['decide'] as List? ?? const [])
          if (d is Map)
            TodayDecision('${d['kind']}', Map<String, dynamic>.from(d)),
      ],
      recent: [
        for (final r in json['recent'] as List? ?? const [])
          if (r is Map)
            (
              action: '${r['action']}',
              order: '${r['order']}',
              at: '${r['at'] ?? ''}',
              by: '${r['by'] ?? ''}',
              stage: MdfStage.parse(r['stage']),
              done: r['done'] == true,
              amount: _d(r['amount']),
            ),
      ],
    );
  }

  final String day;
  final int overdue;

  /// Will miss its date at the shop's pace, while it can still be helped.
  final int atRisk;
  final int dueSoon;
  final int ready;

  /// What comes in when the ready orders are handed over.
  final double readyMoney;
  final double debt;
  final int debtors;
  final List<TodayLoad> load;
  final List<TodayDecision> decide;
  final List<TodayRecent> recent;
}
