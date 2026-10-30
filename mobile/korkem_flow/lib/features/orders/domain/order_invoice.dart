import 'package:flutter/foundation.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Status of the invoice for a sales order.
enum OrderInvoiceStatus {
  notDrafted,
  drafted,
  paid;

  String localized(AppLocalizations l10n) => switch (this) {
    notDrafted => l10n.orderInvoicingStatusNotDrafted,
    drafted => l10n.orderInvoicingStatusDrafted,
    paid => l10n.orderInvoicingStatusPaid,
  };

  StatusIntent get intent => switch (this) {
    notDrafted => StatusIntent.info,
    drafted => StatusIntent.warning,
    paid => StatusIntent.success,
  };

  static OrderInvoiceStatus fromString(String? status) {
    if (status == null || status.isEmpty) return notDrafted;
    final s = status.trim().toLowerCase();
    if (s == 'paid') return paid;
    if (s == 'draft' ||
        s == 'unpaid' ||
        s == 'drafted' ||
        s == 'submitted' ||
        s == 'already_drafted') {
      return drafted;
    }
    return drafted;
  }
}

/// The state of the Sales Invoice linked to a Sales Order.
@immutable
class OrderInvoice {
  const OrderInvoice({
    required this.salesOrder,
    this.name,
    this.grandTotal = 0,
    this.status = OrderInvoiceStatus.notDrafted,
    this.postingDate,
  });

  factory OrderInvoice.fromDoc({
    required String salesOrder,
    required Map<String, dynamic>? doc,
  }) {
    if (doc == null || doc.isEmpty) {
      return OrderInvoice(salesOrder: salesOrder);
    }
    DateTime? postingDate;
    final dateVal = doc['posting_date'];
    if (dateVal is String && dateVal.isNotEmpty) {
      postingDate = DateTime.tryParse(dateVal);
    }

    final rawStatus = doc['status'] as String?;
    return OrderInvoice(
      salesOrder: salesOrder,
      name: doc['name'] as String?,
      grandTotal: (doc['grand_total'] as num?)?.toDouble() ?? 0,
      status: OrderInvoiceStatus.fromString(rawStatus),
      postingDate: postingDate,
    );
  }

  final String salesOrder;
  final String? name;
  final double grandTotal;
  final OrderInvoiceStatus status;
  final DateTime? postingDate;

  bool get hasInvoice => name != null && name!.isNotEmpty;
}
