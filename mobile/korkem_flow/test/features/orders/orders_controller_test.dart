import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/orders/application/orders_controller.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:mocktail/mocktail.dart';

class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

SalesOrder _order(
  String name, {
  SalesOrderStatus status = SalesOrderStatus.draft,
}) => SalesOrder(
  name: name,
  customer: 'Customer $name',
  status: status,
  grandTotal: 100000,
);

List<SalesOrder> _orders(int count, {int from = 0}) =>
    List.generate(count, (i) => _order('SAL-ORD-${from + i}'));

void main() {
  late _MockSalesOrderRepository repository;

  setUpAll(() {
    registerFallbackValue(SalesOrderStatus.draft);
  });

  setUp(() {
    repository = _MockSalesOrderRepository();
  });

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [salesOrderRepositoryProvider.overrideWithValue(repository)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  group('initial load', () {
    test(
      'exposes the first page and flags more when the page is full',
      () async {
        when(
          () => repository.fetchPage(
            pageSize: any(named: 'pageSize'),
            offset: any(named: 'offset'),
            status: any(named: 'status'),
            search: any(named: 'search'),
          ),
        ).thenAnswer(
          (_) async => SalesOrdersPage(orders: _orders(20), total: 50),
        );

        final container = containerWith();
        final state = await container.read(ordersControllerProvider.future);

        expect(state.items, hasLength(20));
        expect(state.hasMore, isTrue);
      },
    );

    test('flags hasMore false on a short page', () async {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          offset: any(named: 'offset'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => SalesOrdersPage(orders: _orders(5), total: 5));

      final container = containerWith();
      final state = await container.read(ordersControllerProvider.future);

      expect(state.items, hasLength(5));
      expect(state.hasMore, isFalse);
    });

    test('propagates repository failures', () async {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          offset: any(named: 'offset'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenThrow(const ServerFailure('Database timeout'));

      final container = containerWith();

      expect(
        () => container.read(ordersControllerProvider.future),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('pagination', () {
    test('loadMore appends the next page to the existing items', () async {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer(
        (_) async => SalesOrdersPage(orders: _orders(20), total: 30),
      );

      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          offset: 20,
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer(
        (_) async => SalesOrdersPage(orders: _orders(10, from: 20), total: 30),
      );

      final container = containerWith();
      await container.read(ordersControllerProvider.future);

      await container.read(ordersControllerProvider.notifier).loadMore();

      final state = container.read(ordersControllerProvider).requireValue;
      expect(state.items, hasLength(30));
      expect(state.hasMore, isFalse);
    });
  });

  group('filtering', () {
    test(
      'updating filter resets pagination and fetches with new filter',
      () async {
        when(
          () => repository.fetchPage(
            pageSize: any(named: 'pageSize'),
            status: any(named: 'status'),
            search: any(named: 'search'),
          ),
        ).thenAnswer(
          (_) async => SalesOrdersPage(orders: _orders(20), total: 100),
        );

        final container = containerWith();
        await container.read(ordersControllerProvider.future);

        when(
          () => repository.fetchPage(
            pageSize: any(named: 'pageSize'),
            status: SalesOrderStatus.toDeliverAndBill,
            search: any(named: 'search'),
          ),
        ).thenAnswer(
          (_) async => SalesOrdersPage(
            orders:
                _orders(
                      5,
                    )
                    .map(
                      (o) => _order(
                        o.name,
                        status: SalesOrderStatus.toDeliverAndBill,
                      ),
                    )
                    .toList(),
            total: 5,
          ),
        );

        container
            .read(ordersFilterProvider.notifier)
            .setStatus(SalesOrderStatus.toDeliverAndBill);

        final state = await container.read(ordersControllerProvider.future);
        expect(state.items, hasLength(5));
        expect(state.hasMore, isFalse);
      },
    );
  });
}
