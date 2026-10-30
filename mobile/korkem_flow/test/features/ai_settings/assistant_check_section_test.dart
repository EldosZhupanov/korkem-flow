import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/ai_settings/data/assistant_check_repository.dart';
import 'package:korkem_flow/features/ai_settings/domain/assistant_check.dart';
import 'package:korkem_flow/features/ai_settings/presentation/widgets/assistant_check_section.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeAssistantCheckRepository implements AssistantCheckRepository {
  _FakeAssistantCheckRepository({
    this.initialReport = const AssistantCheckReport.notRun(),
    this.runResult,
    this.runDelay,
    this.loadDelay,
    this.runError,
    this.pollSequence,
  });

  AssistantCheckReport initialReport;
  AssistantCheckReport? runResult;
  Duration? runDelay;
  Duration? loadDelay;
  Exception? runError;
  List<AssistantCheckReport>? pollSequence;
  int runCallCount = 0;
  int getLastRunCallCount = 0;
  int pollCount = 0;

  @override
  Future<AssistantCheckReport> getLastRun() async {
    getLastRunCallCount++;
    if (loadDelay != null) {
      await Future<void>.delayed(loadDelay!);
    }
    if (runCallCount > 0 && pollSequence != null && pollSequence!.isNotEmpty) {
      final index = pollCount < pollSequence!.length
          ? pollCount++
          : pollSequence!.length - 1;
      return pollSequence![index];
    }
    return initialReport;
  }

  @override
  Future<AssistantCheckReport> runCheck() async {
    runCallCount++;
    if (runDelay != null) {
      await Future<void>.delayed(runDelay!);
    }
    if (runError != null) {
      throw runError!;
    }
    return runResult ?? initialReport;
  }
}

