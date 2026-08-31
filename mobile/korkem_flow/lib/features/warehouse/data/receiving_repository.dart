import 'package:korkem_flow/core/api/frappe_client.dart';

/// Booking a delivery in, without a language model in the path.
///
/// Kept in the warehouse feature rather than beside the production commands
/// because it is a different person's job: a store keeper books in a pallet
/// and holds `Stock User`, which is not what a cutting operator holds. The
/// endpoint enforces that; this is only the client half.
///
/// Calls `korkem_manufacturing.api.purchasing.receive_purchase_order` — the
/// same function the AI tool is registered against, asserted by a backend test.
class ReceivingRepository {
  const ReceivingRepository(this._client);

  static const receivePath =
      'korkem_manufacturing.api.purchasing.receive_purchase_order';

  static const orderPath =
      'korkem_manufacturing.api.purchasing.create_purchase_order';

  final FrappeClient _client;

  /// Receives everything still outstanding, or only [items] for a partial one.
  ///
  /// Quantities in [items] are a *ceiling*, not an instruction: the server
  /// trims each line to what the order still has outstanding, so asking for
  /// four hundred sheets against an order for four receives four. The order is
  /// the fact; the request is not.
  Future<ReceiptResult> receive(
    String purchaseOrder, {
    List<Map<String, Object?>>? items,
  }) async {
    final response = await _client.callMethod(
      receivePath,
      // POST: this moves the stock ledger.
      post: true,
      params: {
        'purchase_order': purchaseOrder,
        'items': ?items,
      },
    );
    return ReceiptResult.fromJson(response['message'] ?? response);
  }

  /// Turns a material request into an order with a supplier.
  ///
  /// There is deliberately no price argument, and there must never be one.
  /// Rates, taxes and terms come from the supplier's price list through
  /// ERPNext's own party lookup — a purchase order carries money somebody has
  /// to pay, and a figure typed on a phone is not a defensible source for it.
  Future<PurchaseOrderResult> order(
    String materialRequest, {
    String? supplier,
    String? scheduleDate,
  }) async {
    final response = await _client.callMethod(
      orderPath,
      post: true,
      params: {
        'material_request': materialRequest,
        'supplier': ?supplier,
        'schedule_date': ?scheduleDate,
      },
    );
    return PurchaseOrderResult.fromJson(response['message'] ?? response);
  }
}

/// The order the server created, read back rather than assumed.
class PurchaseOrderResult {
  const PurchaseOrderResult({
    required this.status,
    this.purchaseOrder,
    this.supplier,
    this.grandTotal,
    this.message,
  });

  factory PurchaseOrderResult.fromJson(Object? raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return PurchaseOrderResult(
      status: ReceiptResult._text(json['status']) ?? 'unknown',
      purchaseOrder: ReceiptResult._text(json['purchase_order']),
      supplier: ReceiptResult._text(json['supplier']),
      grandTotal: switch (json['grand_total']) {
        final num number => number.toDouble(),
        final String text => double.tryParse(text),
        _ => null,
      },
      message: ReceiptResult._text(json['message']),
    );
  }

  final String status;
  final String? purchaseOrder;
  final String? supplier;

  /// What the order came to, priced by ERPNext. Displayed, never recomputed.
  final double? grandTotal;
  final String? message;

  bool get placed => purchaseOrder != null;
}

/// What the server booked. Every figure is ERPNext's.
class ReceiptResult {
  const ReceiptResult({
    required this.status,
    this.purchaseReceipt,
    this.message,
    this.received = const [],
  });

  factory ReceiptResult.fromJson(Object? raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return ReceiptResult(
      status: _text(json['status']) ?? 'unknown',
      purchaseReceipt: _text(json['purchase_receipt']),
      message: _text(json['message']),
      received: _lines(json['received']),
    );
  }

  final String status;
  final String? purchaseReceipt;
  final String? message;
  final List<ReceivedLine> received;

  bool get booked => purchaseReceipt != null;

  static List<ReceivedLine> _lines(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(ReceivedLine.fromJson)
        .toList(growable: false);
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// One line that actually landed on the shelf.
class ReceivedLine {
  const ReceivedLine({required this.itemCode, required this.qty, this.uom});

  factory ReceivedLine.fromJson(Map<String, dynamic> json) => ReceivedLine(
    itemCode: ReceiptResult._text(json['item_code']) ?? '',
    qty: switch (json['qty']) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text) ?? 0,
      _ => 0,
    },
    uom: ReceiptResult._text(json['uom']),
  );

  final String itemCode;
  final double qty;
  final String? uom;
}
