import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
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

  @override
  Future<List<WorkTask>> build() =>
      ref.read(taskRepositoryProvider).fetchPage(pageSize: _pageSize);

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// Completes a task, removing it from the open list immediately.
  ///
  /// Optimistic because a worker on a factory floor should not wait on a round
  /// trip to see their tap register; the row returns if the server refuses.
  Future<void> complete(WorkTask task, {String? notes}) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.where((t) => t.id != task.id).toList());

    try {
      await ref.read(taskRepositoryProvider).complete(task.id, notes: notes);
    } on Exception {
      state = AsyncData(current);
      rethrow;
    }
  }
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
