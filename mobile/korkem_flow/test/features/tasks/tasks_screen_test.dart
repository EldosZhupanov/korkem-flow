import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/tasks/application/tasks_controller.dart';
import 'package:korkem_flow/features/tasks/data/task_repository.dart';
import 'package:korkem_flow/features/tasks/domain/task.dart';
import 'package:korkem_flow/features/tasks/presentation/tasks_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late _MockTaskRepository repository;
  final now = DateTime(2026, 9, 4, 10);

  setUp(() {
    repository = _MockTaskRepository();
    when(
      () => repository.complete(any(), notes: any(named: 'notes')),
    ).thenAnswer((_) async {});
  });

  WorkTask makeTask({
    required int id,
    required String title,
    DateTime? dueDate,
    String? assignedTo,
    TaskPriority priority = TaskPriority.medium,
  }) => WorkTask(
    id: id,
    title: title,
    status: TaskStatus.todo,
    priority: priority,
    dueDate: dueDate,
    assignedTo: assignedTo,
  );

  Widget buildHarness({
    required List<WorkTask> tasks,
    Locale locale = const Locale('ru'),
  }) {
    when(
      () => repository.fetchPage(
        pageSize: any(named: 'pageSize'),
        offset: any(named: 'offset'),
        openOnly: any(named: 'openOnly'),
      ),
    ).thenAnswer((_) async => tasks);

    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TasksScreen(),
      ),
    );
  }

  group('Экран «Задачи» (TasksScreen)', () {
    testWidgets(
      '1. закрытие задачи доходит до сервера с точным ID, а не соседней',
      (tester) async {
        final task1 = makeTask(
          id: 101,
          title: 'Раскрой деталей кухни',
          dueDate: now.add(const Duration(hours: 2)),
        );
        final task2 = makeTask(
          id: 102,
          title: 'Кромление фасадов',
          dueDate: now.add(const Duration(hours: 4)),
        );

        await tester.pumpWidget(buildHarness(tasks: [task1, task2]));
        await tester.pumpAndSettle();

        expect(find.text('Раскрой деталей кухни'), findsOneWidget);
        expect(find.text('Кромление фасадов'), findsOneWidget);

        // Нажимаем кнопку завершения именно первой задачи
        final completeButtons = find.byType(IconButton);
        expect(completeButtons, findsNWidgets(2));
        await tester.tap(completeButtons.first);
        await tester.pump();

        // Строка немедленно оптимистично уходит с экрана
        expect(find.text('Раскрой деталей кухни'), findsNothing);
        expect(find.text('Кромление фасадов'), findsOneWidget);

        // До закрытия окна отмены на сервер ничего не уходит
        verifyNever(
          () => repository.complete(any(), notes: any(named: 'notes')),
        );

        // Ждём появления снекбара с кнопкой отмены
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Задача завершена'), findsOneWidget);
        expect(find.text('Отменить'), findsOneWidget);

        // Проматываем таймер до истечения окна отмены (AppDebounce.undo = 6s)
        await tester.pump(AppDebounce.undo);

        // Вызов на сервер ушёл ровно с ID первой задачи (101),
        // а не соседней (102)
        verify(() => repository.complete(101)).called(1);
        verifyNever(() => repository.complete(102));
      },
    );

    testWidgets(
      '2. отправка упала — человек об этом узнал (сообщение и возврат строки)',
      (tester) async {
        when(
          () => repository.complete(any(), notes: any(named: 'notes')),
        ).thenThrow(const ValidationFailure('Станок на техобслуживании'));

        final task = makeTask(
          id: 201,
          title: 'Фрезеровка пазов',
          dueDate: now.add(const Duration(hours: 1)),
        );

        await tester.pumpWidget(buildHarness(tasks: [task]));
        await tester.pumpAndSettle();

        expect(find.text('Фрезеровка пазов'), findsOneWidget);

        // Закрываем задачу
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // Сначала строка оптимистично скрылась
        expect(find.text('Фрезеровка пазов'), findsNothing);

        // Проматываем окно отмены, чтобы сработал сетевой запрос и упал
        await tester.pump(AppDebounce.undo + const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Человек узнал о сбое: показан снекбар с понятной причиной отказа
        expect(
          find.textContaining('Не удалось завершить задачу'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Станок на техобслуживании'),
          findsOneWidget,
        );

        // Задача вернулась на экран в список — работа не потеряна
        expect(find.text('Фрезеровка пазов'), findsOneWidget);
      },
    );

    testWidgets(
      '3. повторное нажатие не закрывает задачу дважды (дедупликация debounce)',
      (tester) async {
        final task = makeTask(
          id: 301,
          title: 'Присадка отверстий',
          dueDate: now.add(const Duration(hours: 3)),
        );

        await tester.pumpWidget(buildHarness(tasks: [task]));
        await tester.pumpAndSettle();

        final button = find.byType(IconButton);

        // Двойное быстрое нажатие (например, случайный дабл-тап)
        await tester.tap(button);
        await tester.tap(button);
        await tester.pump();

        // До истечения таймера вызовов нет
        verifyNever(
          () => repository.complete(any(), notes: any(named: 'notes')),
        );

        // Дожидаемся истечения дебаунса
        await tester.pump(AppDebounce.undo + const Duration(milliseconds: 100));

        // Вызов отправлен строго один раз, а не дважды
        verify(() => repository.complete(301)).called(1);
      },
    );

    testWidgets(
      '4. список пуст — это спокойное состояние, а не ошибка',
      (tester) async {
        await tester.pumpWidget(buildHarness(tasks: []));
        await tester.pumpAndSettle();

        // Спокойный текст состояния
        expect(find.text('Нет открытых задач'), findsOneWidget);
        expect(find.text('Назначенная работа появится здесь.'), findsOneWidget);

        // Иконка задач и пустое представление
        expect(find.byIcon(AppIcons.task), findsOneWidget);
        expect(find.byType(ListEmptyView), findsOneWidget);

        // Отсутствие признаков ошибки или технического сбоя
        expect(find.byType(ErrorView), findsNothing);
        expect(find.text('Ошибка'), findsNothing);
        expect(find.text('Нет данных'), findsNothing);
      },
    );

    testWidgets(
      '5. отображение исполнителя и поведение при чужой задаче',
      (tester) async {
        final myTask = makeTask(
          id: 401,
          title: 'Моя задача: сборка каркаса',
          assignedTo: 'Текущий Рабочий',
          dueDate: now.add(const Duration(hours: 2)),
        );
        final foreignTask = makeTask(
          id: 402,
          title: 'Чужая задача: шлифовка деталей',
          assignedTo: 'Мастер Ахметов',
          dueDate: now.add(const Duration(hours: 5)),
        );

        await tester.pumpWidget(buildHarness(tasks: [myTask, foreignTask]));
        await tester.pumpAndSettle();

        // Имя назначенного исполнителя видно на карточке в метаданных
        expect(find.text('Текущий Рабочий'), findsOneWidget);
        expect(find.text('Мастер Ахметов'), findsOneWidget);

        // Находка: экран НЕ разграничивает права и не блокирует кнопку закрытия
        // для чужих задач — любой рабочий может закрыть чужую задачу без
        // предупреждения:
        final completeButtons = find.byType(IconButton);
        expect(completeButtons, findsNWidgets(2));

        // Закрываем именно чужую задачу (вторую)
        await tester.tap(completeButtons.at(1));
        await tester.pump(AppDebounce.undo + const Duration(milliseconds: 100));

        // Серверный вызов на закрытие чужой задачи отправляется без ограничений
        verify(() => repository.complete(402)).called(1);
      },
    );

    testWidgets(
      'свайп вправо закрывает задачу и отправляет её на сервер',
      (tester) async {
        final task = makeTask(
          id: 501,
          title: 'Свайп: резка профиля',
          dueDate: now.add(const Duration(hours: 1)),
        );

        await tester.pumpWidget(buildHarness(tasks: [task]));
        await tester.pumpAndSettle();

        expect(find.text('Свайп: резка профиля'), findsOneWidget);

        // Свайпаем строку слева направо (startToEnd)
        await tester.drag(
          find.text('Свайп: резка профиля'),
          const Offset(500, 0),
        );
        await tester.pumpAndSettle();

        // Строка ушла, снекбар показан
        expect(find.text('Свайп: резка профиля'), findsNothing);
        expect(find.text('Задача завершена'), findsOneWidget);

        // По истечении таймера запрос уходит на сервер
        await tester.pump(AppDebounce.undo + const Duration(milliseconds: 100));
        verify(() => repository.complete(501)).called(1);
      },
    );

    testWidgets(
      'нажатие «Отменить» отменяет отправку и восстанавливает задачу на месте',
      (tester) async {
        final task = makeTask(
          id: 601,
          title: 'Ошибочно закрытая задача',
          dueDate: now.add(const Duration(hours: 2)),
        );

        await tester.pumpWidget(buildHarness(tasks: [task]));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(find.text('Ошибочно закрытая задача'), findsNothing);

        // Ждём появления снекбара
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Отменить'), findsOneWidget);

        // Нажимаем «Отменить»
        await tester.tap(find.text('Отменить'));
        await tester.pumpAndSettle();

        // Задача вернулась на экран
        expect(find.text('Ошибочно закрытая задача'), findsOneWidget);

        // Ждём больше времени окна отмены
        await tester.pump(AppDebounce.undo * 2);

        // На сервер вызов complete так и НЕ был отправлен!
        verifyNever(
          () => repository.complete(any(), notes: any(named: 'notes')),
        );
      },
    );

    testWidgets(
      'гонка: refresh во время выполнения complete не возвращает строку на '
      'экран и не провоцирует повторный complete',
      (tester) async {
        final completer = Completer<void>();
        when(
          () => repository.complete(any(), notes: any(named: 'notes')),
        ).thenAnswer((_) => completer.future);

        final task = makeTask(
          id: 701,
          title: 'Задача в полёте',
          dueDate: now.add(const Duration(hours: 1)),
        );

        await tester.pumpWidget(buildHarness(tasks: [task]));
        await tester.pumpAndSettle();

        expect(find.text('Задача в полёте'), findsOneWidget);

        // Рабочий закрывает задачу
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(find.text('Задача в полёте'), findsNothing);

        // Истекает окно отмены — запускается complete(701), зависая в полёте
        await tester.pump(AppDebounce.undo);
        verify(() => repository.complete(701)).called(1);

        // Посреди сетевого запроса происходит refresh()
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TasksScreen)),
        );
        unawaited(container.read(tasksControllerProvider.notifier).refresh());
        await tester.pump();

        // ГОНКА: строка НЕ должна возвращаться на экран
        expect(find.text('Задача в полёте'), findsNothing);

        completer.complete();
        await tester.pumpAndSettle();
      },
    );
  });
}
