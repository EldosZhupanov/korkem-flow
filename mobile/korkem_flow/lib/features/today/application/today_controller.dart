import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/approvals/application/approvals_controller.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/orders/data/sales_order_repository.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:meta/meta.dart';

@immutable
class TodayOrdersSummary {
  const TodayOrdersSummary({
    required this.activeCount,
    required this.lateCount,
    required this.totalCount,
    this.lateOrders = const [],
  });

  final int activeCount;
  final int lateCount;
  final int totalCount;
  final List<SalesOrder> lateOrders;
}

@immutable
class TodayProductionSummary {
  const TodayProductionSummary({
    required this.inProcessCount,
    required this.lateCount,
    this.inProcessOrders = const [],
    this.lateOrders = const [],
  });

  final int inProcessCount;
  final int lateCount;
  final List<WorkOrder> inProcessOrders;
  final List<WorkOrder> lateOrders;
}

@immutable
class TodayApprovalsSummary {
  const TodayApprovalsSummary({
    required this.pendingCount,
    this.pendingActions = const [],
  });

  final int pendingCount;
  final List<PendingAction> pendingActions;
}

@immutable
class TodayStockSummary {
  const TodayStockSummary({
    required this.deficitCount,
    this.deficitPositions = const [],
  });

  final int deficitCount;
  final List<StockPosition> deficitPositions;
}

final todayOrdersSummaryProvider = FutureProvider<TodayOrdersSummary>((
  ref,
) async {
  final repo = ref.watch(salesOrderRepositoryProvider);
  final now = ref.watch(clockProvider)();

  final page = await repo.fetchPage(pageSize: 100);
  final active = page.orders.where((o) => !o.status.isFinished).toList();
  final lateOrders = active.where((o) => o.isLateAt(now)).toList();

  return TodayOrdersSummary(
    activeCount: active.length,
    lateCount: lateOrders.length,
    totalCount: page.total,
    lateOrders: lateOrders,
  );
});

final todayProductionSummaryProvider = FutureProvider<TodayProductionSummary>((
  ref,
) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  final now = ref.watch(clockProvider)();

  final inProcess = await repo.fetchPage(
    pageSize: 100,
    status: WorkOrderStatus.inProcess,
  );
  final lateOrders = inProcess.where((o) => o.isLateAt(now)).toList();

  return TodayProductionSummary(
    inProcessCount: inProcess.length,
    lateCount: lateOrders.length,
    inProcessOrders: inProcess,
    lateOrders: lateOrders,
  );
});

final todayApprovalsSummaryProvider = FutureProvider<TodayApprovalsSummary>((
  ref,
) async {
  final repo = ref.watch(pendingActionRepositoryProvider);

  final pending = await repo.fetchPage(
    pageSize: 100,
    status: PendingActionStatus.pending,
  );

  return TodayApprovalsSummary(
    pendingCount: pending.length,
    pendingActions: pending,
  );
});

final todayStockSummaryProvider = FutureProvider<TodayStockSummary>((
  ref,
) async {
  final repo = ref.watch(stockRepositoryProvider);

  final page = await repo.fetchStock(pageSize: 100);
  final deficits = page.items.where((i) => i.projectedQty < 0).toList();

  return TodayStockSummary(
    deficitCount: deficits.length,
    deficitPositions: deficits,
  );
});
