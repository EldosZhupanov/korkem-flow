import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/orders/data/order_warranty_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_warranty.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/order_warranty_section.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeOrderWarrantyRepository extends OrderWarrantyRepository {
  _FakeOrderWarrantyRepository({
    required this.initialWarranty,
    this.claimException,
  }) : currentWarranty = initialWarranty,
       super(dummyClient);

  static final dummyDio = Dio();
  static final dummyClient = FrappeClient(dummyDio);

  final OrderWarranty initialWarranty;
  final FrappeException? claimException;
  OrderWarranty currentWarranty;
  int claimCalls = 0;
  String? lastItemCode;
  String? lastComplaint;

  @override
  Future<OrderWarranty> fetchWarranty(String salesOrder) async =>
      currentWarranty;

  @override
  Future<Map<String, dynamic>> claimWarranty({
    required String salesOrder,
    required String itemCode,
    required String complaint,
  }) async {
    claimCalls++;
    lastItemCode = itemCode;
    lastComplaint = complaint;
    if (claimException != null) {
      throw claimException!;
    }
    return {
      'sales_order': salesOrder,
      'claim': 'WAR-CLM-2026-0001',
      'item_code': itemCode,
      'warranty_until': '2027-08-20',
      'status': 'accepted',
    };
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
    required _FakeOrderWarrantyRepository repo,
    SalesOrder order = _testOrder,
  }) {
    return ProviderScope(
      overrides: [
        orderWarrantyRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderWarrantySection(order: order),
          ),
        ),
      ),
    );
  }

  testWidgets('shows informational notice when order has not been shipped', (
    tester,
  ) async {
    final repo = _FakeOrderWarrantyRepository(
      initialWarranty: const OrderWarranty(
        salesOrder: 'SAL-ORD-00001',
      ),
    );

    await tester.pumpWidget(buildHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Гарантия'), findsOneWidget);
    expect(find.text('Гарантия начнётся после отгрузки.'), findsOneWidget);
    expect(find.text('Оформить рекламацию'), findsNothing);
  });

  testWidgets('shows shipped date, item warranty duration and active status', (
    tester,
  ) async {
    final repo = _FakeOrderWarrantyRepository(
      initialWarranty: OrderWarranty(
        salesOrder: 'SAL-ORD-00001',
        shippedOn: DateTime(2026, 8, 20),
        items: [
          OrderWarrantyItem(
            itemCode: 'KITCHEN-MOD-01',
            itemName: 'Кухонный гарнитур',
            days: 365,
            until: DateTime(2027, 8, 20),
            active: true,
          ),
          OrderWarrantyItem(
            itemCode: 'FITTING-01',
            itemName: 'Петли доводчики',
            days: 10,
            until: DateTime(2026, 8, 30),
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Гарантия'), findsOneWidget);
    expect(find.textContaining('Отгружено:'), findsOneWidget);
    expect(find.text('Кухонный гарнитур'), findsOneWidget);
    expect(find.textContaining('365 дн.'), findsOneWidget);
    expect(find.text('Действует'), findsNWidgets(2)); // header chip + item chip
    expect(find.text('Петли доводчики'), findsOneWidget);
    expect(find.textContaining('10 дн.'), findsOneWidget);
    expect(find.text('Закончилась'), findsOneWidget);
    expect(find.text('Оформить рекламацию'), findsOneWidget);
  });

  testWidgets('files a warranty claim with complaint description', (
    tester,
  ) async {
    final repo = _FakeOrderWarrantyRepository(
      initialWarranty: OrderWarranty(
        salesOrder: 'SAL-ORD-00001',
        shippedOn: DateTime(2026, 8, 20),
        items: [
          OrderWarrantyItem(
            itemCode: 'KITCHEN-MOD-01',
            itemName: 'Кухонный гарнитур',
            days: 365,
            until: DateTime(2027, 8, 20),
            active: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildHarness(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Оформить рекламацию'));
    await tester.pumpAndSettle();

    expect(find.text('Оформление рекламации'), findsOneWidget);

    // Try submit empty
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Оформить рекламацию'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Опишите причину рекламации'), findsOneWidget);

    // Fill complaint description
    await tester.enterText(
      find.byType(TextFormField),
      'Отслоилась кромка на нижнем фасаде',
    );
    await tester.pumpAndSettle();

    // Submit claim
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Оформить рекламацию'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.claimCalls, 1);
    expect(repo.lastItemCode, 'KITCHEN-MOD-01');
    expect(repo.lastComplaint, 'Отслоилась кромка на нижнем фасаде');
    expect(
      find.textContaining(
        'Рекламация WAR-CLM-2026-0001 успешно зарегистрирована',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows server refusal message in full words when warranty expired',
    (tester) async {
      final repo = _FakeOrderWarrantyRepository(
        initialWarranty: OrderWarranty(
          salesOrder: 'SAL-ORD-00001',
          shippedOn: DateTime(2026, 8, 20),
          items: [
            OrderWarrantyItem(
              itemCode: 'FITTING-01',
              itemName: 'Петли доводчики',
              days: 5,
              until: DateTime(2026, 8, 25),
            ),
          ],
        ),
        claimException: const ValidationFailure(
          'Гарантия по этой позиции закончилась 2026-08-25.',
        ),
      );

      await tester.pumpWidget(buildHarness(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Оформить рекламацию'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'Сломалась петля',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Оформить рекламацию'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Гарантия по этой позиции закончилась 2026-08-25.'),
        findsOneWidget,
      );
    },
  );
}
