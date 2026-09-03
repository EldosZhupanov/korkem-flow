import 'package:flutter/foundation.dart';

/// One voice capture that hasn't been assigned to anyone for > 24 hours.
@immutable
class UnassignedCaptureItem {
  const UnassignedCaptureItem({
    required this.capture,
    required this.said,
    required this.since,
    this.customer,
  });

  factory UnassignedCaptureItem.fromJson(Map<String, dynamic> json) {
    return UnassignedCaptureItem(
      capture: json['capture'] as String? ?? '',
      said: json['said'] as String? ?? '',
      since: json['since'] as String? ?? '',
      customer: json['customer'] as String?,
    );
  }

  final String capture;
  final String said;
  final String? customer;
  final String since;
}

/// One task with missed deadline (measurement, design, installation).
@immutable
class OverdueTaskItem {
  const OverdueTaskItem({
    required this.task,
    required this.wasDue,
    this.title,
    this.who,
    this.on,
  });

  factory OverdueTaskItem.fromJson(Map<String, dynamic> json) {
    return OverdueTaskItem(
      task: json['task'] as String? ?? '',
      title: json['title'] as String?,
      who: json['who'] as String?,
      wasDue: json['was_due'] as String? ?? '',
      on: json['on'] as String?,
    );
  }

  final String task;
  final String? title;
  final String? who;
  final String wasDue;
  final String? on;
}

/// One submitted sales order without an assigned design task.
@immutable
class OrderWithoutDesignItem {
  const OrderWithoutDesignItem({
    required this.salesOrder,
    this.customer,
    this.due,
  });

  factory OrderWithoutDesignItem.fromJson(Map<String, dynamic> json) {
    return OrderWithoutDesignItem(
      salesOrder: json['sales_order'] as String? ?? '',
      customer: json['customer'] as String?,
      due: json['due'] as String?,
    );
  }

  final String salesOrder;
  final String? customer;
  final String? due;
}

/// One sales order where items were delivered but invoice not fully drafted.
@immutable
class DeliveredNotInvoicedItem {
  const DeliveredNotInvoicedItem({
    required this.salesOrder,
    this.customer,
    this.total = 0,
    this.deliveredPercent = 0,
    this.billedPercent = 0,
  });

  factory DeliveredNotInvoicedItem.fromJson(Map<String, dynamic> json) {
    return DeliveredNotInvoicedItem(
      salesOrder: json['sales_order'] as String? ?? '',
      customer: json['customer'] as String?,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      deliveredPercent: (json['delivered_percent'] as num?)?.toDouble() ?? 0,
      billedPercent: (json['billed_percent'] as num?)?.toDouble() ?? 0,
    );
  }

  final String salesOrder;
  final String? customer;
  final double total;
  final double deliveredPercent;
  final double billedPercent;
}

/// The entire response of `korkem_manufacturing.api.attention.today`.
@immutable
class TodayAttention {
  const TodayAttention({
    this.unassignedCaptures = const [],
    this.overdueTasks = const [],
    this.ordersWithoutDesign = const [],
    this.deliveredNotInvoiced = const [],
  });

  factory TodayAttention.fromJson(Map<String, dynamic> json) {
    final unassigned = json['unassigned_captures'] as List<dynamic>? ?? [];
    final overdue = json['overdue_tasks'] as List<dynamic>? ?? [];
    final noDesign = json['orders_without_design'] as List<dynamic>? ?? [];
    final notInvoiced = json['delivered_not_invoiced'] as List<dynamic>? ?? [];

    return TodayAttention(
      unassignedCaptures: unassigned
          .whereType<Map<String, dynamic>>()
          .map(UnassignedCaptureItem.fromJson)
          .toList(growable: false),
      overdueTasks: overdue
          .whereType<Map<String, dynamic>>()
          .map(OverdueTaskItem.fromJson)
          .toList(growable: false),
      ordersWithoutDesign: noDesign
          .whereType<Map<String, dynamic>>()
          .map(OrderWithoutDesignItem.fromJson)
          .toList(growable: false),
      deliveredNotInvoiced: notInvoiced
          .whereType<Map<String, dynamic>>()
          .map(DeliveredNotInvoicedItem.fromJson)
          .toList(growable: false),
    );
  }

  final List<UnassignedCaptureItem> unassignedCaptures;
  final List<OverdueTaskItem> overdueTasks;
  final List<OrderWithoutDesignItem> ordersWithoutDesign;
  final List<DeliveredNotInvoicedItem> deliveredNotInvoiced;

  bool get isAllClear =>
      unassignedCaptures.isEmpty &&
      overdueTasks.isEmpty &&
      ordersWithoutDesign.isEmpty &&
      deliveredNotInvoiced.isEmpty;

  int get totalCount =>
      unassignedCaptures.length +
      overdueTasks.length +
      ordersWithoutDesign.length +
      deliveredNotInvoiced.length;
}
