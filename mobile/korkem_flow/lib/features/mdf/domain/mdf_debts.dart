import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

@immutable
class CustomerDebt {
  const CustomerDebt({
    required this.customer,
    required this.customerName,
    required this.orders,
    required this.debt,
  });

  factory CustomerDebt.fromJson(Map<String, dynamic> json) => CustomerDebt(
    customer: '${json['customer']}',
    customerName: '${json['customer_name'] ?? json['customer']}',
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    debt: _d(json['debt']),
  );

  final String customer;
  final String customerName;
  final int orders;
  final double debt;
}

@immutable
class OrderDebt {
  const OrderDebt({
    required this.name,
    required this.createdOn,
    required this.customer,
    required this.customerName,
    required this.total,
    required this.paid,
    required this.debt,
    this.handedOver = false,
  });

  factory OrderDebt.fromJson(Map<String, dynamic> json) => OrderDebt(
    name: '${json['name']}',
    createdOn: '${json['created_on'] ?? ''}',
    customer: '${json['customer'] ?? ''}',
    customerName: '${json['customer_name'] ?? ''}',
    total: _d(json['total']),
    paid: _d(json['paid']),
    debt: _d(json['debt']),
    handedOver: json['handed_over'] == true,
  );

  final String name;
  final String createdOn;
  final String customer;
  final String customerName;
  final double total;
  final double paid;
  final double debt;

  /// Handed over with a debt — the money that is hardest to collect.
  final bool handedOver;
}

/// OnayBaza's «Қарыз»: who owes what, by customer and by order.
@immutable
class MdfDebts {
  const MdfDebts({
    required this.customers,
    required this.orders,
    required this.total,
  });

  factory MdfDebts.fromJson(Map<String, dynamic> json) => MdfDebts(
    customers: [
      for (final c in json['customers'] as List? ?? const [])
        if (c is Map) CustomerDebt.fromJson(Map<String, dynamic>.from(c)),
    ],
    orders: [
      for (final o in json['orders'] as List? ?? const [])
        if (o is Map) OrderDebt.fromJson(Map<String, dynamic>.from(o)),
    ],
    total: _d(json['total']),
  );

  final List<CustomerDebt> customers;
  final List<OrderDebt> orders;
  final double total;
}