void main() {
  Widget buildHarness({
    required AssistantCheckRepository repository,
  }) {
    return ProviderScope(
      overrides: [
        assistantCheckRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: AssistantCheckSection(),
          ),
        ),
      ),
    );
  }

  group('AssistantCheckSection', () {
    testWidgets('1. пока прогона не было — объяснение, а не пустота', (
      tester,
    ) async {
      final repo = _FakeAssistantCheckRepository();

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      // Section title and run button
      expect(find.text('Проверка ассистента'), findsOneWidget);
      expect(find.text('Прогнать'), findsOneWidget);
      final runButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(runButton.enabled, isTrue);

      // Shows explanation, not empty space
      expect(find.text('Проверка не запускалась'), findsOneWidget);
      expect(
        find.text(
          'Запустите проверку, чтобы убедиться, что ассистент справляется '
          'с типичными сценариями цеха.',
        ),
        findsOneWidget,
      );

      // No scenario items or footer rendered
      expect(find.textContaining('Пройдено'), findsNothing);
      expect(find.textContaining('последний прогон'), findsNothing);
    });

    testWidgets('2. во время прогона кнопка недоступна', (tester) async {
      // Controller override with custom delayed repository
      final delayedRepo = _FakeAssistantCheckRepository(
        runDelay: const Duration(seconds: 2),
        runResult: const AssistantCheckReport(
          status: AssistantCheckStatus.completed,
          scenarios: [
            CheckScenario(
              id: '1',
              name: 'Сценарий 1',
              passed: true,
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildHarness(repository: delayedRepo));
      await tester.pumpAndSettle();

      // Initially enabled
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
        isTrue,
      );

      // Tap run button
      await tester.tap(find.text('Прогнать'));
      await tester.pump(); // Start execution

      // While running, button is disabled
      final runningButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(
        runningButton.enabled,
        isFalse,
        reason: 'Кнопка должна быть недоступна во время выполнения прогона',
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Идёт проверка...'), findsOneWidget);

      // Tapping disabled button does nothing
      await tester.tap(find.byType(FilledButton));
      expect(delayedRepo.runCallCount, 1);

      // Settle delayed execution
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // After finish, button is enabled again
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
        isTrue,
      );
      expect(find.text('Сценарий 1'), findsOneWidget);
    });

    testWidgets(
      '3. провалившийся сценарий показывает причину словами сервера',
      (tester) async {
        const failedReason = 'выбрал не тот инструмент';
        final repo = _FakeAssistantCheckRepository(
          initialReport: const AssistantCheckReport(
            status: AssistantCheckStatus.completed,
            scenarios: [
              CheckScenario(
                id: '1',
                name: 'Создать заявку из сообщения клиента',
                passed: false,
                failureReason: failedReason,
              ),
            ],
          ),
        );

        await tester.pumpWidget(buildHarness(repository: repo));
        await tester.pumpAndSettle();

        expect(
          find.text('Создать заявку из сообщения клиента'),
          findsOneWidget,
        );
        expect(find.textContaining(failedReason), findsOneWidget);
      },
    );

    testWidgets('4. счётчик «пройдено N из M» совпадает со списком', (
      tester,
    ) async {
      final testTime = DateTime(2026, 9, 4, 6, 40);
      final repo = _FakeAssistantCheckRepository(
        initialReport: AssistantCheckReport(
          status: AssistantCheckStatus.completed,
          lastRunAt: testTime,
          scenarios: const [
            CheckScenario(
              id: '1',
              name: 'Найти заказ по нечёткому описанию',
              passed: true,
              durationSeconds: 1.2,
            ),
            CheckScenario(
              id: '2',
              name: 'Проверить остаток материала',
              passed: true,
              durationSeconds: 0.8,
            ),
            CheckScenario(
              id: '3',
              name: 'Создать заявку из сообщения клиента',
              passed: false,
              failureReason: 'выбрал не тот инструмент',
            ),
            CheckScenario(
              id: '4',
              name: 'Отказать в опасном действии',
              passed: true,
              durationSeconds: 1.1,
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      // Counter matches scenarios list: 3 out of 4 passed
      expect(find.text('Пройдено 3 из 4'), findsOneWidget);
      expect(find.text('последний прогон 06:40'), findsOneWidget);

      // All 4 scenarios are present
      expect(
        find.text('Найти заказ по нечёткому описанию'),
        findsOneWidget,
      );
      expect(find.text('1.2 с'), findsOneWidget);

      expect(find.text('Проверить остаток материала'), findsOneWidget);
      expect(find.text('0.8 с'), findsOneWidget);

      expect(
        find.text('Создать заявку из сообщения клиента'),
        findsOneWidget,
      );
      expect(
        find.text('— выбрал не тот инструмент'),
        findsOneWidget,
      );

      expect(find.text('Отказать в опасном действии'), findsOneWidget);
      expect(find.text('1.1 с'), findsOneWidget);
    });

    testWidgets('загрузка прошлого результата не выдаёт себя за прогон', (
      tester,
    ) async {
      // Открывая экран, мы ждём прошлый результат — но ничего не прогоняем.
      // Пока эти два ожидания были одним `isLoading`, кнопка на первом кадре
      // говорила «Идёт проверка...» о проверке, которую никто не запускал.
      final repo = _FakeAssistantCheckRepository(
        loadDelay: const Duration(seconds: 2),
      );

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pump();

      expect(find.text('Идёт проверка...'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Прогнать'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
        isFalse,
        reason: 'Пока прошлый результат не загружен, запускать нечего',
      );
      expect(repo.runCallCount, 0);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
        isTrue,
      );
    });

    testWidgets('отказ без слов всё равно что-то говорит', (tester) async {
      // Сервер обязан прислать причину. Если однажды не пришлёт — пустая
      // красная строка с кнопкой «Повторить» не скажет человеку ничего.
      final repo = _FakeAssistantCheckRepository(
        initialReport: const AssistantCheckReport(
          status: AssistantCheckStatus.failed,
        ),
      );

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Что-то пошло не так.'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('показывает отказ сервера его словами при сбое', (
      tester,
    ) async {
      final repo = _FakeAssistantCheckRepository(
        runError: const ServerFailure(
          'Сервис моделей ИИ временно недоступен',
        ),
      );

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Прогнать'));
      await tester.pumpAndSettle();

      expect(
        find.text('Сервис моделей ИИ временно недоступен'),
        findsOneWidget,
      );
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets(
      'прогон: сервер отдаёт running, на 3-м опросе completed — экран '
      'показывает результат',
      (tester) async {
        final repo = _FakeAssistantCheckRepository(
          runResult: const AssistantCheckReport(
            status: AssistantCheckStatus.running,
          ),
          pollSequence: const [
            AssistantCheckReport(status: AssistantCheckStatus.running),
            AssistantCheckReport(status: AssistantCheckStatus.running),
            AssistantCheckReport(
              status: AssistantCheckStatus.completed,
              scenarios: [
                CheckScenario(
                  id: '1',
                  name: 'Найти заказ по нечёткому описанию',
                  passed: true,
                  durationSeconds: 1.2,
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(buildHarness(repository: repo));
        await tester.pumpAndSettle();

        expect(find.text('Проверка не запускалась'), findsOneWidget);

        await tester.tap(find.text('Прогнать'));
        await tester.pump();

        expect(find.text('Идёт проверка...'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Poll 1 (2s)
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Идёт проверка...'), findsOneWidget);
        expect(repo.pollCount, 1);

        // Poll 2 (4s)
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Идёт проверка...'), findsOneWidget);
        expect(repo.pollCount, 2);

        // Poll 3 (6s)
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(repo.pollCount, 3);

        expect(find.text('Найти заказ по нечёткому описанию'), findsOneWidget);
        expect(find.text('1.2 с'), findsOneWidget);
        expect(find.text('Пройдено 1 из 1'), findsOneWidget);
        expect(find.text('Идёт проверка...'), findsNothing);
        expect(find.text('Прогнать'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
          isTrue,
        );
      },
    );

    testWidgets('закрытый экран перестаёт опрашивать сервер', (tester) async {
      final repo = _FakeAssistantCheckRepository(
        runResult: const AssistantCheckReport(
          status: AssistantCheckStatus.running,
        ),
        pollSequence: const [
          AssistantCheckReport(status: AssistantCheckStatus.running),
        ],
      );

      await tester.pumpWidget(buildHarness(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Прогнать'));
      await tester.pump();

      // Advance 2 seconds for poll 1
      await tester.pump(const Duration(seconds: 2));
      final callsBeforeClose = repo.getLastRunCallCount;
      expect(callsBeforeClose, greaterThanOrEqualTo(2));

      // Close screen by replacing with SizedBox
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Advance time further
      await tester.pump(const Duration(seconds: 10));

      // Polls must not continue after screen disposal
      expect(repo.getLastRunCallCount, callsBeforeClose);
    });

    testWidgets(
      'потолок 3 минуты: бесконечный running прекращает опрос, показывает '
      'предупреждение и возвращает кнопку',
      (tester) async {
        final repo = _FakeAssistantCheckRepository(
          runResult: const AssistantCheckReport(
            status: AssistantCheckStatus.running,
          ),
          pollSequence: const [
            AssistantCheckReport(status: AssistantCheckStatus.running),
          ],
        );

        await tester.pumpWidget(buildHarness(repository: repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Прогнать'));
        await tester.pump();

        expect(find.text('Идёт проверка...'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
          isFalse,
        );

        // Advance by 3 minutes in fake time
        await tester.pump(const Duration(minutes: 3));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Проверка идёт дольше обычного. Загляните сюда через минуту.',
          ),
          findsOneWidget,
        );
        expect(find.text('Идёт проверка...'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text('Прогнать'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
          isTrue,
        );
      },
    );

    testWidgets(
      'статус failed в отчёте показывает отказ в _ErrorBox с failure_reason',
      (tester) async {
        const failureText = 'Сервис моделей ИИ перегружен запросами';
        final repo = _FakeAssistantCheckRepository(
          runResult: const AssistantCheckReport(
            status: AssistantCheckStatus.running,
          ),
          pollSequence: const [
            AssistantCheckReport(
              status: AssistantCheckStatus.failed,
              failureReason: failureText,
            ),
          ],
        );

        await tester.pumpWidget(buildHarness(repository: repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Прогнать'));
        await tester.pump();

        // 1st poll returns failed
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.text(failureText), findsOneWidget);
        expect(find.text('Повторить'), findsOneWidget);
        expect(find.text('Идёт проверка...'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
          isTrue,
        );
      },
    );
  });
}
