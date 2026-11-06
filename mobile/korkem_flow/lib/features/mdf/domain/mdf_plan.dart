import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

@immutable
class PlanOrder {
  const PlanOrder({
    required this.name,
    required this.customerName,
    required this.deliveryDate,
    required this.areaM2,
    this.decorTop,
    this.milling,
    this.overdue = false,
    this.dueSoon = false,
    this.debt = 0,
  });

  factory PlanOrder.fromJson(Map<String, dynamic> json) => PlanOrder(
    name: '${json['name']}',
    customerName: '${json['customer_name'] ?? ''}',
    deliveryDate: '${json['delivery_date'] ?? ''}',
    decorTop: json['decor_top'] as String?,
    milling: json['milling'] as String?,
    areaM2: _d(json['area_m2']),
    overdue: json['overdue'] == true,
    dueSoon: json['due_soon'] == true,
    debt: _d(json['debt']),
  );

  final String name;
  final String customerName;
  final String deliveryDate;
  final String? decorTop;
  final String? milling;
  final double areaM2;
  final bool overdue;
  final bool dueSoon;
  final double debt;
}

/// The orders waiting at one stage, and their m².
@immutable
class PlanStage {
  const PlanStage({
    required this.stage,
    required this.orders,
    required this.areaM2,
  });

  factory PlanStage.fromJson(Map<String, dynamic> json) => PlanStage(
    stage: MdfStage.parse(json['stage']) ?? MdfStage.cut,
    orders: [
      for (final o in json['orders'] as List? ?? const [])
        if (o is Map) PlanOrder.fromJson(Map<String, dynamic>.from(o)),
    ],
    areaM2: _d(json['area_m2']),
  );

  final MdfStage stage;
  final List<PlanOrder> orders;
  final double areaM2;
}

@immutable
class PlanDay {
  const PlanDay({
    required this.date,
    required this.orders,
    required this.areaM2,
  });

  factory PlanDay.fromJson(Map<String, dynamic> json) => PlanDay(
    date: '${json['date']}',
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    areaM2: _d(json['area_m2']),
  );

  final String date;
  final int orders;
  final double areaM2;
}

/// OnayBaza's «Жоспар»: the queue at each stage, and the intake by day.
@immutable
class MdfPlan {
  const MdfPlan({
    required this.stages,
    required this.intake,
    required this.inWorkM2,
  });

  factory MdfPlan.fromJson(Map<String, dynamic> json) => MdfPlan(
    stages: [
      for (final s in json['stages'] as List? ?? const [])
        if (s is Map) PlanStage.fromJson(Map<String, dynamic>.from(s)),
    ],
    intake: [
      for (final d in json['intake'] as List? ?? const [])
        if (d is Map) PlanDay.fromJson(Map<String, dynamic>.from(d)),
    ],
    inWorkM2: _d(json['in_work_m2']),
  );

  final List<PlanStage> stages;
  final List<PlanDay> intake;
  final double inWorkM2;
}
