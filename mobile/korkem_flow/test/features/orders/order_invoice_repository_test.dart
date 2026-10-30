import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/orders/data/order_invoice_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_invoice.dart';

Dio createDio(Future<ResponseBody> Function(RequestOptions) handler) {
  return Dio()..httpClientAdapter = _TestAdapter(handler);
}

class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('OrderInvoiceRepository', () {
    test(
      'fetchInvoice returns notDrafted when no invoice item exists',
      () async {
        final dio = createDio((options) async {
          return _json({'data': <Map<String, dynamic>>[]});
        });

        final client = FrappeClient(dio);
        final repo = OrderInvoiceRepository(client);

        final result = await repo.fetchInvoice('SAL-ORD-00001');

        expect(result.salesOrder, 'SAL-ORD-00001');
        expect(result.status, OrderInvoiceStatus.notDrafted);
        expect(result.hasInvoice, isFalse);
        expect(result.name, isNull);
      },
    );

    test(
      'fetchInvoice returns invoice details when linked invoice exists',
      () async {
        final dio = createDio((options) async {
          if (options.path.contains('Sales%20Invoice%20Item') ||
              options.path.contains('Sales Invoice Item')) {
            return _json({
              'data': [
                {'parent': 'ACC-SINV-2026-00001'},
              ],
            });
          }
          if (options.path.contains('Sales%20Invoice') ||
              options.path.contains('Sales Invoice')) {
            return _json({
              'data': [
                {
                  'name': 'ACC-SINV-2026-00001',
                  'grand_total': 1450000,
                  'status': 'Draft',
                  'posting_date': '2026-09-03',
                  'docstatus': 0,
                },
              ],
            });
          }
          return _json({'data': <Map<String, dynamic>>[]});
        });

        final client = FrappeClient(dio);
        final repo = OrderInvoiceRepository(client);

        final result = await repo.fetchInvoice('SAL-ORD-00001');

        expect(result.salesOrder, 'SAL-ORD-00001');
        expect(result.name, 'ACC-SINV-2026-00001');
        expect(result.grandTotal, 1450000);
        expect(result.status, OrderInvoiceStatus.drafted);
        expect(result.hasInvoice, isTrue);
        expect(result.postingDate, DateTime(2026, 9, 3));
      },
    );

    test('draftInvoice calls endpoint and returns created invoice', () async {
      String? sentOrder;

      final dio = createDio((options) async {
        expect(options.path, contains(OrderInvoiceRepository.draftMethod));
        final body = options.data as Map<String, dynamic>;
        sentOrder = body['sales_order'] as String?;

        return _json({
          'message': {
            'sales_order': 'SAL-ORD-00001',
            'invoice': 'ACC-SINV-2026-00001',
            'total': 1450000.0,
            'delivered_qty': 3.0,
            'status': 'drafted',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = OrderInvoiceRepository(client);

      final result = await repo.draftInvoice('SAL-ORD-00001');

      expect(sentOrder, 'SAL-ORD-00001');
      expect(result['invoice'], 'ACC-SINV-2026-00001');
      expect(result['status'], 'drafted');
    });
  });
}
