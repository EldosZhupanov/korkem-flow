import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/approvals/data/pending_action_repository.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/dashboard/application/dashboard_controller.dart';

final pendingActionRepositoryProvider = Provider<PendingActionRepository>(
  (ref) => PendingActionRepository(ref.watch(frappeClientProvider)),
);

/// Which slice of the queue is shown. Defaults to the only one that needs a
/// human: resolved proposals are history.
final approvalFilterProvider =
    NotifierProvider<ApprovalFilterNotifier, PendingActionStatus?>(
      ApprovalFilterNotifier.new,
    );

class ApprovalFilterNotifier extends Notifier<PendingActionStatus?> {
  @override
  PendingActionStatus? build() => PendingActionStatus.pending;

  /// The queue as a worker thinks of it: what still needs me.
  void showPending() => state = PendingActionStatus.pending;

  /// Everything, including resolved history.
  void showAll() => state = null;
}

final approvalsControllerProvider =
    AsyncNotifierProvider<ApprovalsController, PagedList<PendingAction>>(
      ApprovalsController.new,
    );

class ApprovalsController extends PagedListController<PendingAction> {
  @override
  Future<List<PendingAction>> fetchPage({
    required int offset,
    required int pageSize,
  }) {
    final status = ref.watch(approvalFilterProvider);

    return ref
        .watch(pendingActionRepositoryProvider)
        .fetchPage(pageSize: pageSize, offset: offset, status: status);
  }

  /// Resolves a proposal and removes it from the queue.
  ///
  /// Not optimistic, unlike task completion: approving executes a real command
  /// server-side — creating a quote, scheduling production — and showing it as
  /// done before the server agrees would be claiming work happened that may
  /// not have. The row stays until the backend confirms.
  Future<void> resolve(
    PendingAction action, {
    required bool approved,
    String? reason,
  }) async {
    final repository = ref.read(pendingActionRepositoryProvider);

    if (approved) {
      await repository.approve(action.id);
    } else {
      await repository.reject(action.id, reason: reason);
    }

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          items: current.items.where((a) => a.id != action.id).toList(),
        ),
      );
    }

    // The dashboard counts this queue.
    ref.invalidate(dashboardControllerProvider);
  }
}
