import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Orders, m², money: one group of the report, or all of it.
@immutable
class ReportGroup {
  const ReportGroup({
    required this.key,
    required this.orders,
    required this.areaM2,
    required this.total,
    required this.paid,
    required this.debt,
    this.label,
  });

  factory ReportGroup.fromJson(
    Map<String, dynamic> json, {
    String key = '',
    String? label,
  }) => ReportGroup(
    key: key,
    label: label,
    orders: _i(json['orders']),
    areaM2: _d(json['area_m2']),
    total: _d(json['total']),
    paid: _d(json['paid']),
    debt: _d(json['debt']),
  );

  final String key;
  final String? label;
  final int orders;
  final double areaM2;
  final double total;
  final double paid;
  final double debt;
}

/// «Отчёт по заказам» — OnayBaza's «Тапсырыс есебі».
@immutable
class MdfReport {
  const MdfReport({
    required this.since,
    required this.until,
    required this.all,
    required this.cancelled,
    required this.byStatus,
    required this.byDecor,
    required this.topCustomers,
  });

  factory MdfReport.fromJson(Map<String, dynamic> json) {
    List<ReportGroup> groups(String field, String key, [String? label]) => [
      for (final g in json[field] as List? ?? const [])
        if (g is Map)
          ReportGroup.fromJson(
            Map<String, dynamic>.from(g),
            key: '${g[key]}',
            label: label == null ? null : '${g[label] ?? ''}',
          ),
    ];
    return MdfReport(
      since: '${json['since'] ?? ''}',
      until: '${json['until'] ?? ''}',
      all: ReportGroup.fromJson(json),
      cancelled: _i(json['cancelled']),
      byStatus: groups('by_status', 'status'),
      byDecor: groups('by_decor', 'decor'),
      topCustomers: groups('top_customers', 'customer', 'customer_name'),
    );
  }

  final String since;
  final String until;
  final ReportGroup all;
  final int cancelled;
  final List<ReportGroup> byStatus;
  final List<ReportGroup> byDecor;
  final List<ReportGroup> topCustomers;
}
