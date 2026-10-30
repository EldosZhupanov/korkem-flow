import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/ai_settings/data/ai_settings_repository.dart';
import 'package:korkem_flow/features/ai_settings/domain/prompt_breakdown.dart';
import 'package:korkem_flow/features/ai_settings/presentation/widgets/prompt_breakdown_section.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

void main() {
  group('LastPromptBreakdown domain logic', () {
    test('heaviestItemId identifies unique maximum item', () {
      const breakdown = LastPromptBreakdown(
        totalTokens: 14300,
        items: [
          TokenBreakdownItem(id: 'instruction', label: '', tokens: 2100),
          TokenBreakdownItem(id: 'tools', label: '', tokens: 5400),
          TokenBreakdownItem(id: 'company_memory', label: '', tokens: 800),
          TokenBreakdownItem(id: 'user_memory', label: '', tokens: 300),
          TokenBreakdownItem(id: 'conversation', label: '', tokens: 3200),
          TokenBreakdownItem(id: 'order_data', label: '', tokens: 2500),
        ],
      );

      expect(breakdown.heaviestItemId, 'tools');
    });

    test(
      'heaviestItemId returns null on tie '
      '(равные значения — не выделяется ничего)',
      () {
        const breakdown = LastPromptBreakdown(
          totalTokens: 9000,
          items: [
            TokenBreakdownItem(id: 'tools', label: '', tokens: 4000),
            TokenBreakdownItem(id: 'conversation', label: '', tokens: 4000),
            TokenBreakdownItem(id: 'instruction', label: '', tokens: 1000),
          ],
        );

        expect(breakdown.heaviestItemId, isNull);
      },
    );

    test('heaviestItemId returns null when list is empty or zero', () {
      const empty = LastPromptBreakdown(totalTokens: 0, items: []);
      expect(empty.heaviestItemId, isNull);

      const allZero = LastPromptBreakdown(
        totalTokens: 0,
        items: [
          TokenBreakdownItem(id: 'tools', label: '', tokens: 0),
          TokenBreakdownItem(id: 'instruction', label: '', tokens: 0),
        ],
      );
      expect(allZero.heaviestItemId, isNull);
    });

    test('formatTokenCount groups thousands with spaces', () {
      expect(formatTokenCount(14300), '14 300');
      expect(formatTokenCount(2100), '2 100');
      expect(formatTokenCount(800), '800');
      expect(formatTokenCount(0), '0');
    });

    test('WeeklyUsageSummary computes rates correctly', () {
      const summary = WeeklyUsageSummary(
        totalTurns: 100,
        primaryModelTurns: 85,
        reserveTurns: 15,
        averageDurationSeconds: 1.5,
      );

      expect(summary.primaryRatePercent, 85);
      expect(summary.reserveRatePercent, 15);
    });
  });

  group('PromptBreakdownSection widget', () {
    Widget buildHarness({
      required Future<PromptBreakdownReport> Function() fetchReport,
    }) {
      return ProviderScope(
        overrides: [
          aiPromptBreakdownProvider.overrideWith((ref) => fetchReport()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PromptBreakdownSection(),
            ),
          ),
        ),
      );
    }

    testWidgets(
      '1. самая тяжёлая строка выделена именно та, что больше остальных',
      (tester) async {
        const report = PromptBreakdownReport(
          lastPrompt: LastPromptBreakdown(
            totalTokens: 14300,
            items: [
              TokenBreakdownItem(
                id: 'instruction',
                label: 'Инструкция',
                tokens: 2100,
              ),
              TokenBreakdownItem(
                id: 'tools',
                label: 'Схемы инструментов',
                tokens: 5400,
              ),
              TokenBreakdownItem(
                id: 'company_memory',
                label: 'Память компании',
                tokens: 800,
              ),
              TokenBreakdownItem(
                id: 'user_memory',
                label: 'Память обо мне',
                tokens: 300,
              ),
              TokenBreakdownItem(
                id: 'conversation',
                label: 'Разговор',
                tokens: 3200,
              ),
              TokenBreakdownItem(
                id: 'order_data',
                label: 'Данные заказа',
                tokens: 2500,
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          buildHarness(fetchReport: () async => report),
        );
        await tester.pumpAndSettle();

        expect(find.text('Из чего сложился последний запрос'), findsOneWidget);
        expect(find.text('14 300 токенов'), findsOneWidget);

        // Check rows
        expect(find.text('Инструкция'), findsOneWidget);
        expect(find.text('2 100'), findsOneWidget);

        expect(find.text('Схемы инструментов'), findsOneWidget);
        expect(find.text('5 400'), findsOneWidget);

        // "самое тяжёлое" chip is shown exactly ONCE, on the heaviest row
        final heaviestChip = find.widgetWithText(StatusChip, 'самое тяжёлое');
        expect(heaviestChip, findsOneWidget);

        // Ensure other rows do not have the chip
        expect(find.text('3 200'), findsOneWidget);
        expect(find.text('2 500'), findsOneWidget);
      },
    );

    testWidgets(
      '2. при равных значениях не выделяется ничего (нет ответа наугад)',
      (tester) async {
        const report = PromptBreakdownReport(
          lastPrompt: LastPromptBreakdown(
            totalTokens: 9000,
            items: [
              TokenBreakdownItem(
                id: 'tools',
                label: 'Схемы инструментов',
                tokens: 4000,
              ),
              TokenBreakdownItem(
                id: 'conversation',
                label: 'Разговор',
                tokens: 4000,
              ),
              TokenBreakdownItem(
                id: 'instruction',
                label: 'Инструкция',
                tokens: 1000,
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          buildHarness(fetchReport: () async => report),
        );
        await tester.pumpAndSettle();

        expect(find.text('4 000'), findsNWidgets(2));
        // Neither row should be crowned "heaviest"
        expect(find.text('самое тяжёлое'), findsNothing);
      },
    );

    testWidgets(
      '3. пустое состояние объясняет, а не молчит',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            fetchReport: () async => const PromptBreakdownReport.empty(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Из чего сложился последний запрос'), findsOneWidget);
        expect(find.text('Запросов ещё не было'), findsOneWidget);
        expect(
          find.textContaining('Здесь появится разбивка токенов'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '4. отказ сервера показан его словами',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            fetchReport: () => Future.error(
              const ServerFailure('Сервис аналитики токенов недоступен'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verbatim server refusal displayed
        expect(
          find.text('Сервис аналитики токенов недоступен'),
          findsOneWidget,
        );
        expect(find.text('Повторить'), findsOneWidget);
      },
    );

    testWidgets(
      '5. сводка за неделю отображает все ключевые метрики',
      (tester) async {
        const report = PromptBreakdownReport(
          lastPrompt: LastPromptBreakdown(
            totalTokens: 5000,
            items: [
              TokenBreakdownItem(
                id: 'instruction',
                label: 'Инструкция',
                tokens: 5000,
              ),
            ],
          ),
          weeklySummary: WeeklyUsageSummary(
            totalTurns: 142,
            primaryModelTurns: 128,
            reserveTurns: 14,
            averageDurationSeconds: 1.8,
          ),
        );

        await tester.pumpWidget(
          buildHarness(fetchReport: () async => report),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сводка за неделю'), findsOneWidget);
        expect(find.text('Всего ходов'), findsOneWidget);
        expect(find.text('142'), findsOneWidget);

        expect(find.text('Первой моделью'), findsOneWidget);
        expect(find.text('128 (90%)'), findsOneWidget);

        expect(find.text('Резерв KORKEM'), findsOneWidget);
        expect(find.text('14 (10%)'), findsOneWidget);

        expect(find.text('Средняя длительность'), findsOneWidget);
        expect(find.text('1.8 с'), findsOneWidget);
      },
    );
  });
}
