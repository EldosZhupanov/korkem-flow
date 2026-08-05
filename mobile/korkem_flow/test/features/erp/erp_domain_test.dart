import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/features/approvals/data/pending_action_repository.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/production/data/work_order_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';

void main() {
  group('PendingAction', () {
    test('maps the live payload shape', () {
      // Copied from an actual /api/resource/Pending Action response.
      final action = PendingActionRepository.fromJson({
        'name': 't5kpjav344',
        'status': 'Pending',
        'agent_skill': 'create_quote',
        'entity_type': 'CRM Deal',
        'entity_name': 'CRM-DEAL-2026-00002',
        'action_class': 'CreateQuoteAction',
        'expires_at': '2026-07-29 13:46:05.211177',
        'resolved_by': null,
        'resolved_at': null,
      });

      expect(action.id, 't5kpjav344');
      expect(action.isPending, isTrue);
      expect(action.status.intent, StatusIntent.warning);
      expect(action.entityName, 'CRM-DEAL-2026-00002');
      expect(action.expiresAt, isNotNull);
      expect(action.resolvedBy, isNull);
    });

    test('expiry is judged against a supplied instant, not the wall clock', () {
      // Injected so the boundary is testable at all — and so a golden of this
      // screen does not change its own meaning once a day.
      final action = PendingAction(
        id: 'A',
        status: PendingActionStatus.pending,
        agentSkill: 'create_quote',
        expiresAt: DateTime(2026, 7, 29, 12),
      );

      expect(action.isExpiredAt(DateTime(2026, 7, 29, 11, 59)), isFalse);
      expect(action.isExpiredAt(DateTime(2026, 7, 29, 12, 1)), isTrue);
    });

    test('an action with no expiry never expires', () {
      const action = PendingAction(
        id: 'A',
        status: PendingActionStatus.pending,
        agentSkill: 'x',
      );

      expect(action.isExpiredAt(DateTime(2099)), isFalse);
    });

    test('resolved statuses carry their own intent', () {
      expect(
        PendingActionStatus.fromWire('Approved').intent,
        StatusIntent.success,
      );
      expect(
        PendingActionStatus.fromWire('Rejected').intent,
        StatusIntent.danger,
      );
      expect(
        PendingActionStatus.fromWire('Expired').intent,
        StatusIntent.neutral,
      );
    });
  });

  group('WorkOrder', () {
    WorkOrder order({
      Object? qty = 40,
      Object? produced = 18,
      String status = 'In Process',
    }) {
      return WorkOrderRepository.fromJson({
        'name': 'MFG-WO-2026-00019',
        'status': status,
        'qty': qty,
        'produced_qty': produced,
        'item_name': 'Фасад МДФ 716×396',
        'originating_deal': 'CRM-DEAL-2026-00041',
        'planned_end_date': '2026-08-02 17:00:00',
      });
    }

    test('maps the live payload, including the custom deal link', () {
      final o = order();

      expect(o.id, 'MFG-WO-2026-00019');
      expect(o.status, WorkOrderStatus.inProcess);
      expect(o.itemName, 'Фасад МДФ 716×396');
      // The field that makes the Production Order lifecycle traceable.
      expect(o.originatingDeal, 'CRM-DEAL-2026-00041');
      expect(o.progress, closeTo(0.45, 0.001));
    });

    test('parses floats that arrive as strings', () {
      expect(order(qty: '40', produced: '10').progress, closeTo(0.25, 0.001));
    });

    test('a zero quantity is 0% progress, not NaN', () {
      // NaN renders as an indeterminate bar — a spinner where a worker expects
      // a measurement, which reads as "loading" forever.
      final o = order(qty: 0, produced: 0);

      expect(o.progress, 0);
      expect(o.progress.isNaN, isFalse);
    });

    test('progress cannot exceed 1 when overproduced', () {
      expect(order(qty: 10, produced: 14).progress, 1.0);
    });

    test('a finished order is never late, whatever the plan said', () {
      // Long past the plan, so only the status can be what spares it.
      final wellPast = DateTime(2030);

      expect(order(status: 'Completed').isLateAt(wellPast), isFalse);
      expect(order(status: 'Closed').isLateAt(wellPast), isFalse);
      expect(order(status: 'Cancelled').isLateAt(wellPast), isFalse);
    });

    test('lateness is judged against the time it is given', () {
      // The point of taking the time as an argument. This getter used to read
      // the system clock, which made a golden that had passed for days start
      // failing on its own the morning the fixture's due date arrived.
      final open = order();

      expect(open.isLateAt(DateTime(2020)), isFalse);
      expect(open.isLateAt(DateTime(2030)), isTrue);
    });

    test('classifies which statuses mean the factory is working', () {
      expect(WorkOrderStatus.inProcess.isActive, isTrue);
      expect(WorkOrderStatus.notStarted.isActive, isTrue);
      expect(WorkOrderStatus.completed.isActive, isFalse);
      expect(WorkOrderStatus.completed.isFinished, isTrue);
      expect(WorkOrderStatus.stopped.intent, StatusIntent.danger);
    });

    test('an unknown status falls back rather than throwing', () {
      // A vendored Select can gain options in an ERPNext upgrade.
      expect(WorkOrderStatus.fromWire('Quality Hold'), WorkOrderStatus.draft);
    });
  });
}
