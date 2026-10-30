import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/orders/data/order_installation_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_installation.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/order_installation_section.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeOrderInstallationRepository extends OrderInstallationRepository {
  _FakeOrderInstallationRepository({
    required this.initialInstallation,
  }) : currentInstallation = initialInstallation,
       super(dummyClient);

  static final dummyDio = Dio();
  static final dummyClient = FrappeClient(dummyDio);

  final OrderInstallation initialInstallation;
  OrderInstallation currentInstallation;
  int scheduleCalls = 0;
  int completeCalls = 0;
  String? lastNotes;

  @override
  Future<OrderInstallation> fetchInstallation(String salesOrder) async =>
      currentInstallation;

  @override
  Future<Map<String, dynamic>> scheduleInstallation({
    required String salesOrder,
    required String installer,
    required String installOn,
  }) async {
    scheduleCalls++;
    currentInstallation = OrderInstallation(
      salesOrder: salesOrder,
      taskId: 'TASK-INSTALL-100',
      installer: installer,
      installDate: DateTime.tryParse(installOn),
      status: OrderInstallationStatus.scheduled,
      notes: currentInstallation.notes,
    );
    return {'status': 'scheduled', 'task': 'TASK-INSTALL-100'};
  }

  @override
  Future<Map<String, dynamic>> completeInstallation({
    required String salesOrder,
    String? notes,
  }) async {
    completeCalls++;
    lastNotes = notes;
    currentInstallation = OrderInstallation(
      salesOrder: salesOrder,
      taskId: currentInstallation.taskId,
      installer: currentInstallation.installer,
      installDate: currentInstallation.installDate,
      status: OrderInstallationStatus.completed,
      notes: notes,
    );
    return {'status': 'completed', 'task_closed': currentInstallation.taskId};
  }
}

const _undeliveredOrder = SalesOrder(
  name: 'SAL-ORD-00001',
  customer: 'ТОО Мебель Астана',
  status: SalesOrderStatus.toDeliverAndBill,
  grandTotal: 450000,
);

const _deliveredOrder = SalesOrder(
  name: 'SAL-ORD-00001',
  customer: 'ТОО Мебель Астана',
  status: SalesOrderStatus.toDeliverAndBill,
  grandTotal: 450000,
  perDelivered: 50,
);

void main() {
  Widget buildHarness({
    required _FakeOrderInstallationRepository repo,
    required SalesOrder order,
    DateTime? clockDate,
  }) {
    return ProviderScope(
      overrides: [
        orderInstallationRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(
          () => clockDate ?? DateTime(2026, 9, 3, 12),
        ),
        teamMembersProvider.overrideWith(
          (ref) async => const [
            TeamMember(
              email: 'installer@korkem.kz',
              firstName: 'Марат',
              fullName: 'Марат Монтажник',
              position: EmployeePosition.shopFloor,
              roles: ['Manufacturing User'],
              enabled: true,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderInstallationSection(order: order),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'explains that delivery must come first when order has no shipments',
    (tester) async {
      final repo = _FakeOrderInstallationRepository(
        initialInstallation: const OrderInstallation(
          salesOrder: 'SAL-ORD-00001',
        ),
      );

      await tester.pumpWidget(
        buildHarness(repo: repo, order: _undeliveredOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Монтаж'), findsOneWidget);
      expect(find.text('Не назначен'), findsOneWidget);
      expect(
        find.textContaining('Сначала отгрузка, потом монтаж'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Бригада, приехавшая к клиенту без мебели'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'allows scheduling installation when items are delivered',
    (tester) async {
      final repo = _FakeOrderInstallationRepository(
        initialInstallation: const OrderInstallation(
          salesOrder: 'SAL-ORD-00001',
        ),
      );

      await tester.pumpWidget(
        buildHarness(repo: repo, order: _deliveredOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Монтаж'), findsOneWidget);
      expect(find.text('Назначить монтаж'), findsOneWidget);

      await tester.tap(find.text('Назначить монтаж'));
      await tester.pumpAndSettle();

      // Pick date
      await tester.tap(find.text('Выбрать дату'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Назначить монтаж'));
      await tester.pumpAndSettle();

      expect(repo.scheduleCalls, 1);
      expect(find.text('Назначен'), findsOneWidget);
      expect(find.textContaining('installer@korkem.kz'), findsOneWidget);
    },
  );

  testWidgets('shows overdue badge when installation date has passed', (
    tester,
  ) async {
    final repo = _FakeOrderInstallationRepository(
      initialInstallation: OrderInstallation(
        salesOrder: 'SAL-ORD-00001',
        taskId: 'TASK-001',
        installer: 'installer@korkem.kz',
        installDate: DateTime(2026, 8, 30),
        status: OrderInstallationStatus.scheduled,
      ),
    );

    await tester.pumpWidget(
      buildHarness(repo: repo, order: _deliveredOrder),
    );
    await tester.pumpAndSettle();

    expect(find.text('Просрочен'), findsOneWidget);
    expect(find.text('Монтаж выполнен'), findsOneWidget);
  });

  testWidgets(
    'completes installation with crew notes and shows them on order',
    (tester) async {
      final repo = _FakeOrderInstallationRepository(
        initialInstallation: OrderInstallation(
          salesOrder: 'SAL-ORD-00001',
          taskId: 'TASK-001',
          installer: 'installer@korkem.kz',
          installDate: DateTime(2026, 9, 10),
          status: OrderInstallationStatus.scheduled,
        ),
      );

      await tester.pumpWidget(
        buildHarness(repo: repo, order: _deliveredOrder),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Монтаж выполнен'));
      await tester.pumpAndSettle();

      expect(find.text('Завершение монтажа'), findsOneWidget);

      // Enter crew notes
      await tester.enterText(
        find.byType(TextFormField),
        'стена оказалась кривой, ставили с доборным элементом',
      );
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.completeCalls, 1);
      expect(
        repo.lastNotes,
        'стена оказалась кривой, ставили с доборным элементом',
      );
      expect(find.text('Выполнен'), findsOneWidget);
      expect(find.text('Монтаж успешно завершён'), findsOneWidget);
      expect(
        find.text('стена оказалась кривой, ставили с доборным элементом'),
        findsOneWidget,
      );
    },
  );
}
