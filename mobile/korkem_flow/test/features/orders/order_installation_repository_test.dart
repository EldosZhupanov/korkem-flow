import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/orders/data/order_installation_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_installation.dart';

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
  group('OrderInstallationRepository', () {
    test(
      'fetchInstallation returns notScheduled when no task exists',
      () async {
        final dio = createDio((options) async {
          if (options.path.contains('CRM')) {
            return _json({'data': <Map<String, dynamic>>[]});
          }
          if (options.path.contains('Comment')) {
            return _json({'data': <Map<String, dynamic>>[]});
          }
          return _json({'data': <Map<String, dynamic>>[]});
        });

        final client = FrappeClient(dio);
        final repo = OrderInstallationRepository(client);

        final result = await repo.fetchInstallation('SAL-ORD-00001');

        expect(result.salesOrder, 'SAL-ORD-00001');
        expect(result.status, OrderInstallationStatus.notScheduled);
        expect(result.isScheduled, isFalse);
        expect(result.installer, isNull);
      },
    );

    test('fetchInstallation returns scheduled task with crew notes', () async {
      final dio = createDio((options) async {
        if (options.path.contains('CRM')) {
          return _json({
            'data': [
              {
                'name': 'TASK-INSTALL-001',
                'title': 'Монтаж по заказу SAL-ORD-00001',
                'assigned_to': 'installer@korkem.kz',
                'due_date': '2026-09-15',
                'status': 'Done',
              },
            ],
          });
        }
        if (options.path.contains('Comment')) {
          return _json({
            'data': [
              {
                'name': 'COMM-001',
                'content':
                    'KORKEM: монтаж — стена кривая, ставили с доборником',
                'creation': '2026-09-15 17:00:00',
              },
            ],
          });
        }
        return _json({'data': <Map<String, dynamic>>[]});
      });

      final client = FrappeClient(dio);
      final repo = OrderInstallationRepository(client);

      final result = await repo.fetchInstallation('SAL-ORD-00001');

      expect(result.salesOrder, 'SAL-ORD-00001');
      expect(result.taskId, 'TASK-INSTALL-001');
      expect(result.installer, 'installer@korkem.kz');
      expect(result.installDate, DateTime(2026, 9, 15));
      expect(result.status, OrderInstallationStatus.completed);
      expect(result.isCompleted, isTrue);
      expect(result.notes, 'стена кривая, ставили с доборником');
    });

    test(
      'scheduleInstallation calls API and returns scheduled status',
      () async {
        String? sentSalesOrder;
        String? sentInstaller;
        String? sentInstallOn;

        final dio = createDio((options) async {
          expect(
            options.path,
            contains(OrderInstallationRepository.scheduleMethod),
          );
          final body = options.data as Map<String, dynamic>;
          sentSalesOrder = body['sales_order'] as String?;
          sentInstaller = body['installer'] as String?;
          sentInstallOn = body['install_on'] as String?;

          return _json({
            'message': {
              'sales_order': 'SAL-ORD-00001',
              'task': 'TASK-INSTALL-001',
              'installer': 'installer@korkem.kz',
              'install_on': '2026-09-15',
              'delivered_qty': 5,
              'status': 'scheduled',
            },
          });
        });

        final client = FrappeClient(dio);
        final repo = OrderInstallationRepository(client);

        final result = await repo.scheduleInstallation(
          salesOrder: 'SAL-ORD-00001',
          installer: 'installer@korkem.kz',
          installOn: '2026-09-15',
        );

        expect(sentSalesOrder, 'SAL-ORD-00001');
        expect(sentInstaller, 'installer@korkem.kz');
        expect(sentInstallOn, '2026-09-15');
        expect(result['status'], 'scheduled');
      },
    );

    test('completeInstallation calls API and passes crew notes', () async {
      String? sentSalesOrder;
      String? sentNotes;

      final dio = createDio((options) async {
        expect(
          options.path,
          contains(OrderInstallationRepository.completeMethod),
        );
        final body = options.data as Map<String, dynamic>;
        sentSalesOrder = body['sales_order'] as String?;
        sentNotes = body['notes'] as String?;

        return _json({
          'message': {
            'sales_order': 'SAL-ORD-00001',
            'task_closed': 'TASK-INSTALL-001',
            'status': 'completed',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = OrderInstallationRepository(client);

      final result = await repo.completeInstallation(
        salesOrder: 'SAL-ORD-00001',
        notes: 'Установка завершена успешно',
      );

      expect(sentSalesOrder, 'SAL-ORD-00001');
      expect(sentNotes, 'Установка завершена успешно');
      expect(result['status'], 'completed');
    });
  });
}
