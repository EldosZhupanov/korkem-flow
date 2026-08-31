import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:meta/meta.dart';

/// An ERPNext `Sales Order` — customer order triggering production and billing.
@immutable
class SalesOrder {
  const SalesOrder({
    required this.name,
    required this.customer,
    required this.status,
    this.transactionDate,
    this.deliveryDate,
    this.grandTotal = 0,
    this.perDelivered = 0,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      name: _text(json['name']) ?? '',
      customer: _text(json['customer']) ?? '',
      status: SalesOrderStatus.fromWire(json['status'] as String?),
      transactionDate: _date(json['transaction_date']),
      deliveryDate: _date(json['delivery_date']),
      grandTotal: _number(json['grand_total']) ?? 0,
      perDelivered: _number(json['per_delivered']) ?? 0,
    );
  }

  final String name;
  final String customer;
  final SalesOrderStatus status;
  final DateTime? transactionDate;
  final DateTime? deliveryDate;
  final double grandTotal;
  final double perDelivered;

  /// Progress of delivery in 0.0–1.0 range.
  double get deliveryProgress => (perDelivered / 100.0).clamp(0.0, 1.0);

  bool get isDelivered => perDelivered >= 100.0;

  /// Whether this order has missed its delivery date as of [now].
  bool isLateAt(DateTime now) {
    final delivery = deliveryDate;
    if (delivery == null || status.isFinished) return false;
    return now.isAfter(delivery);
  }

  @override
  bool operator ==(Object other) => other is SalesOrder && other.name == name;

  @override
  int get hashCode => name.hashCode;

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : DateTime.tryParse(trimmed);
  }
}

/// The `Sales Order.status` Select in ERPNext.
enum SalesOrderStatus {
  draft('Draft', StatusIntent.neutral),
  toDeliverAndBill('To Deliver and Bill', StatusIntent.info),
  toBill('To Bill', StatusIntent.info),
  toDeliver('To Deliver', StatusIntent.info),
  completed('Completed', StatusIntent.success),
  cancelled('Cancelled', StatusIntent.neutral),
  closed('Closed', StatusIntent.neutral),
  onHold('On Hold', StatusIntent.danger);

  const SalesOrderStatus(this.wireValue, this.intent);

  final String wireValue;
  final StatusIntent intent;

  static SalesOrderStatus fromWire(String? value) {
    for (final status in SalesOrderStatus.values) {
      if (status.wireValue == value) return status;
    }
    return SalesOrderStatus.draft;
  }

  bool get isFinished =>
      this == completed || this == closed || this == cancelled;

  bool get canStartProduction =>
      this == toDeliverAndBill ||
      this == toDeliver ||
      this == toBill ||
      this == draft;
}
