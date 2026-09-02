import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/orders/data/order_design_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_design.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/order_design_section.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeOrderDesignRepository extends OrderDesignRepository {
  _FakeOrderDesignRepository({
    required this.initialDesign,
  }) : currentDesign = initialDesign,
       super(dummyClient, dummyDio);

  static final dummyDio = Dio();
  static final dummyClient = FrappeClient(dummyDio);

  final OrderDesign initialDesign;
  OrderDesign currentDesign;
  int assignCalls = 0;
  int deliverCalls = 0;
  int attachCalls = 0;

  @override
  Future<OrderDesign> fetchDesign(String salesOrder) async => currentDesign;

  @override
  Future<Map<String, dynamic>> assignDesign({
    required String salesOrder,
    required String designer,
    required String dueOn,
  }) async {
    assignCalls++;
    currentDesign = OrderDesign(
      salesOrder: salesOrder,
      taskId: 'TASK-100',
      designer: designer,
      dueDate: DateTime.tryParse(dueOn),
      status: OrderDesignStatus.assigned,
      attachments: currentDesign.attachments,
    );
    return {'status': 'assigned', 'task': 'TASK-100'};
  }

  @override
  Future<Map<String, dynamic>> deliverDesign({
    required String salesOrder,
  }) async {
    deliverCalls++;
    if (currentDesign.attachments.isEmpty) {
      throw const ServerFailure(
        'К заказу не приложено ни одного файла. Дизайн считается готовым, '
        'когда чертёж есть, а не когда о нём сказали.',
      );
    }
    currentDesign = OrderDesign(
      salesOrder: salesOrder,
      taskId: currentDesign.taskId,
      designer: currentDesign.designer,
      dueDate: currentDesign.dueDate,
      status: OrderDesignStatus.delivered,
      attachments: currentDesign.attachments,
    );
    return {'status': 'delivered', 'task_closed': currentDesign.taskId};
  }

  @override
  Future<OrderDesignAttachment> attachFile({
    required String salesOrder,
    required String fileName,
    String? fileUrl,
    String? content,
  }) async {
    attachCalls++;
    final att = OrderDesignAttachment(
      name: 'FILE-${DateTime.now().millisecondsSinceEpoch}',
      fileName: fileName,
      fileUrl: fileUrl,
    );
    currentDesign = OrderDesign(
      salesOrder: salesOrder,
      taskId: currentDesign.taskId,
      designer: currentDesign.designer,
      dueDate: currentDesign.dueDate,
      status: currentDesign.status,
      attachments: [...currentDesign.attachments, att],
    );
    return att;
  }
}

const _testOrder = SalesOrder(
  name: 'SAL-ORD-00001',
  customer: 'ТОО Мебель Астана',
  status: SalesOrderStatus.toDeliverAndBill,
  grandTotal: 450000,
);

void main() {
  Widget buildHarness({
    required _FakeOrderDesignRepository repo,
    DateTime? clockDate,
  }) {
    return ProviderScope(
      overrides: [
        orderDesignRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(
          () => clockDate ?? DateTime(2026, 9, 3, 12),
        ),
        teamMembersProvider.overrideWith(
          (ref) async => const [
            TeamMember(
              email: 'designer@korkem.kz',
              firstName: 'Айгерим',
              fullName: 'Айгерим Дизайнер',
              position: EmployeePosition.shopFloor,
              roles: ['Design User'],
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
        home: const Scaffold(
          body: SingleChildScrollView(
            child: OrderDesignSection(order: _testOrder),
          ),
        ),
      ),
    );
  }

  testWidgets('renders notAssigned state and assigns design to a designer', (
    tester,
  ) async {
    final repo = _FakeOrderDesignRepository(
      initialDesign: const OrderDesign(salesOrder: 'SAL-ORD-00001'),
    );

    await tester.pumpWidget(buildHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Дизайн и чертежи'), findsOneWidget);
    expect(find.text('Не поручен'), findsOneWidget);
    expect(find.text('Поручить дизайн'), findsOneWidget);

    // Tap "Поручить дизайн"
    await tester.tap(find.text('Поручить дизайн'));
    await tester.pumpAndSettle();

    // Select date
    await tester.tap(find.text('Выбрать дату'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();

    // Confirm assign
    await tester.tap(find.text('Поручить дизайн'));
    await tester.pumpAndSettle();

    expect(repo.assignCalls, 1);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.textContaining('designer@korkem.kz'), findsOneWidget);
  });

  testWidgets(
    'shows overdue badge when deadline has passed and warns of no files',
    (
      tester,
    ) async {
      final repo = _FakeOrderDesignRepository(
        initialDesign: OrderDesign(
          salesOrder: 'SAL-ORD-00001',
          taskId: 'TASK-001',
          designer: 'designer@korkem.kz',
          dueDate: DateTime(2026, 8, 30),
          status: OrderDesignStatus.assigned,
        ),
      );

      await tester.pumpWidget(
        buildHarness(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Просрочен'), findsOneWidget);
      expect(find.textContaining('Ожидается чертёж'), findsOneWidget);
    },
  );

  testWidgets(
    'shows server refusal message when deliver is pressed without files',
    (
      tester,
    ) async {
      final repo = _FakeOrderDesignRepository(
        initialDesign: OrderDesign(
          salesOrder: 'SAL-ORD-00001',
          taskId: 'TASK-001',
          designer: 'designer@korkem.kz',
          dueDate: DateTime(2026, 9, 10),
          status: OrderDesignStatus.assigned,
        ),
      );

      await tester.pumpWidget(buildHarness(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Принять дизайн'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('К заказу не приложено ни одного файла'),
        findsOneWidget,
      );
    },
  );

  testWidgets('attaches drawing and accepts design successfully', (
    tester,
  ) async {
    final repo = _FakeOrderDesignRepository(
      initialDesign: OrderDesign(
        salesOrder: 'SAL-ORD-00001',
        taskId: 'TASK-001',
        designer: 'designer@korkem.kz',
        dueDate: DateTime(2026, 9, 10),
        status: OrderDesignStatus.assigned,
      ),
    );

    await tester.pumpWidget(buildHarness(repo: repo));
    await tester.pumpAndSettle();

    // Tap "Приложить чертёж"
    await tester.tap(find.text('Приложить чертёж'));
    await tester.pumpAndSettle();

    expect(find.text('Прикрепить чертёж к заказу'), findsOneWidget);
    await tester.tap(find.text('Прикрепить файл'));
    await tester.pumpAndSettle();

    expect(repo.attachCalls, 1);
    expect(find.text('чертёж_SAL-ORD-00001.dxf'), findsOneWidget);

    // Now deliver design
    await tester.tap(find.text('Принять дизайн'));
    await tester.pumpAndSettle();

    expect(repo.deliverCalls, 1);
    expect(find.text('Принят'), findsOneWidget);
    expect(find.text('Дизайн принят, чертежи проверены'), findsOneWidget);
  });
}
