import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late WorkOrderRepository repository;

  setUp(() {
    client = _MockClient();
    repository = WorkOrderRepository(client);
  });

  void respond(Map<String, dynamic> message) {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: any(named: 'post'),
      ),
    ).thenAnswer((_) async => {'message': message});
  }

  Map<String, dynamic> sentParams() =>
      verify(
            () => client.callMethod(
              any(),
              params: captureAny(named: 'params'),
              post: any(named: 'post'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('fetching work orders reaches the query endpoint', () {
    test('it calls the dedicated query method, not /api/resource/', () async {
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(pageSize: 20);

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                ),
              ).captured.single
              as String;

      expect(path, 'korkem_manufacturing.api.queries.work_orders');
    });

    test('it never sends a company argument', () async {
      // Company scope is resolved server-side from session.
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(pageSize: 20);

      final params = sentParams();
      expect(params.containsKey('company'), isFalse);
      expect(params.containsKey('organization'), isFalse);
    });

    test('it sends pagination parameters', () async {
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(pageSize: 15, offset: 30);

      final params = sentParams();
      expect(params['limit'], 15);
      expect(params['offset'], 30);
    });

    test('it sends status filter when present', () async {
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(
        pageSize: 20,
        status: WorkOrderStatus.inProcess,
      );

      final params = sentParams();
      expect(params['status'], 'In Process');
    });

    test('it trims and sends search query when present', () async {
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(pageSize: 20, search: '  Стол Обеденный  ');

      final params = sentParams();
      expect(params['search'], 'Стол Обеденный');
    });
  });

  group('work orders response parsing', () {
    test('parses order list according to contract', () async {
      respond({
        'orders': [
          {
            'name': 'MFG-WO-2026-00001',
            'production_item': 'ITEM-001',
            'item_name': 'Шкаф 3-дверный',
            'qty': 10.0,
            'produced_qty': 4.0,
            'status': 'In Process',
            'planned_end_date': '2026-09-01T18:00:00',
            'actual_end_date': null,
            'sales_order': 'SAL-ORD-2026-00001',
            'bom_no': 'BOM-ITEM-001-001',
          },
        ],
        'total': 1,
      });

      final page = await repository.fetchPage(pageSize: 20);
      expect(page, hasLength(1));

      final order = page.first;
      expect(order.id, 'MFG-WO-2026-00001');
      expect(order.productionItem, 'ITEM-001');
      expect(order.itemName, 'Шкаф 3-дверный');
      expect(order.qty, 10.0);
      expect(order.producedQty, 4.0);
      expect(order.status, WorkOrderStatus.inProcess);
      expect(order.plannedEndDate, DateTime(2026, 9, 1, 18));
      expect(order.actualEndDate, isNull);
      expect(order.salesOrder, 'SAL-ORD-2026-00001');
      expect(order.originatingDeal, 'SAL-ORD-2026-00001');
      expect(order.bomNo, 'BOM-ITEM-001-001');
      expect(order.progress, 0.4);
    });

    test('numbers passed as strings are parsed as numbers', () async {
      respond({
        'orders': [
          {
            'name': 'MFG-WO-002',
            'qty': '50.5',
            'produced_qty': '25.25',
            'status': 'Completed',
          },
        ],
        'total': 1,
      });

      final page = await repository.fetchPage(pageSize: 20);
      expect(page.first.qty, 50.5);
      expect(page.first.producedQty, 25.25);
      expect(page.first.progress, 0.5);
    });

    test('fetchOne finds order or throws NotFoundFailure', () async {
      respond({
        'orders': [
          {'name': 'MFG-WO-001', 'qty': 5, 'status': 'Draft'},
        ],
        'total': 1,
      });

      final order = await repository.fetchOne('MFG-WO-001');
      expect(order.id, 'MFG-WO-001');

      respond({'orders': <Map<String, dynamic>>[], 'total': 0});
      expect(
        () => repository.fetchOne('MFG-WO-NONEXISTENT'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
