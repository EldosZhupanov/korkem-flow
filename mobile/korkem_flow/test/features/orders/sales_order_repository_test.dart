import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late SalesOrderRepository repository;

  setUp(() {
    client = _MockClient();
    repository = SalesOrderRepository(client);
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

  group('fetching sales orders reaches the query endpoint', () {
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

      expect(
        path,
        'korkem_manufacturing.api.queries.sales_orders',
      );
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
      expect(params['offset'], 30);
      expect(params['limit'], 15);
    });

    test('it sends status filter when present', () async {
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(
        pageSize: 20,
        status: SalesOrderStatus.toDeliverAndBill,
      );

      final params = sentParams();
      expect(params['status'], 'To Deliver and Bill');
    });

    test('it trims and sends search query when present', () async {
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(pageSize: 20, search: '  Мебель Групп  ');

      final params = sentParams();
      expect(params['search'], 'Мебель Групп');
    });

    test('an empty or whitespace search is not sent', () async {
      respond({'orders': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchPage(pageSize: 20, search: '   ');

      final params = sentParams();
      expect(params.containsKey('search'), isFalse);
    });
  });

  group('sales orders response parsing', () {
    test('parses order list and total count', () async {
      respond({
        'orders': [
          {
            'name': 'SAL-ORD-2026-00001',
            'customer': 'ТОО Мебель Групп',
            'status': 'To Deliver and Bill',
            'transaction_date': '2026-08-31',
            'delivery_date': '2026-09-10',
            'grand_total': 1500000.0,
            'per_delivered': 50.0,
          },
          {
            'name': 'SAL-ORD-2026-00002',
            'customer': 'ИП Сапаров',
            'status': 'Draft',
            'transaction_date': '2026-08-30',
            'delivery_date': null,
            'grand_total': 350000,
            'per_delivered': 0,
          },
        ],
        'total': 42,
      });

      final page = await repository.fetchPage(pageSize: 20);

      expect(page.total, 42);
      expect(page.orders, hasLength(2));

      final first = page.orders[0];
      expect(first.name, 'SAL-ORD-2026-00001');
      expect(first.customer, 'ТОО Мебель Групп');
      expect(first.status, SalesOrderStatus.toDeliverAndBill);
      expect(first.transactionDate, DateTime(2026, 8, 31));
      expect(first.deliveryDate, DateTime(2026, 9, 10));
      expect(first.grandTotal, 1500000.0);
      expect(first.perDelivered, 50.0);
      expect(first.deliveryProgress, 0.5);

      final second = page.orders[1];
      expect(second.name, 'SAL-ORD-2026-00002');
      expect(second.customer, 'ИП Сапаров');
      expect(second.status, SalesOrderStatus.draft);
      expect(second.transactionDate, DateTime(2026, 8, 30));
      expect(second.deliveryDate, isNull);
      expect(second.grandTotal, 350000.0);
      expect(second.perDelivered, 0.0);
      expect(second.deliveryProgress, 0.0);
    });

    test('numbers passed as strings are correctly parsed', () async {
      respond({
        'orders': [
          {
            'name': 'SAL-ORD-001',
            'customer': 'Клиент',
            'status': 'Completed',
            'grand_total': '125000.50',
            'per_delivered': '100.0',
          },
        ],
        'total': 1,
      });

      final page = await repository.fetchPage(pageSize: 20);
      expect(page.orders.single.grandTotal, 125000.50);
      expect(page.orders.single.perDelivered, 100.0);
      expect(page.orders.single.isDelivered, isTrue);
    });

    test('empty or malformed payload returns safe defaults', () async {
      respond({});

      final page = await repository.fetchPage(pageSize: 20);
      expect(page.orders, isEmpty);
      expect(page.total, 0);
    });
  });

  group('fetching deliveries reaches dedicated query endpoint', () {
    test('it calls korkem_manufacturing.api.queries.deliveries', () async {
      respond({
        'deliveries': [
          {
            'name': 'MAT-DN-2026-00001',
            'posting_date': '2026-09-01',
            'status': 'Submitted',
            'grand_total': 150000.0,
            'items': [
              {
                'item_code': 'MDF-716-396-WG',
                'item_name': 'Фасад МДФ Белый',
                'qty': 5.0,
                'uom': 'Шт',
              },
            ],
          },
        ],
        'total': 1,
      });

      final deliveries = await repository.fetchDeliveries('SAL-ORD-00001');

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                ),
              ).captured.single
              as String;

      expect(path, 'korkem_manufacturing.api.queries.deliveries');
      expect(deliveries, hasLength(1));
      expect(deliveries.single.name, 'MAT-DN-2026-00001');
      expect(deliveries.single.items.single.itemCode, 'MDF-716-396-WG');
    });

    test('empty deliveries payload returns empty list', () async {
      respond({'deliveries': <Map<String, dynamic>>[], 'total': 0});

      final deliveries = await repository.fetchDeliveries('SAL-ORD-00002');
      expect(deliveries, isEmpty);
    });
  });
}
