import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/features/production/domain/work_order_operation.dart';

void main() {
  group('WorkOrderOperation entity', () {
    test('fromJson correctly maps valid json', () {
      final json = {
        'name': 'WO-OP-00001',
        'operation': 'Распил ДСП',
        'workstation': 'Форматно-раскроечный станок',
        'status': 'Work in Progress',
        'completed_qty': 10.0,
        'scrap_qty': 1.0,
        'planned_minutes': 60.0,
        'sequence': 1,
      };

      final op = WorkOrderOperation.fromJson(json);

      expect(op.name, 'WO-OP-00001');
      expect(op.operation, 'Распил ДСП');
      expect(op.workstation, 'Форматно-раскроечный станок');
      expect(op.status, 'Work in Progress');
      expect(op.statusEnum, WorkOrderOperationStatus.inProgress);
      expect(op.completedQty, 10.0);
      expect(op.scrapQty, 1.0);
      expect(op.plannedMinutes, 60.0);
      expect(op.sequence, 1);
    });

    test('fromJson handles numbers passed as strings and nulls', () {
      final json = {
        'name': 'WO-OP-00002',
        'operation': null,
        'workstation': '   ',
        'status': 'Completed',
        'completed_qty': '15.5',
        'scrap_qty': '2.5',
        'planned_minutes': '45',
        'sequence': '2',
      };

      final op = WorkOrderOperation.fromJson(json);

      expect(op.name, 'WO-OP-00002');
      expect(op.operation, isNull);
      expect(op.workstation, isNull);
      expect(op.statusEnum, WorkOrderOperationStatus.completed);
      expect(op.completedQty, 15.5);
      expect(op.scrapQty, 2.5);
      expect(op.plannedMinutes, 45.0);
      expect(op.sequence, 2);
    });

    test('equality and hashCode are based on name', () {
      const op1 = WorkOrderOperation(
        name: 'WO-OP-00001',
        operation: 'Распил',
      );
      const op2 = WorkOrderOperation(
        name: 'WO-OP-00001',
        operation: 'Кромкооблицовка',
      );
      const op3 = WorkOrderOperation(
        name: 'WO-OP-00002',
        operation: 'Распил',
      );

      expect(op1, equals(op2));
      expect(op1.hashCode, equals(op2.hashCode));
      expect(op1, isNot(equals(op3)));
    });
  });

  group('WorkOrderOperationStatus enum', () {
    test('fromWire maps known wire values case-insensitively', () {
      expect(
        WorkOrderOperationStatus.fromWire('Pending'),
        WorkOrderOperationStatus.pending,
      );
      expect(
        WorkOrderOperationStatus.fromWire('pending'),
        WorkOrderOperationStatus.pending,
      );
      expect(
        WorkOrderOperationStatus.fromWire('Work in Progress'),
        WorkOrderOperationStatus.inProgress,
      );
      expect(
        WorkOrderOperationStatus.fromWire('In Progress'),
        WorkOrderOperationStatus.inProgress,
      );
      expect(
        WorkOrderOperationStatus.fromWire('in process'),
        WorkOrderOperationStatus.inProgress,
      );
      expect(
        WorkOrderOperationStatus.fromWire('Completed'),
        WorkOrderOperationStatus.completed,
      );
      expect(
        WorkOrderOperationStatus.fromWire('Closed'),
        WorkOrderOperationStatus.closed,
      );
      expect(
        WorkOrderOperationStatus.fromWire('Cancelled'),
        WorkOrderOperationStatus.cancelled,
      );
      expect(
        WorkOrderOperationStatus.fromWire('canceled'),
        WorkOrderOperationStatus.cancelled,
      );
      expect(
        WorkOrderOperationStatus.fromWire('unknown'),
        WorkOrderOperationStatus.pending,
      );
      expect(
        WorkOrderOperationStatus.fromWire(null),
        WorkOrderOperationStatus.pending,
      );
    });

    test('intents are properly assigned', () {
      expect(WorkOrderOperationStatus.pending.intent, StatusIntent.neutral);
      expect(WorkOrderOperationStatus.inProgress.intent, StatusIntent.info);
      expect(WorkOrderOperationStatus.completed.intent, StatusIntent.success);
      expect(WorkOrderOperationStatus.closed.intent, StatusIntent.neutral);
      expect(WorkOrderOperationStatus.cancelled.intent, StatusIntent.neutral);
    });
  });
}
