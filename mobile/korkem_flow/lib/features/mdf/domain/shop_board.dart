import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(Object? v) => v is num ? v.toDouble() : null;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) of) => [
  for (final r in raw as List? ?? const [])
    if (r is Map) of(Map<String, dynamic>.from(r)),
];

/// The month: what the shop is to make against what it made (owner,
/// 26.11.2026), and what sales took in beside «Итоги»'s goal.
@immutable
class ShopMonth {
  const ShopMonth({
    this.planM2 = 0,
    this.planFromTarget = false,
    this.doneM2 = 0,
    this.expectedM2 = 0,
    this.forecastM2 = 0,
    this.inShopM2 = 0,
    this.inShopOrders = 0,
    this.takenM2 = 0,
    this.takenOrders = 0,
    this.salesTargetM2,
  });

  factory ShopMonth.fromJson(Map<String, dynamic> json) => ShopMonth(
    planM2: _d(json['plan_m2']),
    planFromTarget: json['plan_from'] == 'target',
    doneM2: _d(json['done_m2']),
    expectedM2: _d(json['expected_m2']),
    forecastM2: _d(json['forecast_m2']),
    inShopM2: _d(json['in_shop_m2']),
    inShopOrders: _i(json['in_shop_orders']),
    takenM2: _d(json['taken_m2']),
    takenOrders: _i(json['taken_orders']),
    salesTargetM2: _dn(json['sales_target_m2']),
  );

  final double planM2;

  /// The shop's own goal; false — the orders due this month.
  final bool planFromTarget;
  final double doneM2;

  /// What should be made by the end of today, by working days.
  final double expectedM2;
  final double forecastM2;
  final double inShopM2;
  final int inShopOrders;
  final double takenM2;
  final int takenOrders;
  final double? salesTargetM2;

  /// Ahead (above zero) or behind of where today should be.
  double get gapM2 => doneM2 - expectedM2;
}

/// A person on a stage: what he did today and how many open stages are his.
@immutable
class ShopPerson {
  const ShopPerson({
    required this.employee,
    required this.name,
    this.todayM2 = 0,
    this.inWork = 0,
  });

  factory ShopPerson.fromJson(Map<String, dynamic> json) => ShopPerson(
    employee: '${json['employee']}',
    name: '${json['name'] ?? json['employee']}',
    todayM2: _d(json['today_m2']),
    inWork: _i(json['in_work']),
  );

  final String employee;
  final String name;
  final double todayM2;
  final int inWork;
}

/// A post at a stage, with its people; none — nobody does it.
@immutable
class ShopPost {
  const ShopPost({
    required this.post,
    required this.title,
    this.department,
    this.people = const [],
  });

  factory ShopPost.fromJson(Map<String, dynamic> json) => ShopPost(
    post: '${json['post']}',
    title: '${json['title'] ?? json['post']}',
    department: _s(json['department']),
    people: _list(json['people'], ShopPerson.fromJson),
  );

  final String post;
  final String title;
  final String? department;
  final List<ShopPerson> people;
}

/// One step of the road an order takes.
@immutable
class ShopStage {
  const ShopStage({
    required this.stage,
    this.waitingM2 = 0,
    this.waitingOrders,
    this.todayM2 = 0,
    this.monthM2 = 0,
    this.perDayM2 = 0,
    this.days,
    this.jam = false,
    this.nobody = false,
    this.posts = const [],
  });

  factory ShopStage.fromJson(Map<String, dynamic> json) => ShopStage(
    stage: MdfStage.values.asNameMap()[json['stage']] ?? MdfStage.cut,
    waitingM2: _d(json['waiting_m2']),
    waitingOrders: json['waiting_orders'] == null
        ? null
        : _i(json['waiting_orders']),
    todayM2: _d(json['today_m2']),
    monthM2: _d(json['month_m2']),
    perDayM2: _d(json['per_day_m2']),
    days: _dn(json['days']),
    jam: json['jam'] == true,
    nobody: json['nobody'] == true,
    posts: _list(json['posts'], ShopPost.fromJson),
  );

  final MdfStage stage;

  /// Waiting here now; at «ready», lying ready to be given out.
  final double waitingM2;
  final int? waitingOrders;
  final double todayM2;
  final double monthM2;
  final double perDayM2;

  /// Days of work waiting, at the stage's pace; none — no pace yet.
  final double? days;

  /// More than two days of work waits: the bottleneck.
  final bool jam;

  /// Nobody holds any of its posts.
  final bool nobody;
  final List<ShopPost> posts;
}

/// An order overdue or that will not make its date.
@immutable
class ShopLate {
  const ShopLate({
    required this.order,
    required this.stage,
    required this.deliveryDate,
    this.number,
    this.customer,
    this.areaM2 = 0,
    this.overdue = false,
    this.stagesLeft = 0,
  });

  factory ShopLate.fromJson(Map<String, dynamic> json) => ShopLate(
    order: '${json['order']}',
    stage: MdfStage.values.asNameMap()[json['stage']] ?? MdfStage.cut,
    deliveryDate: '${json['delivery_date']}',
    number: json['number'] is num ? (json['number'] as num).toInt() : null,
    customer: _s(json['customer']),
    areaM2: _d(json['area_m2']),
    overdue: json['overdue'] == true,
    stagesLeft: _i(json['stages_left']),
  );

  final String order;
  final MdfStage stage;
  final String deliveryDate;
  final int? number;
  final String? customer;
  final double areaM2;
  final bool overdue;
  final int stagesLeft;
}

/// A department off the order's road: film sales, the warehouse.
@immutable
class ShopSide {
  const ShopSide({
    required this.department,
    required this.title,
    this.posts = const [],
    this.salesToday = 0,
    this.metresToday = 0,
    this.metresMonth = 0,
    this.receivedToday = 0,
  });

  factory ShopSide.fromJson(Map<String, dynamic> json) => ShopSide(
    department: '${json['department']}',
    title: '${json['title'] ?? json['department']}',
    posts: _list(json['posts'], ShopPost.fromJson),
    salesToday: _i(json['sales_today']),
    metresToday: _d(json['metres_today']),
    metresMonth: _d(json['metres_month']),
    receivedToday: _i(json['received_today']),
  );

  final String department;
  final String title;
  final List<ShopPost> posts;
  final int salesToday;
  final double metresToday;
  final double metresMonth;
  final int receivedToday;
}

/// «Цех»: the month, the stages, the late orders, the side departments.
@immutable
class ShopBoard {
  const ShopBoard({
    required this.month,
    this.stages = const [],
    this.late = const [],
    this.side = const [],
  });

  factory ShopBoard.fromJson(Map<String, dynamic> json) => ShopBoard(
    month: ShopMonth.fromJson(
      json['month'] is Map
          ? Map<String, dynamic>.from(json['month'] as Map)
          : const {},
    ),
    stages: _list(json['stages'], ShopStage.fromJson),
    late: _list(json['late'], ShopLate.fromJson),
    side: _list(json['side'], ShopSide.fromJson),
  );

  final ShopMonth month;
  final List<ShopStage> stages;
  final List<ShopLate> late;
  final List<ShopSide> side;
}
