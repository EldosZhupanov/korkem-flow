import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
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

class _TestSessionController extends SessionController {
  _TestSessionController(this._initial);

  final Session _initial;

  @override
  Future<Session> build() async => _initial;
}

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
    String? currentUser,
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
        if (currentUser != null)
          sessionProvider.overrideWith(
            () => _TestSessionController(
              Session(
                serverUrl: 'https://korkem.test',
                credentials: SessionCredentials(
                  user: currentUser,
                  sid: 'test_sid',
                ),
              ),
            ),
          ),
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
      '5. чужая задача выглядит чужой: кнопка и свайп неактивны, '
      'есть объяснение одной строкой',
      (tester) async {
        final myTask = makeTask(
          id: 401,
          title: 'Моя задача: сборка каркаса',
          assignedTo: 'worker@korkem.kz',
          dueDate: now.add(const Duration(hours: 2)),
        );
        final foreignTask = makeTask(
          id: 402,
          title: 'Чужая задача: шлифовка деталей',
          assignedTo: 'Мастер Ахметов',
          dueDate: now.add(const Duration(hours: 5)),
        );
        final unassignedTask = makeTask(
          id: 403,
          title: 'Свободная задача: упаковка заказа',
          dueDate: now.add(const Duration(hours: 6)),
        );

        await tester.pumpWidget(
          buildHarness(
            tasks: [myTask, foreignTask, unassignedTask],
            currentUser: 'worker@korkem.kz',
          ),
        );
        await tester.pumpAndSettle();

        // 1. Чужая задача выглядит чужой: разница видна до нажатия.
        // Выводится одна строка: чья задача и кто может её закрыть
        expect(
          find.text(
            'Задача: Мастер Ахметов. '
            'Закрыть может исполнитель или старший смены',
          ),
          findsOneWidget,
        );
        // Для своей и свободной задач такого объяснения нет
        expect(
          find.textContaining('worker@korkem.kz. Закрыть может'),
          findsNothing,
        );

        // 2. Кнопка на чужой задаче неактивна (onPressed == null),
        // на своей и свободной — активна (onPressed != null)
        final iconButtons = tester
            .widgetList<IconButton>(find.byType(IconButton))
            .toList();
        expect(iconButtons, hasLength(3));
        expect(iconButtons[0].onPressed, isNotNull);
        expect(iconButtons[1].onPressed, isNull);
        expect(iconButtons[2].onPressed, isNotNull);

        // 3. Свайп на чужой задаче неактивен (direction == none),
        // на своей и свободной — активен (direction == startToEnd)
        final dismissibles = tester
            .widgetList<Dismissible>(find.byType(Dismissible))
            .toList();
        expect(dismissibles, hasLength(3));
        expect(dismissibles[0].direction, equals(DismissDirection.startToEnd));
        expect(dismissibles[1].direction, equals(DismissDirection.none));
        expect(dismissibles[2].direction, equals(DismissDirection.startToEnd));
      },
    );

    testWidgets(
      'сервер отказывает при активной кнопке — отказ доходит словами, '
      'строка возвращается',
      (tester) async {
        const serverRefusal =
            'Эту задачу закрывает тот, кому она назначена. '
            'Если человек не может — закрыть за него может старший смены.';
        when(
          () => repository.complete(any(), notes: any(named: 'notes')),
        ).thenThrow(const ValidationFailure(serverRefusal));

        final task = makeTask(
          id: 450,
          title: 'Своя задача: фрезеровка пазов',
          assignedTo: 'worker@korkem.kz',
          dueDate: now.add(const Duration(hours: 1)),
        );

        await tester.pumpWidget(
          buildHarness(
            tasks: [task],
            currentUser: 'worker@korkem.kz',
          ),
        );
        await tester.pumpAndSettle();

        // Кнопка активна
        final button = tester.widget<IconButton>(find.byType(IconButton));
        expect(button.onPressed, isNotNull);

        // Нажимаем «Завершить»
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // Сначала строка оптимистично скрылась
        expect(find.text('Своя задача: фрезеровка пазов'), findsNothing);

        // Истекает окно отмены — запрос уходит и падает с отказом сервера
        await tester.pump(AppDebounce.undo + const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Отказ дошёл до человека словами
        expect(
          find.textContaining('Не удалось завершить задачу'),
          findsOneWidget,
        );
        expect(
          find.textContaining(serverRefusal),
          findsOneWidget,
        );

        // Строка вернулась на экран
        expect(find.text('Своя задача: фрезеровка пазов'), findsOneWidget);
      },
    );

    testWidgets(
      'объяснение чужой задачи переведено на три языка (ru, kk, en)',
      (tester) async {
        final foreignTask = makeTask(
          id: 480,
          title: 'Задача цеха',
          assignedTo: 'Serik',
          dueDate: now.add(const Duration(hours: 1)),
        );

        // Русский (ru)
        await tester.pumpWidget(
          buildHarness(
            tasks: [foreignTask],
            currentUser: 'Other',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Задача: Serik. Закрыть может исполнитель или старший смены',
          ),
          findsOneWidget,
        );

        // Казахский (kk)
        await tester.pumpWidget(
          buildHarness(
            tasks: [foreignTask],
            currentUser: 'Other',
            locale: const Locale('kk'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Тапсырма: Serik. Орындаушы немесе ауысым шебері аяқтай алады',
          ),
          findsOneWidget,
        );

        // Английский (en)
        await tester.pumpWidget(
          buildHarness(
            tasks: [foreignTask],
            currentUser: 'Other',
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Assigned to Serik. '
            'Can be completed by the assignee or shift supervisor',
          ),
          findsOneWidget,
        );
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
