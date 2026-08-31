import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late StockRepository repository;

  setUp(() {
    client = _MockClient();
    repository = StockRepository(client);
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

  group('fetching stock reaches the query endpoint', () {
    test('it calls the dedicated query method, not /api/resource/', () async {
      respond({'items': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchStock();

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                ),
              ).captured.single
              as String;

      expect(path, 'korkem_manufacturing.api.queries.stock');
    });

    test('it never sends a company argument', () async {
      // Company scope is resolved server-side from session.
      respond({'items': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchStock();

      final params = sentParams();
      expect(params.containsKey('company'), isFalse);
      expect(params.containsKey('organization'), isFalse);
    });

    test('it sends pagination parameters', () async {
      respond({'items': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchStock(pageSize: 25, offset: 50);

      final params = sentParams();
      expect(params['limit'], 25);
      expect(params['offset'], 50);
    });

    test('it sends warehouse filter when present', () async {
      respond({'items': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchStock(warehouse: 'Склад материалов - К');

      final params = sentParams();
      expect(params['warehouse'], 'Склад материалов - К');
    });

    test('it trims and sends search query when present', () async {
      respond({'items': <Map<String, dynamic>>[], 'total': 0});

      await repository.fetchStock(search: '  ЛДСП 18мм  ');

      final params = sentParams();
      expect(params['search'], 'ЛДСП 18мм');
    });
  });

  group('stock response parsing', () {
    test('parses items according to contract', () async {
      respond({
        'items': [
          {
            'item_code': 'MAT-001',
            'item_name': 'ДСП 16мм Дуб Сонома',
            'warehouse': 'Склад материалов - К',
            'actual_qty': 45.0,
            'reserved_qty': 10.0,
            'projected_qty': 35.0,
            'stock_uom': 'Лист',
          },
        ],
        'total': 1,
      });

      final page = await repository.fetchStock();
      expect(page.total, 1);
      expect(page.items, hasLength(1));

      final item = page.items.first;
      expect(item.itemCode, 'MAT-001');
      expect(item.itemName, 'ДСП 16мм Дуб Сонома');
      expect(item.warehouse, 'Склад материалов - К');
      expect(item.actualQty, 45.0);
      expect(item.reservedQty, 10.0);
      expect(item.projectedQty, 35.0);
      expect(item.stockUom, 'Лист');
    });

    test('numbers passed as strings are parsed as numbers', () async {
      respond({
        'items': [
          {
            'item_code': 'MAT-002',
            'warehouse': 'Склад',
            'actual_qty': '100.5',
            'reserved_qty': '20.25',
            'projected_qty': '80.25',
          },
        ],
        'total': 1,
      });

      final page = await repository.fetchStock();
      final item = page.items.first;
      expect(item.actualQty, 100.5);
      expect(item.reservedQty, 20.25);
      expect(item.projectedQty, 80.25);
    });

    test('fetchBalances returns balances for specific item code', () async {
      respond({
        'items': [
          {
            'item_code': 'MAT-001',
            'warehouse': 'Склад 1',
            'actual_qty': 30.0,
            'reserved_qty': 5.0,
            'projected_qty': 25.0,
            'stock_uom': 'Шт',
          },
          {
            'item_code': 'MAT-002',
            'warehouse': 'Склад 2',
            'actual_qty': 10.0,
            'reserved_qty': 0.0,
            'projected_qty': 10.0,
            'stock_uom': 'Шт',
          },
        ],
        'total': 2,
      });

      final balances = await repository.fetchBalances('MAT-001');
      expect(balances, hasLength(1));
      expect(balances.first.warehouse, 'Склад 1');
      expect(balances.first.actualQty, 30.0);
      expect(balances.first.availableQty, 25.0);
    });
  });

  group('error propagation', () {
    test('permission error surfaces as PermissionFailure', () async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: any(named: 'post'),
        ),
      ).thenThrow(const PermissionFailure('No access to stock'));

      expect(
        () => repository.fetchStock(),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });
}
