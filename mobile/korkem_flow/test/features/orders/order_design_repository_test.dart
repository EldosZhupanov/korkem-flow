import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/orders/data/order_design_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_design.dart';

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
  group('OrderDesignRepository', () {
    test('fetchDesign returns notAssigned when no task exists', () async {
      final dio = createDio((options) async {
        if (options.path.contains('CRM')) {
          return _json({'data': <Map<String, dynamic>>[]});
        }
        if (options.path.contains('File')) {
          return _json({'data': <Map<String, dynamic>>[]});
        }
        return _json({'data': <Map<String, dynamic>>[]});
      });

      final client = FrappeClient(dio);
      final repo = OrderDesignRepository(client, dio);

      final result = await repo.fetchDesign('SAL-ORD-00001');

      expect(result.salesOrder, 'SAL-ORD-00001');
      expect(result.status, OrderDesignStatus.notAssigned);
      expect(result.isAssigned, isFalse);
      expect(result.attachments, isEmpty);
    });

    test('fetchDesign returns assigned task with deadline and files', () async {
      final dio = createDio((options) async {
        if (options.path.contains('CRM')) {
          return _json({
            'data': [
              {
                'name': 'TASK-001',
                'title': 'Дизайн по заказу SAL-ORD-00001',
                'assigned_to': 'designer@korkem.kz',
                'due_date': '2026-09-10',
                'status': 'Todo',
              },
            ],
          });
        }
        if (options.path.contains('File')) {
          return _json({
            'data': [
              {
                'name': 'FILE-001',
                'file_name': 'чертёж_кухня.dxf',
                'file_size': 10240,
                'creation': '2026-09-03 12:00:00',
              },
            ],
          });
        }
        return _json({'data': <Map<String, dynamic>>[]});
      });

      final client = FrappeClient(dio);
      final repo = OrderDesignRepository(client, dio);

      final result = await repo.fetchDesign('SAL-ORD-00001');

      expect(result.salesOrder, 'SAL-ORD-00001');
      expect(result.taskId, 'TASK-001');
      expect(result.designer, 'designer@korkem.kz');
      expect(result.status, OrderDesignStatus.assigned);
      expect(result.dueDate, DateTime(2026, 9, 10));
      expect(result.attachments.length, 1);
      expect(result.attachments.first.fileName, 'чертёж_кухня.dxf');
    });

    test(
      'assignDesign calls server API and returns assigned payload',
      () async {
        String? sentSalesOrder;
        String? sentDesigner;
        String? sentDueOn;

        final dio = createDio((options) async {
          expect(options.path, contains(OrderDesignRepository.assignMethod));
          final body = options.data as Map<String, dynamic>;
          sentSalesOrder = body['sales_order'] as String?;
          sentDesigner = body['designer'] as String?;
          sentDueOn = body['due_on'] as String?;

          return _json({
            'message': {
              'sales_order': 'SAL-ORD-00001',
              'task': 'TASK-001',
              'designer': 'designer@korkem.kz',
              'due_on': '2026-09-10',
              'status': 'assigned',
            },
          });
        });

        final client = FrappeClient(dio);
        final repo = OrderDesignRepository(client, dio);

        final result = await repo.assignDesign(
          salesOrder: 'SAL-ORD-00001',
          designer: 'designer@korkem.kz',
          dueOn: '2026-09-10',
        );

        expect(sentSalesOrder, 'SAL-ORD-00001');
        expect(sentDesigner, 'designer@korkem.kz');
        expect(sentDueOn, '2026-09-10');
        expect(result['status'], 'assigned');
      },
    );

    test(
      'deliverDesign calls server API and returns delivered payload',
      () async {
        String? sentSalesOrder;

        final dio = createDio((options) async {
          expect(options.path, contains(OrderDesignRepository.deliverMethod));
          final body = options.data as Map<String, dynamic>;
          sentSalesOrder = body['sales_order'] as String?;

          return _json({
            'message': {
              'sales_order': 'SAL-ORD-00001',
              'task_closed': 'TASK-001',
              'files': ['чертёж.dxf'],
              'status': 'delivered',
            },
          });
        });

        final client = FrappeClient(dio);
        final repo = OrderDesignRepository(client, dio);

        final result = await repo.deliverDesign(salesOrder: 'SAL-ORD-00001');

        expect(sentSalesOrder, 'SAL-ORD-00001');
        expect(result['status'], 'delivered');
      },
    );

    test('attachFile posts to /api/resource/File', () async {
      String? attachedDocname;
      String? attachedFileName;

      final dio = createDio((options) async {
        expect(options.path, contains('/api/resource/File'));
        final body = options.data as Map<String, dynamic>;
        attachedDocname = body['attached_to_name'] as String?;
        attachedFileName = body['file_name'] as String?;

        return _json({
          'data': {
            'name': 'FILE-002',
            'file_name': 'спецификация.pdf',
            'attached_to_doctype': 'Sales Order',
            'attached_to_name': 'SAL-ORD-00001',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = OrderDesignRepository(client, dio);

      final result = await repo.attachFile(
        salesOrder: 'SAL-ORD-00001',
        fileName: 'спецификация.pdf',
      );

      expect(attachedDocname, 'SAL-ORD-00001');
      expect(attachedFileName, 'спецификация.pdf');
      expect(result.name, 'FILE-002');
      expect(result.fileName, 'спецификация.pdf');
    });
  });
}
