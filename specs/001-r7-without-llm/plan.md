# План: R7 без подмены производственной операции

Дата: 2026-09-09. [Spec](spec.md). Корневой [PLAN](../../PLAN.md) имеет приоритет.

## Решение и существующий код

Расширить backend/korkem_manufacturing/korkem_manufacturing/test_without_llm.py.
Сохранить быстрые тесты обёрток, добавить отдельный IntegrationTestCase с
реальными API production/purchasing/dispatch и ERPNext.
before_tests вызывает setup.provision; demo seed нужен один раз до тестовой
транзакции. Не наследовать старые _BuyingTestCase/_ProductionTestCase: их
cleanups коммитят и удаляют широкие множества документов.
Создавать копии Sales Order и свой Material Request в транзакции; после каждого
теста rollback. В тесте запрещён commit. Снимок остатков через Bin нужен только
для чтения, движение всегда через ERPNext Stock Entry.

## Проверка конституции

| R | Применимость и доказательство |
|---|---|
| R1 | AST всех API и семи модулей пяти действий/общего доступа. Общий аудит services нашёл две отдельные инверсии; см. research.md |
| R2 | Пять вызовов существующих API, настоящий сервис и ORM |
| R3 | Существующие endpoints сохраняются; UI/tool adapters не меняются |
| R4 | Отказ при current_company другого реального пользователя |
| R5 | N/A: роли не меняются; тестовый пользователь с минимальным доступом |
| R6 | Только локальный тестовый стенд, синтетические fixtures |
| R7 | Пять ERP-результатов при выключенном AI + ловушки resolve/get_provider |
| R8 | N/A: не моделируем отсутствие интернета; не утверждаем offline E2E |
| R9 | Реальные permission checks и Comment assertions |
| R10 | N/A: вызовы человеком, AI confirmation-путь не изменяется |

## Границы транзакций и повторов

Существующие savepoint и idempotency_key не заменяются.
Все пять действий повторяются с тем же ключом. Первая и повторная запись
сверяются по результату, счётчикам, количествам и аудиту.
Никаких broad cleanup, commit, реальных сообщений или реальных ключей.

## Матрица проверки

| FR | Задача | Наблюдаемое доказательство |
|---|---|---|
| FR-001 | T002 | Work Order, Stock Entry, Stock Ledger Entry, Bin |
| FR-002 | T002 | Job Card, Work Order Operation |
| FR-003 | T003 | Purchase Order, rate, qty, Material Request |
| FR-004 | T003 | Purchase Receipt, received_qty, Bin, ledger |
| FR-005 | T004 | Delivery Note, delivered_qty, Bin, ledger |
| FR-006 | T002–T004 | AI disabled, провайдерные mocks assert_not_called |
| FR-007 | T002–T004 | replay + неизменность ERP-снимка |
| FR-008 | T005 | реальный пользователь без прав / с другой компанией |
| FR-009 | T002–T005 | Comment, guard commit, rollback |
| FR-010 | T006 | targeted дважды, mutation, full suite |

## Выполнение

Один bench korkem-clean-bench-1, сайт korkem.localhost.
Команды в quickstart.md. Сначала проверка нового модуля, затем мутация
outage-защиты в самом тесте через временную подмену вызова, затем полный
korkem_manufacturing. Миграции и Flutter-прогоны не нужны: изменений runtime/Dart
не планируется. Если тесты найдут продуктовый дефект, план уточняется до фикса.

## Оценка

Baseline 0/5 ERP-доказательств уже известен. Дополнительные пробелы уточнения:
фиктивная проверка аудита, повторов и scope; риск commit из заимствованных
fixtures; AST не покрывает services. Записывать изменения после первого запуска
отдельно от уточнений до кода. Метрики: покрытие FR, число содержательных
переделок тестов, число собственных документов процесса, измеренное время
проверок. Сравнимого baseline времени разработки нет.
