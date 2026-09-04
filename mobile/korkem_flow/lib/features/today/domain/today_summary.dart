import 'package:flutter/foundation.dart';

/// The metrics that answer the owner's morning question:
/// "What is important today?"
///
/// All values are computed and provided by the server. The client never
/// recalculates deadlines or deficits, preserving single-source truth.
@immutable
class TodaySummary {
  const TodaySummary({
    this.overdueOrders = 0,
    this.dueTodayOrders = 0,
    this.dueThisWeekOrders = 0,
    this.unpaidAmount = 0,
    this.materialDeficitCount = 0,
    this.installationsToday = 0,
    this.pendingApprovals = 0,
  });

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    return TodaySummary(
      overdueOrders: _asInt(
        json['overdue_orders'] ?? json['overdue'] ?? json['late_orders'],
      ),
      dueTodayOrders: _asInt(
        json['due_today_orders'] ?? json['due_today'] ?? json['today_orders'],
      ),
      dueThisWeekOrders: _asInt(
        json['due_this_week_orders'] ??
            json['due_this_week'] ??
            json['week_orders'],
      ),
      unpaidAmount: _asDouble(
        json['unpaid_amount'] ?? json['unpaid'] ?? json['not_invoiced'],
      ),
      materialDeficitCount: _asInt(
        json['material_deficit_count'] ??
            json['material_deficit_positions'] ??
            json['deficit_count'] ??
            json['deficit_positions'],
      ),
      installationsToday: _asInt(
        json['installations_today'] ??
            json['installations'] ??
            json['montage_today'],
      ),
      pendingApprovals: _asInt(
        json['pending_approvals'] ??
            json['approvals'] ??
            json['pending_actions'],
      ),
    );
  }

  /// 1. Просрочено (заказы)
  final int overdueOrders;

  /// 2. Сдать сегодня (заказы)
  final int dueTodayOrders;

  /// 3. Сдать на этой неделе (заказы)
  final int dueThisWeekOrders;

  /// 4. Не оплачено (₸)
  final double unpaidAmount;

  /// 5. Материала не хватает (позиции)
  final int materialDeficitCount;

  /// 6. Монтаж сегодня
  final int installationsToday;

  /// 7. Требует решения (согласования)
  final int pendingApprovals;

  /// True when no metric requires attention (everything is zero / on track).
  bool get isAllClear =>
      overdueOrders == 0 &&
      dueTodayOrders == 0 &&
      dueThisWeekOrders == 0 &&
      unpaidAmount <= 0 &&
      materialDeficitCount == 0 &&
      installationsToday == 0 &&
      pendingApprovals == 0;

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodaySummary &&
          other.overdueOrders == overdueOrders &&
          other.dueTodayOrders == dueTodayOrders &&
          other.dueThisWeekOrders == dueThisWeekOrders &&
          other.unpaidAmount == unpaidAmount &&
          other.materialDeficitCount == materialDeficitCount &&
          other.installationsToday == installationsToday &&
          other.pendingApprovals == pendingApprovals;

  @override
  int get hashCode => Object.hash(
    overdueOrders,
    dueTodayOrders,
    dueThisWeekOrders,
    unpaidAmount,
    materialDeficitCount,
    installationsToday,
    pendingApprovals,
  );

  @override
  String toString() =>
      'TodaySummary(overdue: $overdueOrders, dueToday: $dueTodayOrders, '
      'dueThisWeek: $dueThisWeekOrders, unpaid: $unpaidAmount, '
      'materialDeficit: $materialDeficitCount, '
      'installations: $installationsToday, '
      'pendingApprovals: $pendingApprovals)';
}
