import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/orders/domain/order_invoice.dart';

final orderInvoiceRepositoryProvider = Provider<OrderInvoiceRepository>(
  (ref) => OrderInvoiceRepository(ref.watch(frappeClientProvider)),
);

/// Communicates with Frappe/ERPNext for the Stage 12 Invoicing lifecycle.
class OrderInvoiceRepository {
  const OrderInvoiceRepository(this._client);

  static const draftMethod = 'korkem_manufacturing.api.invoicing.draft';

  final FrappeClient _client;

  /// Fetches the sales invoice issued against a sales order.
  Future<OrderInvoice> fetchInvoice(String salesOrder) async {
    final invoiceItems = await _client.getList(
      'Sales Invoice Item',
      FrappeQuery(
        fields: const ['parent'],
        filters: [
          FrappeFilter.equals('sales_order', salesOrder),
          const FrappeFilter.equals('parenttype', 'Sales Invoice'),
        ],
        limitPageLength: 10,
      ),
    );

    if (invoiceItems.isEmpty) {
      return OrderInvoice(salesOrder: salesOrder);
    }

    final parentNames = invoiceItems
        .map((it) => it['parent'] as String?)
        .whereType<String>()
        .toSet()
        .toList(growable: false);

    if (parentNames.isEmpty) {
      return OrderInvoice(salesOrder: salesOrder);
    }

    final invoices = await _client.getList(
      'Sales Invoice',
      FrappeQuery(
        fields: const [
          'name',
          'grand_total',
          'status',
          'posting_date',
          'docstatus',
        ],
        filters: [
          FrappeFilter.isIn('name', parentNames),
          const FrappeFilter('docstatus', '<', 2),
        ],
        orderBy: 'creation desc',
        limitPageLength: 1,
      ),
    );

    return OrderInvoice.fromDoc(
      salesOrder: salesOrder,
      doc: invoices.firstOrNull,
    );
  }

  /// Drafts a sales invoice for shipped items.
  Future<Map<String, dynamic>> draftInvoice(String salesOrder) async {
    final response = await _client.callMethod(
      draftMethod,
      params: {'sales_order': salesOrder},
      post: true,
    );
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }
}
