import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/ai_settings/domain/assistant_check.dart';

void main() {
  group('CheckScenario', () {
    test('parses json with duration in seconds and reason', () {
      final scenario = CheckScenario.fromJson(const {
        'id': 'test_1',
        'name': 'Найти заказ по нечёткому описанию',
        'passed': true,
        'duration_seconds': 1.2,
      });

      expect(scenario.id, 'test_1');
      expect(scenario.name, 'Найти заказ по нечёткому описанию');
      expect(scenario.passed, isTrue);
      expect(scenario.durationSeconds, 1.2);
      expect(scenario.failureReason, isNull);
    });

    test('parses json with duration_ms and failure_reason', () {
      final scenario = CheckScenario.fromJson(const {
        'id': 'test_2',
        'title': 'Создать заявку из сообщения клиента',
        'passed': false,
        'duration_ms': 2500,
        'failure_reason': 'выбрал не тот инструмент',
      });

      expect(scenario.id, 'test_2');
      expect(scenario.name, 'Создать заявку из сообщения клиента');
      expect(scenario.passed, isFalse);
      expect(scenario.durationSeconds, 2.5);
      expect(scenario.failureReason, 'выбрал не тот инструмент');
    });

    test('handles fallback aliases for error and reason', () {
      final scenario1 = CheckScenario.fromJson(const {
        'name': 'Сценарий А',
        'success': false,
        'reason': 'недостаточно прав',
      });
      expect(scenario1.failureReason, 'недостаточно прав');

      final scenario2 = CheckScenario.fromJson(const {
        'name': 'Сценарий Б',
        'status': 'passed',
      });
      expect(scenario2.passed, isTrue);
    });

    test('equality and hashCode', () {
      const a = CheckScenario(
        id: '1',
        name: 'A',
        passed: true,
        durationSeconds: 1,
      );
      const b = CheckScenario(
        id: '1',
        name: 'A',
        passed: true,
        durationSeconds: 1,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('AssistantCheckReport', () {
    test('notRun report has hasRun == false and empty scenarios', () {
      const report = AssistantCheckReport.notRun();
      expect(report.hasRun, isFalse);
      expect(report.isRunning, isFalse);
      expect(report.totalCount, 0);
      expect(report.passedCount, 0);
      expect(report.failedCount, 0);
      expect(report.lastRunAt, isNull);
    });

    test('parses full json report matching mock', () {
      final json = {
        'status': 'completed',
        'last_run_at': '2026-09-04T06:40:00Z',
        'scenarios': [
          {
            'id': '1',
            'name': 'Найти заказ по нечёткому описанию',
            'passed': true,
            'duration_seconds': 1.2,
          },
          {
            'id': '2',
            'name': 'Проверить остаток материала',
            'passed': true,
            'duration_seconds': 0.8,
          },
          {
            'id': '3',
            'name': 'Создать заявку из сообщения клиента',
            'passed': false,
            'reason': 'выбрал не тот инструмент',
          },
          {
            'id': '4',
            'name': 'Отказать в опасном действии',
            'passed': true,
            'duration_seconds': 1.1,
          },
        ],
      };

      final report = AssistantCheckReport.fromJson(json);
      expect(report.hasRun, isTrue);
      expect(report.isRunning, isFalse);
      expect(report.totalCount, 4);
      expect(report.passedCount, 3);
      expect(report.failedCount, 1);
      expect(report.lastRunAt, isNotNull);
      expect(report.scenarios[2].failureReason, 'выбрал не тот инструмент');
    });

    test('recognizes running status', () {
      final json = {
        'status': 'running',
      };
      final report = AssistantCheckReport.fromJson(json);
      expect(report.isRunning, isTrue);
    });
  });
}
