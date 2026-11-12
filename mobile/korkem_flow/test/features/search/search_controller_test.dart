import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/search/application/search_controller.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:mocktail/mocktail.dart';

/// One film and one customer to be found.
class _SomeFilm implements FilmDeptRepository {
  @override
  Future<FilmCatalog> stock() async => FilmCatalog.fromJson(const {
    'films': [
      {
        'item': 'MAT-7',
        'maker': 'JS Group',
        'colour': 'Графит',
        'code': 'GR-1',
      },
    ],
  });

  @override
  Future<List<FilmCustomer>> customers() async => const [
    FilmCustomer(customer: 'CUST-1', name: 'Мебель-ЮГ', phone: '+7 701 555'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The film department has nothing to find here.
class _NoFilm implements FilmDeptRepository {
  @override
  Future<FilmCatalog> stock() async => FilmCatalog.fromJson(const {});

  @override
  Future<List<FilmCustomer>> customers() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

class _MockStockRepository extends Mock implements StockRepository {}

void main() {
  late _MockSalesOrderRepository orders;
  late _MockWorkOrderRepository workOrders;
  late _MockStockRepository stock;
  late ProviderContainer container;

  setUp(() {
    orders = _MockSalesOrderRepository();
    workOrders = _MockWorkOrderRepository();
    stock = _MockStockRepository();

    container = ProviderContainer(
      overrides: [
        salesOrderRepositoryProvider.overrideWithValue(orders),
        workOrderRepositoryProvider.overrideWithValue(workOrders),
        stockRepositoryProvider.overrideWithValue(stock),
        filmDeptRepositoryProvider.overrideWithValue(_NoFilm()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('film and its customers are found by code, name or phone', () async {
    final films = ProviderContainer(
      overrides: [
        salesOrderRepositoryProvider.overrideWithValue(orders),
        workOrderRepositoryProvider.overrideWithValue(workOrders),
        stockRepositoryProvider.overrideWithValue(stock),
        filmDeptRepositoryProvider.overrideWithValue(_SomeFilm()),
      ],
    );
    addTearDown(films.dispose);
    final byCode = await films.read(globalSearchResultsProvider('gr-1').future);
    expect([for (final f in byCode.films.items) f.item], ['MAT-7']);
    final byPhone = await films.read(globalSearchResultsProvider('701').future);
    expect(
      [for (final c in byPhone.filmCustomers.items) c.customer],
      ['CUST-1'],
    );
  });

  test(
    'empty or whitespace query yields empty results without calling '
    'repositories',
    () async {
      final results = await container.read(
        globalSearchResultsProvider('').future,
      );

      expect(results.isEmpty, isTrue);
      expect(results.hasAnyResults, isFalse);
      verifyZeroInteractions(orders);
      verifyZeroInteractions(workOrders);
      verifyZeroInteractions(stock);
    },
  );

  test(
    'queries all three repositories in parallel and aggregates results',
    () async {
      when(
        () => orders.fetchPage(
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        ),
      ).thenAnswer(
        (_) async => const SalesOrdersPage(
          orders: [
            SalesOrder(
              name: 'SAL-ORD-00001',
              customer: 'Мебель Астана',
              status: SalesOrderStatus.draft,
            ),
          ],
          total: 1,
        ),
      );

      when(
        () => workOrders.fetchPage(
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        ),
      ).thenAnswer(
        (_) async => const [
          WorkOrder(
            id: 'MFG-WO-0001',
            status: WorkOrderStatus.inProcess,
            qty: 10,
            itemName: 'Шкаф-купе',
          ),
        ],
      );

      when(
        () => stock.fetchStock(
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        ),
      ).thenAnswer(
        (_) async => const StockPage(
          items: [
            StockPosition(
              itemCode: 'MDF-716-396-WG',
              itemName: 'Фасад МДФ Белый',
              warehouse: 'Склад материалов',
              actualQty: 100,
            ),
          ],
          total: 1,
        ),
      );

      final results = await container.read(
        globalSearchResultsProvider('Мебель').future,
      );

      expect(results.hasAnyResults, isTrue);
      expect(results.orders.items.length, 1);
      expect(results.orders.items.first.name, 'SAL-ORD-00001');
      expect(results.workOrders.items.length, 1);
      expect(results.workOrders.items.first.id, 'MFG-WO-0001');
      expect(results.stock.items.length, 1);
      expect(results.stock.items.first.itemCode, 'MDF-716-396-WG');

      verify(
        () => orders.fetchPage(pageSize: 5, search: 'Мебель'),
      ).called(1);
      verify(
        () => workOrders.fetchPage(pageSize: 5, search: 'Мебель'),
      ).called(1);
      verify(
        () => stock.fetchStock(pageSize: 5, search: 'Мебель'),
      ).called(1);
    },
  );

  test(
    'graceful degradation: one repository failure does not crash others',
    () async {
      when(
        () => orders.fetchPage(
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        ),
      ).thenThrow(const ServerFailure('Orders service unavailable'));

      when(
        () => workOrders.fetchPage(
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        ),
      ).thenAnswer(
        (_) async => const [
          WorkOrder(
            id: 'MFG-WO-0001',
            status: WorkOrderStatus.inProcess,
            qty: 10,
          ),
        ],
      );

      when(
        () => stock.fetchStock(
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        ),
      ).thenAnswer(
        (_) async => const StockPage(
          items: [],
          total: 0,
        ),
      );

      final results = await container.read(
        globalSearchResultsProvider('MDF').future,
      );

      expect(results.orders.hasError, isTrue);
      expect(results.orders.error, isA<ServerFailure>());
      expect(results.workOrders.hasError, isFalse);
      expect(results.workOrders.items.length, 1);
      expect(results.stock.hasError, isFalse);
      expect(results.stock.items, isEmpty);
    },
  );
}
