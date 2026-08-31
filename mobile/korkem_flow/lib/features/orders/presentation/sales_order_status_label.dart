import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Display names for `Sales Order.status`.
extension SalesOrderStatusLabel on SalesOrderStatus {
  String label(AppLocalizations l10n) => switch (this) {
    SalesOrderStatus.draft => l10n.soDraft,
    SalesOrderStatus.toDeliverAndBill => l10n.soToDeliverAndBill,
    SalesOrderStatus.toBill => l10n.soToBill,
    SalesOrderStatus.toDeliver => l10n.soToDeliver,
    SalesOrderStatus.completed => l10n.soCompleted,
    SalesOrderStatus.cancelled => l10n.soCancelled,
    SalesOrderStatus.closed => l10n.soClosed,
    SalesOrderStatus.onHold => l10n.soOnHold,
  };
}
