import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late ReceivingRepository repository;

  setUp(() {
    client = _MockClient();
    repository = ReceivingRepository(client);
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
      expect(sentParams(), {'purchase_order': 'PUR-ORD-1'});
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
}
