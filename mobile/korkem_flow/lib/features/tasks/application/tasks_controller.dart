import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/tasks/data/task_repository.dart';
import 'package:korkem_flow/features/tasks/domain/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(frappeClientProvider)),
);

final tasksControllerProvider =
    AsyncNotifierProvider<TasksController, List<WorkTask>>(
      TasksController.new,
    );

class TasksController extends AsyncNotifier<List<WorkTask>> {
  static const _pageSize = 50;

  /// Completions the user has asked for and can still take back, by task id.
  final _pending = <int, _PendingCompletion>{};

  @override
  Future<List<WorkTask>> build() {
    final repository = ref.watch(taskRepositoryProvider);
    // Captured, not looked up later: Riverpod forbids touching `ref` from a
    // dispose callback, and by the time this one runs the container may
    // already be tearing itself down.
    ref.onDispose(() => _sendEverythingPending(repository));
    return repository.fetchPage(pageSize: _pageSize);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final fresh = await build();
      // A task whose completion is still waiting out its undo window is open
      // on the server and would come back in this response — putting a row the
      // user just cleared back on their screen.
      return fresh.where((task) => !_pending.containsKey(task.id)).toList();
    });
  }

  /// Removes the task now and sends the completion once the undo window closes.
  ///
  /// Holding the request is what makes the undo real. `CRM Task` has no reopen
  /// call — `korkem_manufacturing.shop_floor.complete_task` is one-way — so an
  /// undo offered *after* the write would be a promise this app cannot keep.
  /// Deferring means undoing cancels something that never left the phone.
  ///
  /// The row leaves immediately regardless: a worker on a factory floor should
  /// not wait on a round trip to see their swipe register.
  void completeLater(WorkTask task, {String? notes}) {
    final current = state.value;
    if (current == null || _pending.containsKey(task.id)) return;

    final index = current.indexWhere((t) => t.id == task.id);
    if (index < 0) return;

    state = AsyncData([...current]..removeAt(index));
    _pending[task.id] = _PendingCompletion(
      task: task,
      index: index,
      timer: Timer(AppDebounce.undo, () => unawaited(_send(task, notes))),
    );
  }

  /// Cancels a completion still inside its window and puts the row back where
  /// it was. A no-op once the request has gone, which is why the snackbar
  /// offering it lives exactly as long as the window.
  void undoComplete(WorkTask task) {
    final pending = _pending[task.id];
    if (pending == null || !pending.timer.isActive) return;

    _pending.remove(task.id);
    pending.timer.cancel();
    _restore(pending);
  }

  Future<void> _send(WorkTask task, String? notes) async {
    final pending = _pending[task.id];
    if (pending == null) return;

    try {
      await ref.read(taskRepositoryProvider).complete(task.id, notes: notes);
    } on Exception catch (error) {
      // The row comes back, because the app said "done" and it is not done.
      // Hiding a task the server still considers open is how work gets lost.
      _restore(pending);
      // Reported out of band rather than thrown: this runs from a timer with
      // nobody left to catch it, and the screen that started the swipe may not
      // even be mounted. Surfacing it as state lets whichever screen *is*
      // mounted tell the user.
      ref.read(taskFailureProvider.notifier).report(error);
    } finally {
      _pending.remove(task.id);
    }
  }

  void _restore(_PendingCompletion pending) {
    final current = state.value;
    if (current == null || current.any((t) => t.id == pending.task.id)) return;

    state = AsyncData(
      [...current]..insert(
        pending.index.clamp(0, current.length),
        pending.task,
      ),
    );
  }

  /// Signing out, or otherwise losing this controller, must not quietly drop a
  /// completion the user already asked for. Their intent was to finish the
  /// task, so the remaining wait is skipped rather than the request abandoned.
  ///
  /// A failure here cannot be shown — there is no screen left to show it on —
  /// so the task simply stays open and reappears on the next launch. That is
  /// the honest outcome: the work was not recorded, and the list says so.
  void _sendEverythingPending(TaskRepository repository) {
    for (final pending in _pending.values) {
      pending.timer.cancel();
      unawaited(repository.complete(pending.task.id).catchError((_) {}));
    }
    _pending.clear();
  }
}

/// A completion in flight, with everything needed to put it back.
class _PendingCompletion {
  const _PendingCompletion({
    required this.task,
    required this.index,
    required this.timer,
  });

  final WorkTask task;

  /// Where the row was, so an undo restores the order rather than appending.
  /// Within a due-date bucket the list order is the only order there is.
  final int index;

  final Timer timer;
}

/// The last completion failure, for whichever screen is mounted to report.
///
/// Deferred completions fail after the gesture that started them is over, so
/// there is no `await` left to throw into. This is the seam.
final taskFailureProvider = NotifierProvider<TaskFailureNotifier, Object?>(
  TaskFailureNotifier.new,
);

class TaskFailureNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  /// Last one wins: two failures inside one window are one interruption, and
  /// stacking snackbars buries both.
  ///
  /// A method rather than the setter the linter suggests. A notifier's mutation
  /// surface is a list of events, and `report(error)` reads as one where
  /// `failure = error` would read as state the caller owns.
  // ignore: use_setters_to_change_properties
  void report(Object error) => state = error;

  /// Called once the failure has been shown, so the same one is not reported
  /// twice when the screen rebuilds.
  void clear() => state = null;
}

/// Open tasks split into the three buckets a worker actually thinks in.
///
/// Derived rather than stored, so it cannot drift out of sync with the list.
final groupedTasksProvider = Provider<AsyncValue<TaskGroups>>((ref) {
  final now = ref.watch(clockProvider);
  return ref
      .watch(tasksControllerProvider)
      .whenData((tasks) => TaskGroups.from(tasks, now()));
});

class TaskGroups {
  const TaskGroups({
    required this.overdue,
    required this.today,
    required this.upcoming,
  });

  factory TaskGroups.from(List<WorkTask> tasks, DateTime now) {
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final overdue = <WorkTask>[];
    final today = <WorkTask>[];
    final upcoming = <WorkTask>[];

    for (final task in tasks) {
      final due = task.dueDate;
      if (due == null) {
        upcoming.add(task);
      } else if (due.isBefore(now)) {
        overdue.add(task);
      } else if (!due.isAfter(endOfToday)) {
        today.add(task);
      } else {
        upcoming.add(task);
      }
    }

    return TaskGroups(overdue: overdue, today: today, upcoming: upcoming);
  }

  final List<WorkTask> overdue;
  final List<WorkTask> today;
  final List<WorkTask> upcoming;

  bool get isEmpty => overdue.isEmpty && today.isEmpty && upcoming.isEmpty;
}
