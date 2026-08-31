import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';

void main() {
  group('SalesOrder entity', () {
    test('fromJson correctly maps valid json', () {
      final order = SalesOrder.fromJson(const {
        'name': 'SAL-ORD-2026-00001',
        'customer': 'ТОО Мебель',
        'status': 'To Deliver and Bill',
        'transaction_date': '2026-08-31',
        'delivery_date': '2026-09-10',
        'grand_total': 1500000.0,
        'per_delivered': 25.0,
      });

      expect(order.name, 'SAL-ORD-2026-00001');
      expect(order.customer, 'ТОО Мебель');
      expect(order.status, SalesOrderStatus.toDeliverAndBill);
      expect(order.transactionDate, DateTime(2026, 8, 31));
      expect(order.deliveryDate, DateTime(2026, 9, 10));
      expect(order.grandTotal, 1500000.0);
      expect(order.perDelivered, 25.0);
      expect(order.deliveryProgress, 0.25);
      expect(order.isDelivered, isFalse);
    });

    test('isLateAt detects overdue orders accurately', () {
      final order = SalesOrder(
        name: 'SAL-ORD-001',
        customer: 'Клиент',
        status: SalesOrderStatus.toDeliver,
        deliveryDate: DateTime(2026, 8, 30),
      );

      expect(order.isLateAt(DateTime(2026, 8, 29)), isFalse);
      expect(order.isLateAt(DateTime(2026, 8, 31)), isTrue);
    });

    test('completed order is never late', () {
      final order = SalesOrder(
        name: 'SAL-ORD-001',
        customer: 'Клиент',
        status: SalesOrderStatus.completed,
        deliveryDate: DateTime(2026, 8, 20),
      );

      expect(order.isLateAt(DateTime(2026, 8, 31)), isFalse);
    });

    test('equality and hashCode are based on name', () {
      const order1 = SalesOrder(
        name: 'SAL-ORD-001',
        customer: 'Клиент 1',
        status: SalesOrderStatus.draft,
      );
      const order2 = SalesOrder(
        name: 'SAL-ORD-001',
        customer: 'Клиент 2',
        status: SalesOrderStatus.completed,
      );
      const order3 = SalesOrder(
        name: 'SAL-ORD-002',
        customer: 'Клиент 1',
        status: SalesOrderStatus.draft,
      );

      expect(order1, equals(order2));
      expect(order1.hashCode, equals(order2.hashCode));
      expect(order1, isNot(equals(order3)));
    });
  });

  group('SalesOrderStatus enum', () {
    test('fromWire maps known wire values', () {
      expect(SalesOrderStatus.fromWire('Draft'), SalesOrderStatus.draft);
      expect(
        SalesOrderStatus.fromWire('To Deliver and Bill'),
        SalesOrderStatus.toDeliverAndBill,
      );
      expect(SalesOrderStatus.fromWire('To Bill'), SalesOrderStatus.toBill);
      expect(
        SalesOrderStatus.fromWire('To Deliver'),
        SalesOrderStatus.toDeliver,
      );
      expect(
        SalesOrderStatus.fromWire('Completed'),
        SalesOrderStatus.completed,
      );
      expect(
        SalesOrderStatus.fromWire('Cancelled'),
        SalesOrderStatus.cancelled,
      );
      expect(SalesOrderStatus.fromWire('Closed'), SalesOrderStatus.closed);
      expect(SalesOrderStatus.fromWire('On Hold'), SalesOrderStatus.onHold);
      expect(SalesOrderStatus.fromWire('Unknown'), SalesOrderStatus.draft);
      expect(SalesOrderStatus.fromWire(null), SalesOrderStatus.draft);
    });

    test('intents are properly assigned', () {
      expect(SalesOrderStatus.completed.intent, StatusIntent.success);
      expect(SalesOrderStatus.onHold.intent, StatusIntent.danger);
      expect(SalesOrderStatus.toDeliverAndBill.intent, StatusIntent.info);
      expect(SalesOrderStatus.draft.intent, StatusIntent.neutral);
    });
  });
}
