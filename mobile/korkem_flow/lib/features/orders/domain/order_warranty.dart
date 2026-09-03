import 'package:flutter/foundation.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Warranty state of a single sales order item.
@immutable
class OrderWarrantyItem {
  const OrderWarrantyItem({
    required this.itemCode,
    this.itemName,
    this.days = 0,
    this.until,
    this.active = false,
  });

  factory OrderWarrantyItem.fromJson(Map<String, dynamic> json) {
    DateTime? untilDate;
    final untilVal = json['until'];
    if (untilVal is String && untilVal.isNotEmpty) {
      untilDate = DateTime.tryParse(untilVal);
    }

    return OrderWarrantyItem(
      itemCode: (json['item_code'] as String?) ?? '',
      itemName: json['item_name'] as String?,
      days: (json['days'] as num?)?.toInt() ?? 0,
      until: untilDate,
      active: json['active'] as bool? ?? false,
    );
  }

  final String itemCode;
  final String? itemName;
  final int days;
  final DateTime? until;
  final bool active;

  bool get hasWarranty => days > 0 && until != null;

  String localizedStatus(AppLocalizations l10n) {
    if (days <= 0 || until == null) {
      return l10n.orderWarrantyStatusNoWarranty;
    }
    if (active) {
      return l10n.orderWarrantyStatusActive;
    }
    return l10n.orderWarrantyStatusExpired;
  }

  StatusIntent get statusIntent {
    if (days <= 0 || until == null) {
      return StatusIntent.info;
    }
    if (active) {
      return StatusIntent.success;
    }
    return StatusIntent.danger;
  }
}

/// Warranty coverage for an entire sales order.
@immutable
class OrderWarranty {
  const OrderWarranty({
    required this.salesOrder,
    this.customer,
    this.shippedOn,
    this.items = const [],
  });

  factory OrderWarranty.fromJson(Map<String, dynamic> json) {
    DateTime? shippedOnDate;
    final shippedVal = json['shipped_on'];
    if (shippedVal is String && shippedVal.isNotEmpty) {
      shippedOnDate = DateTime.tryParse(shippedVal);
    }

    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(OrderWarrantyItem.fromJson)
        .toList(growable: false);

    return OrderWarranty(
      salesOrder: (json['sales_order'] as String?) ?? '',
      customer: json['customer'] as String?,
      shippedOn: shippedOnDate,
      items: items,
    );
  }

  final String salesOrder;
  final String? customer;
  final DateTime? shippedOn;
  final List<OrderWarrantyItem> items;

  bool get isShipped => shippedOn != null;
  bool get hasActiveWarranty => items.any((i) => i.active);
}
