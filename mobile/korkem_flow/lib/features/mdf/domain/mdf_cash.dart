import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

@immutable
class CashDay {
  const CashDay({
    required this.date,
    required this.moneyIn,
    required this.moneyOut,
    required this.net,
    required this.byMethod,
  });

  factory CashDay.fromJson(Map<String, dynamic> json) => CashDay(
    date: '${json['date']}',
    moneyIn: _d(json['in']),
    moneyOut: _d(json['out']),
    net: _d(json['net']),
    byMethod: {
      if (json['by_method'] is Map)
        for (final e in (json['by_method'] as Map).entries)
          '${e.key}': _d(e.value),
    },
  );

  final String date;
  final double moneyIn;
  final double moneyOut;
  final double net;
  final Map<String, double> byMethod;
}

@immutable
class CashPayment {
  const CashPayment({
    required this.date,
    required this.method,
    required this.order,
    required this.customerName,
    required this.amount,
  });

  factory CashPayment.fromJson(Map<String, dynamic> json) => CashPayment(
    date: '${json['date']}',
    method: '${json['method'] ?? '—'}',
    order: '${json['order'] ?? ''}',
    customerName: '${json['customer_name'] ?? ''}',
    amount: _d(json['amount']),
  );

  final String date;
  final String method;
  final String order;
  final String customerName;
  final double amount;
}

@immutable
class CashExpense {
  const CashExpense({
    required this.date,
    required this.purpose,
    required this.category,
    required this.amount,
  });

  factory CashExpense.fromJson(Map<String, dynamic> json) => CashExpense(
    date: '${json['date']}',
    purpose: '${json['purpose'] ?? ''}',
    category: '${json['category'] ?? ''}',
    amount: _d(json['amount']),
  );

  final String date;
  final String purpose;
  final String category;
  final double amount;
}

/// «Касса» — OnayBaza's «Төлем есебі»: money in by day and method, the
/// approved expenses, the balance.
@immutable
class MdfCash {
  const MdfCash({
    required this.since,
    required this.until,
    required this.days,
    required this.byMethod,
    required this.payments,
    required this.expenses,
    required this.totalIn,
    required this.totalOut,
    required this.net,
  });

  factory MdfCash.fromJson(Map<String, dynamic> json) => MdfCash(
    since: '${json['since'] ?? ''}',
    until: '${json['until'] ?? ''}',
    days: [
      for (final d in json['days'] as List? ?? const [])
        if (d is Map) CashDay.fromJson(Map<String, dynamic>.from(d)),
    ],
    byMethod: {
      for (final m in json['by_method'] as List? ?? const [])
        if (m is Map) '${m['method']}': _d(m['amount']),
    },
    payments: [
      for (final p in json['payments'] as List? ?? const [])
        if (p is Map) CashPayment.fromJson(Map<String, dynamic>.from(p)),
    ],
    expenses: [
      for (final e in json['expenses'] as List? ?? const [])
        if (e is Map) CashExpense.fromJson(Map<String, dynamic>.from(e)),
    ],
    totalIn: _d(json['total_in']),
    totalOut: _d(json['total_out']),
    net: _d(json['net']),
  );

  final String since;
  final String until;
  final List<CashDay> days;

  /// Biggest first.
  final Map<String, double> byMethod;
  final List<CashPayment> payments;
  final List<CashExpense> expenses;
  final double totalIn;
  final double totalOut;
  final double net;
}
