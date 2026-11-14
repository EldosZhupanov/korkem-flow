import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Someone who can be named on a stage.
@immutable
class MdfWorker {
  const MdfWorker({required this.employee, required this.name, this.role});

  factory MdfWorker.fromJson(Map<String, dynamic> json) => MdfWorker(
    employee: '${json['employee']}',
    name: '${json['employee_name'] ?? json['employee']}',
    role: json['designation'] as String?,
  );

  final String employee;
  final String name;
  final String? role;
}

/// One worker's volume; [employee] null is «не указано».
@immutable
class VolumeRow {
  const VolumeRow({
    required this.employee,
    required this.name,
    required this.orders,
    required this.areaM2,
    required this.byStage,
  });

  factory VolumeRow.fromJson(Map<String, dynamic> json) => VolumeRow(
    employee: json['worker'] as String?,
    name: json['worker_name'] as String?,
    orders: _i(json['orders']),
    areaM2: _d(json['area_m2']),
    byStage: {
      if (json['stages'] is Map)
        for (final e in (json['stages'] as Map).entries)
          if (MdfStage.parse(e.key) != null)
            MdfStage.parse(e.key)!: _d(e.value),
    },
  );

  final String? employee;
  final String? name;
  final int orders;
  final double areaM2;
  final Map<MdfStage, double> byStage;
}

/// «Объём работ» — OnayBaza's «Жұмыс көлемі».
@immutable
class MdfVolume {
  const MdfVolume({
    required this.workers,
    required this.byStage,
    required this.unassignedM2,
    this.days = const [],
    this.previousM2 = 0,
    this.queue = const [],
  });

  factory MdfVolume.fromJson(Map<String, dynamic> json) => MdfVolume(
    workers: [
      for (final w in json['workers'] as List? ?? const [])
        if (w is Map) VolumeRow.fromJson(Map<String, dynamic>.from(w)),
    ],
    byStage: {
      for (final s in json['stages'] as List? ?? const [])
        if (s is Map && MdfStage.parse(s['stage']) != null)
          MdfStage.parse(s['stage'])!: _d(s['area_m2']),
    },
    unassignedM2: _d(json['unassigned_m2']),
    days: [
      for (final d in json['days'] as List? ?? const [])
        if (d is Map) (date: '${d['date'] ?? ''}', areaM2: _d(d['area_m2'])),
    ],
    previousM2: _d(json['previous_m2']),
    queue: [
      for (final q in json['queue'] as List? ?? const [])
        if (q is Map)
          if (MdfStage.parse(q['stage']) case final stage?)
            (stage: stage, orders: _i(q['orders']), areaM2: _d(q['area_m2'])),
    ],
  );

  /// All the m² done in the period, every stage counted.
  double get totalM2 => byStage.values.fold(0, (a, b) => a + b);

  /// Most m² first; «не указано» last.
  final List<VolumeRow> workers;
  final Map<MdfStage, double> byStage;
  final double unassignedM2;

  /// m² done day by day — a month each over a year (owner, 14.11.2026).
  final List<({String date, double areaM2})> days;

  /// The period of the same length before, to compare with.
  final double previousM2;

  /// What waits at each stage now; the longest is where the shop jams.
  final List<({MdfStage stage, int orders, double areaM2})> queue;
}
