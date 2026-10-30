import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/workstations/data/workstation_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockFrappeClient extends Mock implements FrappeClient {}

void main() {
  late _MockFrappeClient client;
  late WorkstationRepository repository;

  setUp(() {
    client = _MockFrappeClient();
    repository = WorkstationRepository(client);
  });

  void respond(Object? data) {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: any(named: 'post'),
      ),
    ).thenAnswer((_) async => {'message': data});
  }

  group('workstations query', () {
    test('fetches active workstations with waiting operations count', () async {
      respond({
        'workstations': [
          {'name': 'Edge 1', 'waiting': 3},
          {'name': 'Распил 1', 'waiting': 5},
        ],
        'total': 2,
      });

      final stations = await repository.fetchWorkstations();

      expect(stations, hasLength(2));
      expect(stations[0].name, 'Edge 1');
      expect(stations[0].waiting, 3);
      expect(stations[1].name, 'Распил 1');
      expect(stations[1].waiting, 5);

      final captured = verify(
        () => client.callMethod(
          captureAny(),
          params: captureAny(named: 'params'),
          post: any(named: 'post'),
        ),
      ).captured;

      expect(
        captured[0],
        'korkem_manufacturing.api.queries.workstations',
      );
      expect(captured[1], {'limit': 50, 'offset': 0});
    });

    test('handles empty response gracefully', () async {
      respond({'workstations': <Map<String, dynamic>>[], 'total': 0});

      final stations = await repository.fetchWorkstations();
      expect(stations, isEmpty);
    });
  });

  group('station_queue query', () {
    test('fetches queued operations for a specific workstation', () async {
      respond({
        'operations': [
          {
            'name': 'OP-0001',
            'work_order': 'MFG-WO-2026-00001',
            'operation': 'Edge Banding',
            'status': 'Pending',
            'completed_qty': 0.0,
            'planned_minutes': 45.0,
            'sequence': 1,
            'item': 'ITEM-DESK-01',
            'item_name': 'Стол Офисный',
            'order_qty': 10.0,
            'due_on': '2026-09-10',
          },
        ],
        'total': 1,
      });

      final queue = await repository.fetchStationQueue('Edge 1');

      expect(queue, hasLength(1));
      final op = queue.first;
      expect(op.name, 'OP-0001');
      expect(op.workOrder, 'MFG-WO-2026-00001');
      expect(op.operation, 'Edge Banding');
      expect(op.status, 'Pending');
      expect(op.completedQty, 0.0);
      expect(op.plannedMinutes, 45.0);
      expect(op.sequence, 1);
      expect(op.item, 'ITEM-DESK-01');
      expect(op.itemName, 'Стол Офисный');
      expect(op.orderQty, 10.0);
      expect(op.dueOn, '2026-09-10');

      final captured = verify(
        () => client.callMethod(
          captureAny(),
          params: captureAny(named: 'params'),
          post: any(named: 'post'),
        ),
      ).captured;

      expect(
        captured[0],
        'korkem_manufacturing.api.queries.station_queue',
      );
      expect(captured[1], {
        'workstation': 'Edge 1',
        'limit': 50,
        'offset': 0,
      });
    });

    test('handles empty queue gracefully', () async {
      respond({'operations': <Map<String, dynamic>>[], 'total': 0});

      final queue = await repository.fetchStationQueue('Edge 1');
      expect(queue, isEmpty);
    });
  });
}
