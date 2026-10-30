import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/today/data/today_repository.dart';
import 'package:korkem_flow/features/today/domain/today_summary.dart';

class _FakeFrappeClient extends FrappeClient {
  _FakeFrappeClient(this.handler) : super(Dio());

  final Future<Map<String, dynamic>> Function(
    String method, {
    Map<String, dynamic>? params,
    bool post,
  })
  handler;

  @override
  Future<Map<String, dynamic>> callMethod(
    String path, {
    Map<String, dynamic>? params,
    bool post = false,
  }) async {
    return handler(path, params: params, post: post);
  }
}

void main() {
  group('TodaySummary', () {
    test('fromJson parses full payload with canonical field names', () {
      final json = {
        'overdue_orders': 3,
        'due_today_orders': 2,
        'due_this_week_orders': 7,
        'unpaid_amount': 1240000.5,
        'material_deficit_count': 4,
        'installations_today': 1,
        'pending_approvals': 2,
      };

      final summary = TodaySummary.fromJson(json);

      expect(summary.overdueOrders, 3);
      expect(summary.dueTodayOrders, 2);
      expect(summary.dueThisWeekOrders, 7);
      expect(summary.unpaidAmount, 1240000.5);
      expect(summary.materialDeficitCount, 4);
      expect(summary.installationsToday, 1);
      expect(summary.pendingApprovals, 2);
      expect(summary.isAllClear, isFalse);
    });

    test('fromJson handles aliases and string/num conversions gracefully', () {
      final json = {
        'late_orders': '5',
        'due_today': 1,
        'week_orders': '10',
        'unpaid': 500000,
        'deficit_positions': '2',
        'montage_today': '3',
        'approvals': 4,
      };

      final summary = TodaySummary.fromJson(json);

      expect(summary.overdueOrders, 5);
      expect(summary.dueTodayOrders, 1);
      expect(summary.dueThisWeekOrders, 10);
      expect(summary.unpaidAmount, 500000.0);
      expect(summary.materialDeficitCount, 2);
      expect(summary.installationsToday, 3);
      expect(summary.pendingApprovals, 4);
    });

    test('isAllClear is true when all values are zero or default', () {
      const summary = TodaySummary();
      expect(summary.isAllClear, isTrue);

      final fromEmptyJson = TodaySummary.fromJson(const {});
      expect(fromEmptyJson.isAllClear, isTrue);
    });

    test('isAllClear is false if any single metric is positive', () {
      expect(const TodaySummary(overdueOrders: 1).isAllClear, isFalse);
      expect(const TodaySummary(dueTodayOrders: 1).isAllClear, isFalse);
      expect(const TodaySummary(dueThisWeekOrders: 1).isAllClear, isFalse);
      expect(const TodaySummary(unpaidAmount: 100).isAllClear, isFalse);
      expect(const TodaySummary(materialDeficitCount: 1).isAllClear, isFalse);
      expect(const TodaySummary(installationsToday: 1).isAllClear, isFalse);
      expect(const TodaySummary(pendingApprovals: 1).isAllClear, isFalse);
    });
  });

  group('TodayRepository', () {
    test('fetchSummary queries endpoint and deserializes message', () async {
      String? calledMethod;

      final client = _FakeFrappeClient((method, {params, post = false}) async {
        calledMethod = method;
        return {
          'message': {
            'overdue_orders': 3,
            'due_today_orders': 2,
            'due_this_week_orders': 7,
            'unpaid_amount': 1240000,
            'material_deficit_count': 4,
            'installations_today': 1,
            'pending_approvals': 2,
          },
        };
      });

      final repo = TodayRepository(client);
      final summary = await repo.fetchSummary();

      expect(calledMethod, TodayRepository.summaryMethod);
      expect(summary.overdueOrders, 3);
      expect(summary.unpaidAmount, 1240000.0);
    });
  });
}
