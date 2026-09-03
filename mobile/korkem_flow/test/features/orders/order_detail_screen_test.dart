import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/orders/data/order_design_repository.dart';
import 'package:korkem_flow/features/orders/data/order_installation_repository.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/delivery_note.dart';
import 'package:korkem_flow/features/orders/domain/order_design.dart';
import 'package:korkem_flow/features/orders/domain/order_installation.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/order_detail_screen.dart';
import 'package:korkem_flow/features/orders/presentation/start_production_button.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/widget_harness.dart';

class _MockSalesOrderRepository extends Mock implements SalesOrderRepository {}

class _MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

class _MockProductionCommandRepository extends Mock
    implements ProductionCommandRepository {}

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

class _MockOrderDesignRepository extends Mock
    implements OrderDesignRepository {}

class _MockOrderInstallationRepository extends Mock
    implements OrderInstallationRepository {}

const _order = SalesOrder(
  name: 'SAL-ORD-00001',
  customer: 'Мебель Астана',
  status: SalesOrderStatus.toDeliverAndBill,
  grandTotal: 450000,
  perDelivered: 25,
);

void main() {
  late _MockSalesOrderRepository orders;
  late _MockWorkOrderRepository workOrders;
  late _MockProductionCommandRepository commands;
  late _MockReceivingRepository receivingRepo;
  late _MockOrderDesignRepository designRepo;
  late _MockOrderInstallationRepository installationRepo;

  setUp(() {
    orders = _MockSalesOrderRepository();
    workOrders = _MockWorkOrderRepository();
    commands = _MockProductionCommandRepository();
    receivingRepo = _MockReceivingRepository();
    designRepo = _MockOrderDesignRepository();
    installationRepo = _MockOrderInstallationRepository();
  });

  void stubOrder({
    List<SalesOrder> found = const [_order],
    List<SalesOrderDelivery> deliveries = const [],
    OrderDesign? design,
    OrderInstallation? installation,
  }) {
    when(
      () => orders.fetchPage(
        pageSize: any(named: 'pageSize'),
        search: any(named: 'search'),
      ),
    ).thenAnswer(
      (_) async => SalesOrdersPage(orders: found, total: found.length),
    );
    when(
      () => orders.fetchDeliveries(any()),
    ).thenAnswer((_) async => deliveries);
    when(
      () => designRepo.fetchDesign(any()),
    ).thenAnswer(
      (_) async =>
          design ??
          const OrderDesign(
            salesOrder: 'SAL-ORD-00001',
          ),
    );
    when(
      () => installationRepo.fetchInstallation(any()),
    ).thenAnswer(
      (_) async =>
          installation ??
          const OrderInstallation(
            salesOrder: 'SAL-ORD-00001',
          ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    List<WorkOrder> jobs = const [],
  }) async {
    when(() => workOrders.fetchForDeal(any())).thenAnswer((_) async => jobs);

    await tester.pumpWidget(
      ProviderScope(
        // Riverpod 3 retries a failed provider with backoff, so without this a
        // failure never settles into `AsyncError` and the test waits forever.
        retry: (_, _) => null,
        overrides: [
          salesOrderRepositoryProvider.overrideWithValue(orders),
          orderDesignRepositoryProvider.overrideWithValue(designRepo),
          orderInstallationRepositoryProvider.overrideWithValue(
            installationRepo,
          ),
          workOrderRepositoryProvider.overrideWithValue(workOrders),
          productionCommandRepositoryProvider.overrideWithValue(commands),
          receivingRepositoryProvider.overrideWithValue(receivingRepo),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 1, 12)),
        ],
        child: harness(const OrderDetailScreen(name: 'SAL-ORD-00001')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the order and the jobs raised for it', (tester) async {
    stubOrder();
    await pump(
      tester,
      jobs: const [
        WorkOrder(
          id: 'MFG-WO-0001',
          status: WorkOrderStatus.inProcess,
          qty: 10,
          producedQty: 4,
          itemName: 'Шкаф-купе',
          salesOrder: 'SAL-ORD-00001',
        ),
      ],
    );

    expect(find.text('Мебель Астана'), findsOneWidget);
    expect(find.text('Шкаф-купе'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
  });

  testWidgets('says production has not started instead of showing nothing', (
    tester,
  ) async {
    stubOrder();
    await pump(tester);

    expect(find.text('Production has not started'), findsOneWidget);
    expect(find.byType(StartProductionButton), findsOneWidget);
  });

  testWidgets('a job belonging to another order is not shown here', (
    tester,
  ) async {
    // `fetchForDeal` searches, and a search matches more than it should.
    stubOrder();
    await pump(
      tester,
      jobs: const [
        WorkOrder(
          id: 'MFG-WO-0002',
          status: WorkOrderStatus.inProcess,
          qty: 5,
          itemName: 'Чужая тумба',
          salesOrder: 'SAL-ORD-00099',
        ),
      ],
    );

    expect(find.text('Чужая тумба'), findsNothing);
    expect(find.text('Production has not started'), findsOneWidget);
  });

  testWidgets('a near-miss name is not shown as the order', (tester) async {
    // A search for SAL-ORD-00001 also matches SAL-ORD-000011. Showing the
    // wrong order confidently is worse than saying it was not found.
    stubOrder(
      found: const [
        SalesOrder(
          name: 'SAL-ORD-000011',
          customer: 'Другой заказчик',
          status: SalesOrderStatus.toDeliverAndBill,
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Другой заказчик'), findsNothing);
  });

  testWidgets('the server refusal is shown in full, with the materials', (
    tester,
  ) async {
    stubOrder();
    when(() => commands.start(any())).thenAnswer(
      (_) async => const StartProductionResult(
        status: 'blocked',
        message: 'Не хватает материала на складе',
        blockingMaterials: [
          BlockingMaterial(itemCode: 'ЛДСП-16-БЕЛ', shortageQty: 12, uom: 'шт'),
        ],
      ),
    );
    await pump(tester);

    // The 800x600 test viewport puts the button below the fold.
    await tester.ensureVisible(find.byType(StartProductionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(StartProductionButton));
    // Not `pumpAndSettle`: the refusal also raises a snack bar, and waiting
    // for that to expire outlasts the settle timeout. The dialog is what this
    // test is about, and it is up after one frame plus its own animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Not "Ошибка": the reason the server gave, and the shortage behind it.
    expect(find.text('Не хватает материала на складе'), findsOneWidget);
    expect(find.textContaining('ЛДСП-16-БЕЛ'), findsOneWidget);
  });

  testWidgets('shows empty view when no deliveries exist', (tester) async {
    stubOrder();
    await pump(tester);

    expect(
      find.text('DELIVERIES', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('No shipments yet', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('shows deliveries cards when shipments exist', (tester) async {
    stubOrder(
      deliveries: const [
        SalesOrderDelivery(
          name: 'MAT-DN-2026-00001',
          status: 'Submitted',
          grandTotal: 150000,
          items: [
            SalesOrderDeliveryItem(
              itemCode: 'MDF-716-396-WG',
              itemName: 'Фасад МДФ Белый',
              qty: 5,
              uom: 'Шт',
            ),
          ],
        ),
      ],
    );
    await pump(tester);

    expect(
      find.text('DELIVERIES', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('MAT-DN-2026-00001', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Submitted', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('Фасад МДФ Белый', skipOffstage: false),
      findsOneWidget,
    );
  });
}
