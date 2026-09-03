import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/today/data/today_attention_repository.dart';

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
  group('TodayAttentionRepository', () {
    test(
      'fetchTodayAttention parses all four attention groups accurately',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            contains(TodayAttentionRepository.todayMethod),
          );
          return _json({
            'message': {
              'unassigned_captures': [
                {
                  'capture': 'CAP-001',
                  'said': 'Шкаф купе 3 метра',
                  'customer': 'Алибек',
                  'since': '2026-09-01 10:00:00',
                },
              ],
              'overdue_tasks': [
                {
                  'task': 'TASK-001',
                  'title': 'Замер кухни',
                  'who': 'Марат',
                  'was_due': '2026-08-30',
                  'on': 'CAP-001',
                },
              ],
              'orders_without_design': [
                {
                  'sales_order': 'SAL-ORD-00001',
                  'customer': 'ТОО Астана',
                  'due': '2026-09-15',
                },
              ],
              'delivered_not_invoiced': [
                {
                  'sales_order': 'SAL-ORD-00002',
                  'customer': 'ТОО Мебель',
                  'total': 1500000.0,
                  'delivered_percent': 100.0,
                  'billed_percent': 0.0,
                },
              ],
            },
          });
        });

        final client = FrappeClient(dio);
        final repo = TodayAttentionRepository(client);

        final result = await repo.fetchTodayAttention();

        expect(result.isAllClear, isFalse);
        expect(result.totalCount, 4);

        expect(result.unassignedCaptures.length, 1);
        expect(result.unassignedCaptures.first.capture, 'CAP-001');
        expect(result.unassignedCaptures.first.said, 'Шкаф купе 3 метра');
        expect(result.unassignedCaptures.first.customer, 'Алибек');

        expect(result.overdueTasks.length, 1);
        expect(result.overdueTasks.first.task, 'TASK-001');
        expect(result.overdueTasks.first.who, 'Марат');

        expect(result.ordersWithoutDesign.length, 1);
        expect(result.ordersWithoutDesign.first.salesOrder, 'SAL-ORD-00001');

        expect(result.deliveredNotInvoiced.length, 1);
        expect(result.deliveredNotInvoiced.first.salesOrder, 'SAL-ORD-00002');
        expect(result.deliveredNotInvoiced.first.total, 1500000.0);
      },
    );

    test(
      'fetchTodayAttention returns isAllClear when all lists are empty',
      () async {
        final dio = createDio((options) async {
          return _json({
            'message': {
              'unassigned_captures': <Map<String, dynamic>>[],
              'overdue_tasks': <Map<String, dynamic>>[],
              'orders_without_design': <Map<String, dynamic>>[],
              'delivered_not_invoiced': <Map<String, dynamic>>[],
            },
          });
        });

        final client = FrappeClient(dio);
        final repo = TodayAttentionRepository(client);

        final result = await repo.fetchTodayAttention();

        expect(result.isAllClear, isTrue);
        expect(result.totalCount, 0);
      },
    );
  });
}
