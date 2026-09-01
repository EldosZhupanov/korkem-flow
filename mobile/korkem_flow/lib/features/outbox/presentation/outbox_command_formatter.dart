import 'package:flutter/material.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Human-readable presentation model for a queued [PendingMutation].
class OutboxCommandInfo {
  const OutboxCommandInfo({
    required this.title,
    required this.icon,
    this.details = const [],
  });

  final String title;
  final IconData icon;
  final List<String> details;
}

/// Known Frappe/ERPNext endpoints and their human-readable translations.
abstract final class OutboxEndpoints {
  static const startProduction =
      'korkem_manufacturing.api.production.start_production';
  static const completeOperation =
      'korkem_manufacturing.api.production.complete_operation';
  static const receiveReceipt =
      'korkem_manufacturing.api.purchasing.receive_purchase_receipt';
  static const createPurchaseOrder =
      'korkem_manufacturing.api.purchasing.create_purchase_order';
  static const createDelivery =
      'korkem_manufacturing.api.dispatch.create_delivery';
}

/// Resolves a human-readable title, icon and key parameters for a queued
/// mutation.
OutboxCommandInfo describePendingMutation(
  PendingMutation mutation,
  AppLocalizations l10n,
) {
  final params = mutation.params;

  switch (mutation.path) {
    case OutboxEndpoints.startProduction:
      final salesOrder = params['sales_order']?.toString() ?? '';
      final itemCode = params['item_code']?.toString();
      final title = salesOrder.isNotEmpty
          ? l10n.outboxCommandStartProduction(salesOrder)
          : l10n.outboxCommandGeneric(mutation.path);

      return OutboxCommandInfo(
        title: title,
        icon: AppIcons.workOrder,
        details: [
          if (itemCode != null && itemCode.isNotEmpty)
            l10n.outboxParamItem(itemCode),
        ],
      );

    case OutboxEndpoints.completeOperation:
      final operation = params['operation']?.toString() ?? '';
      final workOrder = params['work_order']?.toString();
      final salesOrder = params['sales_order']?.toString();
      final completedQty = params['completed_qty']?.toString();
      final scrapQty = params['scrap_qty']?.toString();

      final displayOp = operation.isNotEmpty
          ? operation
          : (workOrder ?? salesOrder ?? '');
      final title = displayOp.isNotEmpty
          ? l10n.outboxCommandCompleteOperation(displayOp)
          : l10n.outboxCommandGeneric(mutation.path);

      return OutboxCommandInfo(
        title: title,
        icon: AppIcons.workOrder,
        details: [
          if (workOrder != null && workOrder.isNotEmpty)
            l10n.outboxParamWorkOrder(workOrder),
          if (completedQty != null && completedQty.isNotEmpty)
            l10n.outboxParamCompletedQty(completedQty),
          if (scrapQty != null && scrapQty.isNotEmpty && scrapQty != '0')
            l10n.outboxParamScrapQty(scrapQty),
        ],
      );

    case OutboxEndpoints.receiveReceipt:
      final purchaseOrder = params['purchase_order']?.toString() ?? '';
      final title = purchaseOrder.isNotEmpty
          ? l10n.outboxCommandReceiveReceipt(purchaseOrder)
          : l10n.outboxCommandGeneric(mutation.path);

      return OutboxCommandInfo(
        title: title,
        icon: AppIcons.warehouse,
      );

    case OutboxEndpoints.createPurchaseOrder:
      final materialRequest = params['material_request']?.toString() ?? '';
      final supplier = params['supplier']?.toString();
      final title = materialRequest.isNotEmpty
          ? l10n.outboxCommandCreatePurchaseOrder(materialRequest)
          : l10n.outboxCommandGeneric(mutation.path);

      return OutboxCommandInfo(
        title: title,
        icon: AppIcons.warehouse,
        details: [
          if (supplier != null && supplier.isNotEmpty)
            l10n.outboxParamSupplier(supplier),
        ],
      );

    case OutboxEndpoints.createDelivery:
      final salesOrder = params['sales_order']?.toString() ?? '';
      final title = salesOrder.isNotEmpty
          ? l10n.outboxCommandCreateDelivery(salesOrder)
          : l10n.outboxCommandGeneric(mutation.path);

      return OutboxCommandInfo(
        title: title,
        icon: AppIcons.deal,
      );

    default:
      return OutboxCommandInfo(
        title: l10n.outboxCommandGeneric(mutation.path),
        icon: AppIcons.refresh,
      );
  }
}
