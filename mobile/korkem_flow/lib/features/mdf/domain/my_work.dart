import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// One stage of an order that is the worker's to do (owner, 17.11.2026:
/// «каждый отмечает со своего телефона»). [waitingFor] — the stages still
/// before it; empty, it can be done now.
@immutable
class MyWorkStage {
  const MyWorkStage({
    required this.order,
    required this.stage,
    required this.areaM2,
    this.customer,
    this.deliveryDate,
    this.givenToMe = false,
    this.overdue = false,
    this.waitingFor = const [],
  });

  factory MyWorkStage.fromJson(Map<String, dynamic> json) => MyWorkStage(
    order: '${json['order']}',
    stage: MdfStage.parse(json['stage']) ?? MdfStage.ready,
    areaM2: _d(json['area_m2']),
    customer: json['customer'] == null ? null : '${json['customer']}',
    deliveryDate: json['delivery_date'] == null
        ? null
        : '${json['delivery_date']}',
    givenToMe: json['given_to_me'] == true,
    overdue: json['overdue'] == true,
    waitingFor: [
      for (final s in json['waiting_for'] as List? ?? const [])
        ?MdfStage.parse(s),
    ],
  );

  final String order;
  final MdfStage stage;
  final double areaM2;
  final String? customer;
  final String? deliveryDate;
  final bool givenToMe;
  final bool overdue;
  final List<MdfStage> waitingFor;
}

/// The worker's stages and his m² this month; [name] null — his login is
/// not tied to a person in «Команда» yet.
@immutable
class MyWork {
  const MyWork({
    this.name,
    this.ready = const [],
    this.coming = const [],
    this.monthM2 = 0,
    this.monthOrders = 0,
    this.monthByStage = const {},
  });

  factory MyWork.fromJson(Map<String, dynamic> json) {
    final me = json['me'];
    final month = json['month'];
    List<MyWorkStage> rows(Object? raw) => [
      for (final r in raw is List ? raw : const <Object>[])
        if (r is Map) MyWorkStage.fromJson(Map<String, dynamic>.from(r)),
    ];
    return MyWork(
      name: me is Map ? '${me['name'] ?? me['employee']}' : null,
      ready: rows(json['ready']),
      coming: rows(json['coming']),
      monthM2: month is Map ? _d(month['area_m2']) : 0,
      monthOrders: month is Map ? _d(month['orders']).round() : 0,
      monthByStage: {
        if (month is Map && month['stages'] is Map)
          for (final e in (month['stages'] as Map).entries)
            ?MdfStage.parse(e.key): _d(e.value),
      },
    );
  }

  final String? name;
  final List<MyWorkStage> ready;
  final List<MyWorkStage> coming;
  final double monthM2;
  final int monthOrders;
  final Map<MdfStage, double> monthByStage;
}
