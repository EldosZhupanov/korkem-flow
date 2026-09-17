# Задачи: R7

Источники: [spec](spec.md), [plan](plan.md).
Порядок: T001 → T002 → T003 → T004 → T005 → T006 → T007. Один агент.

- [x] T001 Зафиксировать baseline и FR в specs/001-r7-without-llm/spec.md и plan.md.
- [x] T002 [US1] Добавить реальные запуск и закрытие операции с replay/audit в backend/korkem_manufacturing/korkem_manufacturing/test_without_llm.py (FR-001,002,006,007,009).
- [x] T003 [US1] Добавить реальные закупку и приёмку с ERP assertions в том же test_without_llm.py (FR-003,004,006,007,009).
- [x] T004 [US1] Добавить реальную отгрузку с ledger/replay/audit в том же test_without_llm.py (FR-005,006,007,009).
- [x] T005 [US2] Добавить отказы прав/компании и расширить AST на services в том же test_without_llm.py (FR-008, R1).
- [x] T006 Выполнить targeted дважды, mutation и full suite из specs/001-r7-without-llm/quickstart.md (FR-010).
- [x] T007 Записать измерения в specs/001-r7-without-llm/evaluation.md, обновить NOW.md и ROADMAP.md.
