import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/orders/data/order_warranty_repository.dart';

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
  group('OrderWarrantyRepository', () {
    test('fetchWarranty returns warranty status with items', () async {
      final dio = createDio((options) async {
        expect(options.path, contains(OrderWarrantyRepository.statusMethod));
        return _json({
          'message': {
            'sales_order': 'SAL-ORD-00001',
            'customer': 'ТОО Мебель Астана',
            'shipped_on': '2026-08-20',
            'items': [
              {
                'item_code': 'KITCHEN-MOD-01',
                'item_name': 'Кухонный гарнитур',
                'days': 365,
                'until': '2027-08-20',
                'active': true,
              },
              {
                'item_code': 'FITTING-01',
                'item_name': 'Петли доводчики',
                'days': 30,
                'until': '2026-09-19',
                'active': false,
              },
            ],
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = OrderWarrantyRepository(client);

      final result = await repo.fetchWarranty('SAL-ORD-00001');

      expect(result.salesOrder, 'SAL-ORD-00001');
      expect(result.customer, 'ТОО Мебель Астана');
      expect(result.shippedOn, DateTime(2026, 8, 20));
      expect(result.isShipped, isTrue);
      expect(result.hasActiveWarranty, isTrue);
      expect(result.items.length, 2);

      final first = result.items[0];
      expect(first.itemCode, 'KITCHEN-MOD-01');
      expect(first.itemName, 'Кухонный гарнитур');
      expect(first.days, 365);
      expect(first.until, DateTime(2027, 8, 20));
      expect(first.active, isTrue);

      final second = result.items[1];
      expect(second.itemCode, 'FITTING-01');
      expect(second.active, isFalse);
    });

    test(
      'claimWarranty calls POST claim endpoint and returns claim id',
      () async {
        String? sentOrder;
        String? sentItem;
        String? sentComplaint;

        final dio = createDio((options) async {
          expect(options.path, contains(OrderWarrantyRepository.claimMethod));
          final body = options.data as Map<String, dynamic>;
          sentOrder = body['sales_order'] as String?;
          sentItem = body['item_code'] as String?;
          sentComplaint = body['complaint'] as String?;

          return _json({
            'message': {
              'sales_order': 'SAL-ORD-00001',
              'claim': 'WAR-CLM-2026-0001',
              'item_code': 'KITCHEN-MOD-01',
              'warranty_until': '2027-08-20',
              'status': 'accepted',
            },
          });
        });

        final client = FrappeClient(dio);
        final repo = OrderWarrantyRepository(client);

        final result = await repo.claimWarranty(
          salesOrder: 'SAL-ORD-00001',
          itemCode: 'KITCHEN-MOD-01',
          complaint: 'Отслоилась кромка на нижнем фасаде',
        );

        expect(sentOrder, 'SAL-ORD-00001');
        expect(sentItem, 'KITCHEN-MOD-01');
        expect(sentComplaint, 'Отслоилась кромка на нижнем фасаде');
        expect(result['claim'], 'WAR-CLM-2026-0001');
        expect(result['status'], 'accepted');
      },
    );
  });
}
