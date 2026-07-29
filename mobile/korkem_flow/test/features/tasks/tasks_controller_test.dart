import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/features/tasks/application/tasks_controller.dart';
import 'package:korkem_flow/features/tasks/data/task_repository.dart';
import 'package:korkem_flow/features/tasks/domain/task.dart';
import 'package:mocktail/mocktail.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

WorkTask _task(int id) => WorkTask(
  id: id,
  title: 'Task $id',
  status: TaskStatus.todo,
  priority: TaskPriority.medium,
);

/// The completion undo, which guards the only destructive gesture in the app.
///
/// Worth pinning hard because it is a *timing* feature: the request is held for
/// [AppDebounce.undo] so that undoing cancels something that was never sent.
/// `CRM Task` has no reopen call, so if the request ever escapes early the undo
/// silently becomes a button that lies — and nothing on screen would look any
/// different.
void main() {
  late _MockTaskRepository repository;

  setUp(() {
    repository = _MockTaskRepository();
    when(
      () => repository.fetchPage(pageSize: any(named: 'pageSize')),
    ).thenAnswer((_) async => [_task(1), _task(2), _task(3)]);
    when(
      () => repository.complete(any(), notes: any(named: 'notes')),
    ).thenAnswer((_) async {});
  });

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repository)],
      // Riverpod 3 auto-retries a failed provider with backoff, so a failing
      // provider sits in AsyncLoading(retrying) and never settles.
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A container with its first page already loaded, inside fake time.
  ///
  /// The load is a real `Future`; `flushMicrotasks` is what settles it without
  /// leaving fake time, which every timing assertion below depends on.
  ProviderContainer loadedIn(FakeAsync async) {
    final container = containerWith();
    unawaited(container.read(tasksControllerProvider.future));
    async.flushMicrotasks();
    return container;
  }

  List<int> idsIn(ProviderContainer container) => [
    ...?container.read(tasksControllerProvider).value?.map((t) => t.id),
  ];

  void expectNothingSent() =>
      verifyNever(() => repository.complete(any(), notes: any(named: 'notes')));

  test('the row leaves immediately, before anything is sent', () {
    fakeAsync((async) {
      final container = loadedIn(async);

      container.read(tasksControllerProvider.notifier).completeLater(_task(2));

      expect(idsIn(container), [1, 3]);
      expectNothingSent();
    });
  });

  test('nothing is sent until the undo window closes', () {
    fakeAsync((async) {
      loadedIn(
        async,
      ).read(tasksControllerProvider.notifier).completeLater(_task(2));

      async.elapse(AppDebounce.undo - const Duration(milliseconds: 1));
      expectNothingSent();

      async.elapse(const Duration(milliseconds: 2));
      verify(() => repository.complete(2)).called(1);
    });
  });

  test('undo cancels the request outright and restores the row in place', () {
    fakeAsync((async) {
      final container = loadedIn(async);
      final notifier = container.read(tasksControllerProvider.notifier)
        ..completeLater(_task(2));
      expect(idsIn(container), [1, 3]);

      notifier.undoComplete(_task(2));

      // Back where it was, not appended. Within a due-date bucket the list
      // order is the only order there is, so a row restored to the bottom
      // would read as a different task.
      expect(idsIn(container), [1, 2, 3]);

      async.elapse(AppDebounce.undo * 2);
      expectNothingSent();
    });
  });

  test('a refused completion puts the row back and reports the reason', () {
    when(
      () => repository.complete(any(), notes: any(named: 'notes')),
    ).thenThrow(const ValidationFailure('This task is already closed.'));

    fakeAsync((async) {
      final container = loadedIn(async);
      container.read(tasksControllerProvider.notifier).completeLater(_task(2));

      async
        ..elapse(AppDebounce.undo)
        ..flushMicrotasks();

      // Hiding a task the server still considers open is how work gets lost.
      expect(idsIn(container), [1, 2, 3]);
      expect(
        container.read(taskFailureProvider),
        isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          'This task is already closed.',
        ),
      );
    });
  });

  test('a refresh does not resurrect a row whose completion is still held', () {
    fakeAsync((async) {
      final container = loadedIn(async);
      final notifier = container.read(tasksControllerProvider.notifier)
        ..completeLater(_task(2));

      // The server still has task 2 open — the completion has not been sent —
      // so a refresh mid-window would otherwise put a row the user just
      // cleared straight back on their screen.
      unawaited(notifier.refresh());
      async.flushMicrotasks();

      expect(idsIn(container), [1, 3]);
    });
  });
}
