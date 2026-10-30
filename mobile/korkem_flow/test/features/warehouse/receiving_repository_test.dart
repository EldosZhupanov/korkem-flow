import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late ReceivingRepository repository;

  setUp(() {
    client = _MockClient();
    repository = ReceivingRepository(
      client,
      MutationOutbox(keyFactory: () => 'test-key'),
    );
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

  group('receiving reaches the domain service', () {
    test('it calls the published endpoint, not a doctype', () async {
      respond({'status': 'received'});

      await repository.receive('PUR-ORD-2026-00003');

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                  post: true,
                ),
              ).captured.single
              as String;

      expect(
        path,
        'korkem_manufacturing.api.purchasing.receive_purchase_order',
      );
    });

    test('it posts, because it moves the stock ledger', () async {
      respond({'status': 'received'});
      await repository.receive('PUR-ORD-1');
      verify(
        () =>
            client.callMethod(any(), params: any(named: 'params'), post: true),
      ).called(1);
    });

    test('it never sends a company', () async {
      respond({'status': 'received'});
      await repository.receive('PUR-ORD-1');
      expect(sentParams().containsKey('company'), isFalse);
    });

    test('a full receipt sends no line list at all', () async {
      // Absent means "everything still outstanding". An empty list would be a
      // different instruction, and the two must not be confused.
      respond({'status': 'received'});
      await repository.receive('PUR-ORD-1');
      expect(sentParams(), {
        'purchase_order': 'PUR-ORD-1',
        'idempotency_key': 'test-key',
      });
    });

    test('a partial receipt sends only the lines it narrows to', () async {
      respond({'status': 'received'});

      await repository.receive(
        'PUR-ORD-1',
        items: [
          {'item_code': 'ДСП 16мм', 'qty': 4},
        ],
      );

      expect(sentParams()['items'], [
        {'item_code': 'ДСП 16мм', 'qty': 4},
      ]);
    });
  });

  group('the answer is read, not recomputed', () {
    test('what landed on the shelf comes back line by line', () async {
      respond({
        'status': 'received',
        'purchase_receipt': 'MAT-PRE-2026-00002',
        'received': [
          {'item_code': 'ДСП 16мм', 'qty': 4.0, 'uom': 'Лист'},
        ],
      });

      final result = await repository.receive('PUR-ORD-1');

      expect(result.booked, isTrue);
      expect(result.purchaseReceipt, 'MAT-PRE-2026-00002');
      expect(result.received.single.itemCode, 'ДСП 16мм');
      expect(result.received.single.qty, 4.0);
      expect(result.received.single.uom, 'Лист');
    });

    test('a quantity that arrives as a string is still a number', () async {
      respond({
        'status': 'received',
        'purchase_receipt': 'MAT-PRE-1',
        'received': [
          {'item_code': 'ДСП', 'qty': '4.0'},
        ],
      });

      expect((await repository.receive('PUR-ORD-1')).received.single.qty, 4.0);
    });

    test('nothing booked is not the same as booked', () async {
      respond({'status': 'nothing_outstanding', 'message': 'Всё уже принято.'});

      final result = await repository.receive('PUR-ORD-1');

      expect(result.booked, isFalse);
      expect(result.status, 'nothing_outstanding');
    });

    test('an unrecognised shape does not crash the screen', () async {
      respond(const {});
      expect((await repository.receive('PUR-ORD-1')).status, 'unknown');
    });
  });

  group('the LLM is not in this path', () {
    test('a store keeper can receive with the provider down', () async {
      respond({'status': 'received', 'purchase_receipt': 'MAT-PRE-1'});

      await repository.receive('PUR-ORD-1');

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                  post: any(named: 'post'),
                ),
              ).captured.single
              as String;

      expect(path.contains('chat'), isFalse);
      expect(path.contains('korkem_ai'), isFalse);
    });

    test('a refusal still surfaces as one', () async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: any(named: 'post'),
        ),
      ).thenThrow(const PermissionFailure('You do not have warehouse rights'));

      expect(
        () => repository.receive('PUR-ORD-1'),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });

  group('ordering from a supplier', () {
    test('it calls the published endpoint', () async {
      respond({'status': 'ordered'});

      await repository.order('MAT-MR-2026-00004');

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                  post: true,
                ),
              ).captured.single
              as String;

      expect(path, 'korkem_manufacturing.api.purchasing.create_purchase_order');
    });

    test('no price can be sent, because there is nowhere to put one', () async {
      // The property worth guarding above every other here. Rates come from
      // the supplier's price list through ERPNext; a figure typed on a phone
      // is not a defensible source for money somebody has to pay.
      respond({'status': 'ordered'});

      await repository.order('MAT-MR-1', supplier: 'WoodGroup');

      final params = sentParams();
      expect(params.keys.toSet(), {
        'material_request',
        'supplier',
        'idempotency_key',
      });
      for (final forbidden in ['rate', 'price', 'amount', 'total', 'qty']) {
        expect(params.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });

    test('an unnamed supplier is not sent as null', () async {
      respond({'status': 'ordered'});
      await repository.order('MAT-MR-1');
      expect(sentParams(), {
        'material_request': 'MAT-MR-1',
        'idempotency_key': 'test-key',
      });
    });

    test('the total is read from the server, never computed here', () async {
      respond({
        'status': 'ordered',
        'purchase_order': 'PUR-ORD-2026-00003',
        'supplier': 'WoodGroup',
        'grand_total': 845000.0,
      });

      final result = await repository.order('MAT-MR-1');

      expect(result.placed, isTrue);
      expect(result.purchaseOrder, 'PUR-ORD-2026-00003');
      expect(result.supplier, 'WoodGroup');
      expect(result.grandTotal, 845000.0);
    });

    test('a total that arrives as a string is still a number', () async {
      respond({
        'status': 'ordered',
        'purchase_order': 'PUR-ORD-1',
        'grand_total': '845000.0',
      });
      expect((await repository.order('MAT-MR-1')).grandTotal, 845000.0);
    });

    test('nothing ordered is not the same as ordered', () async {
      respond({'status': 'nothing_to_order', 'message': 'Всё уже заказано.'});

      final result = await repository.order('MAT-MR-1');

      expect(result.placed, isFalse);
      expect(result.grandTotal, isNull, reason: 'no order, no figure');
    });

    test('a buyer can order with the provider down', () async {
      respond({'status': 'ordered', 'purchase_order': 'PUR-ORD-1'});

      await repository.order('MAT-MR-1');

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                  post: any(named: 'post'),
                ),
              ).captured.single
              as String;

      expect(path.contains('chat'), isFalse);
      expect(path.contains('korkem_ai'), isFalse);
    });
  });

  group('shipping to the customer', () {
    test('it calls the published endpoint', () async {
      respond({'status': 'shipped'});

      await repository.ship('SAL-ORD-2026-00011');

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                  post: true,
                ),
              ).captured.single
              as String;

      expect(path, 'korkem_manufacturing.api.dispatch.create_delivery');
    });

    test('no quantity can be sent, because the shelf decides', () async {
      // A finished quantity on a work order is not goods in a warehouse. The
      // server recomputes what can go out at the moment of execution.
      respond({'status': 'shipped'});

      await repository.ship('SAL-ORD-1');

      final params = sentParams();
      expect(params, {
        'sales_order': 'SAL-ORD-1',
        'idempotency_key': 'test-key',
      });
      for (final forbidden in ['qty', 'quantity', 'warehouse', 'company']) {
        expect(params.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });

    test('a trimmed shipment is reported as trimmed, not as success', () async {
      // Asking for four hundred against an order for ten with six on the shelf
      // ships six. Saying "done" without saying "six" is how a driver leaves
      // with the wrong load.
      respond({
        'status': 'shipped',
        'delivery_note': 'MAT-DN-2026-00002',
        'adjusted': true,
        'shipped': [
          {'item_code': 'Шкаф Астана', 'qty': 6.0, 'uom': 'Nos'},
        ],
      });

      final result = await repository.ship('SAL-ORD-1');

      expect(result.dispatched, isTrue);
      expect(result.adjusted, isTrue);
      expect(result.shipped.single.qty, 6.0);
    });

    test('nothing shipped is not the same as shipped', () async {
      respond({'status': 'blocked', 'message': 'Ничего нет на складе.'});

      final result = await repository.ship('SAL-ORD-1');

      expect(result.dispatched, isFalse);
      expect(result.shipped, isEmpty);
    });

    test('a dispatcher can ship with the provider down', () async {
      respond({'status': 'shipped', 'delivery_note': 'MAT-DN-1'});

      await repository.ship('SAL-ORD-1');

      final path =
          verify(
                () => client.callMethod(
                  captureAny(),
                  params: any(named: 'params'),
                  post: any(named: 'post'),
                ),
              ).captured.single
              as String;

      expect(path.contains('chat'), isFalse);
      expect(path.contains('korkem_ai'), isFalse);
    });
  });

  group('querying receivable purchase orders and material requests', () {
    test(
      'fetches receivable purchase orders through dedicated query endpoint',
      () async {
        respond({
          'orders': [
            {
              'name': 'PUR-ORD-2026-00001',
              'supplier': 'WoodGroup',
              'ordered_on': '2026-09-01',
              'expected_on': '2026-09-05',
              'status': 'To Receive',
              'received_percent': 25.0,
              'total': 450000.0,
            },
          ],
          'total': 1,
        });

        final orders = await repository.fetchReceivablePurchaseOrders();

        expect(orders, hasLength(1));
        expect(orders.first.name, 'PUR-ORD-2026-00001');
        expect(orders.first.supplier, 'WoodGroup');
        expect(orders.first.orderedOn, '2026-09-01');
        expect(orders.first.expectedOn, '2026-09-05');
        expect(orders.first.receivedPercent, 25.0);
        expect(orders.first.total, 450000.0);
      },
    );

    test(
      'fetches orderable material requests through dedicated query endpoint',
      () async {
        respond({
          'requests': [
            {
              'name': 'MAT-MR-2026-00001',
              'requested_on': '2026-09-01',
              'needed_on': '2026-09-10',
              'status': 'Pending',
              'ordered_percent': 0.0,
            },
          ],
          'total': 1,
        });

        final requests = await repository.fetchOrderableMaterialRequests();

        expect(requests, hasLength(1));
        expect(requests.first.name, 'MAT-MR-2026-00001');
        expect(requests.first.requestedOn, '2026-09-01');
        expect(requests.first.neededOn, '2026-09-10');
        expect(requests.first.orderedPercent, 0.0);
      },
    );
  });
}
