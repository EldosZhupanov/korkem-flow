import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/orders/data/order_invoice_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_invoice.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/order_invoicing_section.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeOrderInvoiceRepository extends OrderInvoiceRepository {
  _FakeOrderInvoiceRepository({
    required this.initialInvoice,
  }) : currentInvoice = initialInvoice,
       super(dummyClient);

  static final dummyDio = Dio();
  static final dummyClient = FrappeClient(dummyDio);

  final OrderInvoice initialInvoice;
  OrderInvoice currentInvoice;
  int draftCalls = 0;

  @override
  Future<OrderInvoice> fetchInvoice(String salesOrder) async => currentInvoice;

  @override
  Future<Map<String, dynamic>> draftInvoice(String salesOrder) async {
    draftCalls++;
    currentInvoice = OrderInvoice(
      salesOrder: salesOrder,
      name: 'ACC-SINV-2026-00001',
      grandTotal: 1200000,
      status: OrderInvoiceStatus.drafted,
      postingDate: DateTime(2026, 9, 3),
    );
    return {
      'sales_order': salesOrder,
      'invoice': 'ACC-SINV-2026-00001',
      'total': 1200000.0,
      'status': 'drafted',
    };
  }
}

const _draftOrder = SalesOrder(
  name: 'SAL-ORD-00001',
  customer: 'ТОО Мебель Астана',
  status: SalesOrderStatus.draft,
  grandTotal: 1200000,
);

const _undeliveredOrder = SalesOrder(
  name: 'SAL-ORD-00001',
  customer: 'ТОО Мебель Астана',
  status: SalesOrderStatus.toDeliverAndBill,
  grandTotal: 1200000,
);

const _deliveredOrder = SalesOrder(
  name: 'SAL-ORD-00001',
  customer: 'ТОО Мебель Астана',
  status: SalesOrderStatus.toDeliverAndBill,
  grandTotal: 1200000,
  perDelivered: 50,
);

void main() {
  Widget buildHarness({
    required _FakeOrderInvoiceRepository repo,
    required SalesOrder order,
  }) {
    return ProviderScope(
      overrides: [
        orderInvoiceRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderInvoicingSection(order: order),
          ),
        ),
      ),
    );
  }

  testWidgets('explains why invoice cannot be drafted when order is in draft', (
    tester,
  ) async {
    final repo = _FakeOrderInvoiceRepository(
      initialInvoice: const OrderInvoice(salesOrder: 'SAL-ORD-00001'),
    );

    await tester.pumpWidget(buildHarness(repo: repo, order: _draftOrder));
    await tester.pumpAndSettle();

    expect(find.text('Счёт'), findsOneWidget);
    expect(
      find.textContaining('Заказ ещё не проведён'),
      findsOneWidget,
    );
    expect(find.text('Выставить счёт'), findsNothing);
  });

  testWidgets(
    'explains why invoice cannot be drafted when nothing is delivered',
    (tester) async {
      final repo = _FakeOrderInvoiceRepository(
        initialInvoice: const OrderInvoice(salesOrder: 'SAL-ORD-00001'),
      );

      await tester.pumpWidget(
        buildHarness(repo: repo, order: _undeliveredOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Счёт'), findsOneWidget);
      expect(
        find.textContaining('По заказу ничего не отгружено'),
        findsOneWidget,
      );
      expect(find.text('Выставить счёт'), findsNothing);
    },
  );

  testWidgets(
    'allows drafting invoice when items are delivered and displays invoice',
    (tester) async {
      final repo = _FakeOrderInvoiceRepository(
        initialInvoice: const OrderInvoice(salesOrder: 'SAL-ORD-00001'),
      );

      await tester.pumpWidget(
        buildHarness(repo: repo, order: _deliveredOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Счёт'), findsOneWidget);
      expect(find.text('Выставить счёт'), findsOneWidget);

      await tester.tap(find.text('Выставить счёт'));
      await tester.pumpAndSettle();

      expect(repo.draftCalls, 1);
      expect(find.text('Выставлен'), findsOneWidget);
      expect(find.text('Номер счёта: ACC-SINV-2026-00001'), findsOneWidget);
      expect(find.textContaining('Сумма счёта:'), findsOneWidget);
      // Ensure the button is replaced, not offered a second time
      expect(find.text('Выставить счёт'), findsNothing);
    },
  );

  testWidgets(
    'shows existing invoice without offering a second draft action',
    (tester) async {
      final repo = _FakeOrderInvoiceRepository(
        initialInvoice: OrderInvoice(
          salesOrder: 'SAL-ORD-00001',
          name: 'ACC-SINV-2026-00001',
          grandTotal: 1200000,
          status: OrderInvoiceStatus.drafted,
          postingDate: DateTime(2026, 9, 3),
        ),
      );

      await tester.pumpWidget(
        buildHarness(repo: repo, order: _deliveredOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Счёт'), findsOneWidget);
      expect(find.text('Выставлен'), findsOneWidget);
      expect(find.text('Номер счёта: ACC-SINV-2026-00001'), findsOneWidget);
      expect(find.textContaining('Сумма счёта:'), findsOneWidget);
      expect(find.text('Выставить счёт'), findsNothing);
    },
  );
}
