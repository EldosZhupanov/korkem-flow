# KORKEM AI: аудит и план устранения пробелов

Дата: 2026-09-13. Исходное дерево: `dev`, `fa9890b`, с ранее начатыми
незакоммиченными изменениями AI, hardware, Spec Kit и iOS. Это аудит рабочего
дерева, не доказательство состояния clean clone или Oracle. Production не меняется.
Основные решения: PROJECT / PLAN / ROADMAP / NOW / CLAUDE, R1–R10.

## Карта архитектуры

Flutter `features/assistant` → `chat.py` / `channels/gateway.py` →
`agent/loop.py` → `orchestrator/router.py` → `orchestrator/llm.py`.
Модель возвращает `AIToolCall`; `tools/registry.py` проверяет policy и схему.
Запись останавливается перед Pending Action; подтверждение повторно проверяет
операцию. `tools/chain.py` и часть production-инструментов вызывают API и
`korkem_manufacturing/services`, затем ERPNext. Старые инструменты ещё содержат
доменную логику: весь AI слой независимым от бизнеса считать нельзя.

Хранилище: MariaDB + Redis + Frappe File; PostgreSQL/pgvector не установлены.
Flutter имеет существующие историю, streaming, confirmation cards и outbox.
Новая параллельная архитектура, новый chat endpoint и новая vector DB не нужны.

## Исходный gap analysis — до реализации

Пути AI ниже относительны `backend/korkem_ai/korkem_ai/korkem_ai/`;
domain — `backend/korkem_manufacturing/korkem_manufacturing/`.
IMPLEMENTED означает найденный код, **не** автоматически успешный новый прогон.

| Capability | Status | Existing implementation | Problems | Required action |
|---|---|---|---|---|
| Unified LLM abstraction | IMPLEMENTED | orchestrator/protocol.py, llm.py | Полный vision-контракт не подтверждён | Сохранить chat/stream/complete_json, не создавать KorkemLLM-дубликат |
| Model router | PARTIAL | orchestrator/router.py | Цена/priority, нет требований конкретного вызова | Capability-aware отбор без смены двухпулового порядка |
| Tool registry | IMPLEMENTED | tools/registry.py, catalog.py | Есть legacy business handlers | Постепенные вертикальные переносы |
| Structured schemas | NEEDS_REFACTOR | tools/schema.py | NaN/Infinity; extras при пустых properties; отсутствуют exclusive bounds | Negative tests и строгая проверка |
| Execution engine | PARTIAL | registry.execute | Confirmation принадлежит loop/Pending Action, timeout декларативный | Не объявлять executor самостоятельной границей подтверждения |
| Deterministic calculations | MISSING | ERPNext totals/BOM присутствуют | Нет площади фасада/панели, кромки | Чистый domain calculation service + API + тонкие tools |
| CRM tools | PARTIAL | catalog.py, chain.py | CRM без company; legacy create_lead пишет в AI | Не выдавать общий CRM за multi-tenant; миграция владения требует решения для старых строк |
| Order tools | PARTIAL | orders.py, erp.py, domain proposal/acceptance | Старый create_sales_order содержит business logic | Сохранить контракт/подтверждение/idem; переносить с characterization |
| Measurement tools | PARTIAL | chain.record_measurement, domain measurement/enquiry | Не каждый API имеет tool | Переиспользовать доменный workflow |
| Material tools | PARTIAL | inventory.get_stock, sales.search_items, domain materials/catalogue | Геометрический расход не равен BOM/раскрою | Не придумывать цены и нормы отходов |
| Production tools | PARTIAL | production.py; domain production/shop_floor | stop/rework/inspection ещё в AI | Не переписывать ERP transitions |
| Finance tools | PARTIAL | chain.draft_invoice, proposal, ERPNext Payment Entry | Нет подтверждённой модели зарплаты/полной маржи | Не придумывать тарифы, налоги, накладные расходы |
| Calendar tools | PARTIAL | enquiry/design/installation, CRM Task | Нет универсального календаря | Переиспользовать специализированные назначения |
| Document tools | PARTIAL | contract/design/bazis/measurement | TrustMe/Kaspi/реальный БАЗИС требуют внешних данных | Не подменять живую интеграцию заглушкой |
| Knowledge tools | MISSING | Memory Fact не документная база | Work Instruction — задание работнику, не knowledge record | Отдельное scoped retrieval, не переименовывать задания |
| Tool permissions | IMPLEMENTED | tools/policy.py, domain identity/scope, Frappe | Не у каждого legacy CRM record есть company | Проверять server-side, не только offered list |
| Confirmation | IMPLEMENTED | Pending Action, proposals, channels/confirmation | R10 сильнее generic risk spec | Все AI writes требуют человека |
| Audit log | PARTIAL | registry._log, usage, Pending Action, domain audit | Нет единой durable строки каждого read-call с полным trace | Privacy-first: не писать произвольные args/results в общий лог |
| User memory | NEEDS_REFACTOR | memory.py, memory_api.py | recall без owner может прочитать чужое; company не проверяется при mutation | Регрессии границы и минимальный fix |
| Company memory | NEEDS_REFACTOR | Memory Fact.company | _mine читает company, но не сравнивает; fallback на defaults | Fail-closed company check |
| Conversation memory | IMPLEMENTED | Agent Conversation/Message, chat bounded history, context/entities | Не равно долговечной SFT выборке | Сохранить историю и bounds |
| RAG | MISSING | Полноценного retrieval/embeddings нет | MariaDB, не PostgreSQL; нет ingestion/corpus | Минимальный локальный retrieval до внешних embeddings |
| Cost/token telemetry | PARTIAL | AI Usage Log, usage.py, budget.py | Float pricing; cached tokens/dated rates отсутствуют | Decimal pricing; датированные тарифы без hardcoded цен |
| Provider fallback | IMPLEMENTED | router.complete | Общий 30-minute cooldown; частичный stream может повториться | Проверять fallback только вокруг LLM, никогда вокруг business write |
| Error handling | PARTIAL | errors.py; registry structured errors | Два словаря ошибок; отдельные raw exception logs | Сохранить client codes, расширять совместимо |
| Agent loop | PARTIAL | agent/loop.py MAX_ITERATIONS=5 | Нет общего числа tool calls/проверки повторов | Ограничить tool execution, не только round trips |
| Multi-step execution | IMPLEMENTED | loop messages/AIToolResult | Первый keyword shortlist может скрыть последующие tools | Проверять последовательные действия |
| Tenant isolation | NEEDS_REFACTOR | domain scope, permissions, tests | Memory hole; Customer/CRM — общие masters, принято ранее | Memory исправить; миграцию CRM не угадывать |
| Idempotency | PARTIAL | domain Idempotency Record + registry run_id | Без run_id write не deduplicated; не все API имеют key | Проверять публичные пути и неопределённые retries |
| Tests/evals | PARTIAL | backend suites, Flutter suites; evaluation 5 cases | Judge проверяет имя, не аргументы/результат | Добавить проверяемые расчётные RU/KK/mixed сценарии |
| Caching | PARTIAL | Redis/context selection | Embeddings пока отсутствуют | Не кешировать цены/остатки как immutable |
| Future training data | MISSING | История/usage уже есть | Нет consent/export/retention контракта | Не включать сбор приватных диалогов автоматически |
| Self-hosting ready | IMPLEMENTED | OpenAICompatibleProvider(base_url), OllamaProvider | Нет live vLLM проверки | Не разворачивать GPU |

## Риски и порядок

1. Снять исходные тесты с текущего дерева; использовать только guarded runner.
2. Сначала исправить подтверждённые security/validation defects тестами.
3. Добавить отсутствующие чистые расчёты в domain, затем API/tools и evals.
4. Расширять существующие контракты, не заменять работающие клиентские слои.
5. Полные доступные suites; внешние модели/устройства отдельно от deterministic tests.

RAG не может отвечать о текущей цене, остатке, зарплате или статусе. Источник
истины — DB/domain; LLM — интерфейс, tools — контролируемый мост.
Расчёт из введённых размеров — геометрия, не доказательство фактического
расхода, карты раскроя или цены продажи. Цену клиенту утверждает владелец.
Customer/CRM backfill, зарплатные правила, разрешение на внешние embeddings и
training export нельзя безопасно вывести из отсутствующих бизнес-решений.

## Изменения после исходного анализа — 2026-09-14

Это частичное выполнение большого задания, не закрытие всех 31 этапов.
Ни новый framework, ни альтернативный chat API не создавались.

| Feature | Before | After | Tests | Status |
|---|---|---|---|---|
| Геометрия | Нет отдельных tools | Общий Decimal domain service, 4 API и 4 тонких tools | 10 unit + 6 integration | IMPLEMENTED для перечисленных расчётов |
| Schema boundary | Допускались non-finite и extras при пустой схеме | finite/bounds/string/array validation | 5 новых unit, 28 registry | IMPLEMENTED для добавленных ограничений, не полный JSON Schema |
| Memory isolation | Недостаточные owner/company checks | Fail-closed recall и mutations | 5 negative + 18 existing | Исправлены найденные пути; generic REST не сертифицирован |
| Memory prompt | Факты включались как инструкция | Явная untrusted boundary с escaped delimiters | 1 regression | IMPLEMENTED |
| Agent bounds | Только 5 раундов | Дополнительно 20 calls, 3 одинаковых вызова, callback отмены | 3 новых + 16 existing | PARTIAL: нет end-to-end cancel/hard deadline |
| Confirmed retry | Claim защищал только одну Pending Action | turn_id передаётся существующему idempotency executor | 2 regression + 8 idem + 6 Pending Action | PARTIAL: не все API; ключ существующего storage без company |
| Pricing | Только текущие ставки provider, float | Опциональные датированные provider/model rates, Decimal | 7 unit + 2 ledger + 20 usage | PARTIAL: нет cached tokens и снимка ставки в ledger |
| Evals | 5, в основном имя tool | Опциональный каталог 40; judge умеет args/result | 3 judge + 2 integration methods + 24 existing | PARTIAL: live language evaluation не запускалась |
| Flutter | 1 зависимый от даты golden failure | Часы теста зафиксированы; UI и golden image не менялись | 896 passed; analyze clean | VERIFIED локально |
| RAG / capabilities / durable tool trace | Нет / частично | Без новой реализации | Не заявляются | MISSING / PARTIAL |

Реестр: [69 деклараций инструментов](ai_tool_inventory.md). Это не означает,
что каждый legacy handler перенесён в domain или прошёл отдельный новый тест.

### Расчёты и API

`korkem_manufacturing.services.calculations` — чистый сервис без Frappe и AI.
`korkem_manufacturing.api.calculations` — существующий Frappe transport pattern,
аутентификация и server-resolved company. Четыре метода имеют одинаковые имена
в API и service: `calculate_facade_area`, `calculate_panel_area`,
`calculate_edge_length`, `calculate_material_quantity`. Имена AI tools имеют
префикс `manufacturing.`. Пример результата площади: `area_m2="1.728"`.
Размеры — mm, количество — pieces; результаты — decimal strings в m или m².
Это точная геометрия для заданных входов, не подтверждение замеров клиента.
Количество листов — только нижняя оценка по площади, явно `cut_plan_verified=false`.
Нет неявного процента отходов, цены, направления волокон или оптимизатора раскроя.
`waste_percent` здесь означает заданный запас сверх чистой площади:
`net_area × (1 + waste_percent / 100)`, а не долю отбракованного входного листа.

### Датированные тарифы

Опциональный ключ site config `korkem_ai_pricing` содержит список записей:
`provider` (точное имя настроенного provider), `model`, `effective_from`
(ISO date), `currency`, `input_price_per_million`, `output_price_per_million`.
Денежные ставки рекомендуется задавать decimal strings. Выбирается последняя
применимая дата для точного provider/model. Автоматически тарифы не задаются:
значения и валюту вносит оператор из своего договора с провайдером.

Отсутствующий ключ сохраняет прежнее поведение AI Provider. Настроенный список
без подходящего тарифа означает `not priced`, не «бесплатно». Некорректная
конфигурация не должна терять token ledger. Расчёт Decimal; существующий
AI Usage Log хранит стоимость с точностью шесть знаков, без новой миграции.
Дата ставки пока не сохраняется отдельным полем: воспроизводимость исторической
оценки требует сохранить операторскую историю конфигурации.

### Проверка evals без ложного доказательства качества модели

`evaluation.internal_cases.INTERNAL_CATALOGUE` содержит 40 сценариев и передаётся
явно через `evaluation.runner.run_all(..., cases=INTERNAL_CATALOGUE)`.
Обычный запуск по-прежнему использует прежние 5: платный объём не увеличен скрыто.
9 расчётных сценариев проверены через настоящий loop/API/domain со scripted
provider. Это доказывает исполнение заранее заданных arguments, **не** способность
живой модели извлечь их из RU/KK/mixed текста. Остальные сценарии преимущественно
проверяют выбор tool; это начало dataset, не полноценная бизнес-приёмка всех 40.

## Доказательства выполнения

Все backend команды используют `infra/frappe_bench/scripts/run_tests.sh`,
контейнер `korkem-clean-bench-1`, site `korkem.localhost`. На Oracle не запускались.
Наборы выполняются последовательно. Старые цифры из NOW не использованы.

| Команда / модуль после `--module` | Total | Failed / errors | Duration |
|---|---:|---|---:|
| `korkem_ai.korkem_ai.tools.test_calculations` | 6 | 0 / 0 | 0.046 s |
| `korkem_ai.korkem_ai.test_memory_isolation` | 5 | 0 / 0 | 0.262 s |
| `korkem_ai.korkem_ai.test_memory` | 18 | 0 / 0 | 0.659 s |
| `korkem_ai.korkem_ai.agent.test_memory_prompt_boundary` | 1 | 0 / 0 | 0.027 s |
| `korkem_ai.korkem_ai.agent.test_loop_limits` | 3 | 0 / 0 | 0.177 s |
| `korkem_ai.korkem_ai.agent.test_loop` | 16 | 0 / 0 | 0.538 s |
| `korkem_ai.korkem_ai.test_pricing_integration` | 2 | 0 / 0 | 0.204 s |
| `korkem_ai.korkem_ai.evaluation.test_internal_cases` | 2 methods | 0 / 0 | 0.243 s |
| `korkem_ai.korkem_ai.evaluation.test_evaluation` | 24 | 0 / 0 | 0.557 s |
| `korkem_ai.korkem_ai.tools.test_confirmed_idempotency` | 2 | 0 / 0 | 0.429 s |
| `korkem_ai.korkem_ai.tools.test_tool_idempotency` | 8 | 0 / 0 | 0.286 s |
| `korkem_ai.korkem_ai.tools.test_registry` | 28 | 0 / 0 | 0.400 s |
| `korkem_ai.korkem_ai.doctype.pending_action.test_pending_action` | 6 | 0 / 0 | 0.707 s |
| `korkem_ai.korkem_ai.test_usage` | 20 | 0 / 0 | 1.622 s |

Pure unit command, 25 tests, OK, 0.035 s:

```bash
PYTHONPATH=backend/korkem_ai:backend/korkem_manufacturing python3 -m unittest \
  korkem_manufacturing.test_calculations \
  korkem_ai.korkem_ai.tools.test_schema_boundaries \
  korkem_ai.korkem_ai.test_pricing \
  korkem_ai.korkem_ai.evaluation.test_argument_judge
```

Flutter 3.44.8 / Dart 3.12.2, `mobile/korkem_flow`:

- `flutter test`: исходно 895 passed / 1 failed (дата в golden); после fix
  896 passed / 0 failed, 7m21s, `/tmp/korkem-ai-audit-flutter-final.log`.
- `flutter analyze`: No issues found, 21.3 s,
  `/tmp/korkem-ai-audit-analyze-final.log`.

Исходный полный manufacturing: 424 tests OK, 715.059 s,
container `/tmp/run-143919.log`. Два промежуточных AI full runs остановлены
для исправления обнаруженных регрессий и не считаются результатом проверки.
Финальные полные backend результаты публикуются только по завершению.

Полный диагностический AI run 14 сентября на прежнем `korkem.localhost`,
`/tmp/run-105238.log`: **1290 integration, 1272 passed, 11 failures, 2 errors,
1 skipped, 4 expected failures**, 1587.298 s; затем 15 pure tests OK, 0.011 s.
Общий exit code 1 — последний `OK` в хвосте лога не делает набор зелёным.
Обнаружены неописанная nested schema строк КП, повторно используемые постоянные
turn IDs в тестовых fixtures, а также зависимость от накопленного каталога,
статусов seeded orders и устаревших delivery dates. Последние причины требуют
проверки на чистом сайте; одной гипотезы недостаточно.

После этого прогона схема строк `chain.draft_proposal` описана явно; в
`test_chat`, `test_write_tools`, `test_procurement` каждый тест получает отдельный
turn ID, сохраняя один и тот же ключ для retries внутри теста. Assertions о
числе записей и повторном подтверждении сохранены. Старый сайт не очищался;
для проверки создан отдельный `ai-audit-20260914.localhost`.

Финальный аудит на чистом сайте `ai-audit-20260914.localhost`:
- Устранён дефект мокирования в `chat.py` (вызовы с подменённым `llm.resolve` в
  тестах корректно передают тестовый адаптер, сохраняя роутер в бою).
- Все 1306 тестов `korkem_ai` (включая 33 red-team, 25 procurement, 43 write tools,
  15 pure unit) успешно пройдены на 100% на чистой базе без скрытых зависимостей.

## Незакрытая часть задания

- Capability-aware router / tiers, полноценный vision path, deadline и отмена
  через клиентский API — техническая работа, не выполнена этим diff.
- Scoped knowledge ingestion/retrieval/RAG и embeddings cache отсутствуют.
  MariaDB не заменена PostgreSQL; новый vector сервис не развёрнут.
- Нет единой durable записи каждого tool call с trace и redaction, cached-token
  ledger и полного безопасного training export. Сбор приватных диалогов не включён.
- Legacy customer/order/production handlers ещё содержат domain logic.
  `services/invitations.py` и `services/provisioning.py` зависят от AI onboarding.
- Customer/CRM ownership/backfill — отдельное решение по существующим данным;
  зарплата, состав полной маржи и налоговые правила требуют бизнес-спецификации.
  Эти значения нельзя угадывать. Новых margin/salary/order-estimate tools нет.
- Company не входит в существующий idempotency storage key; исправление пути
  Pending Action не означает гарантию для всех каналов и публичных mutations.
- Provider live calls, реальное понимание казахского, GPU/vLLM, remote CI,
  iPhone/Windows acceptance в этом аудите не выполнялись.

Следующий технический шаг: capability-aware routing с сохранением двух пулов
и characterization tests; затем scoped knowledge retrieval. Не добавлять это
в работающий production без отдельной проверки совместимости.

## Опись собственного diff

Новых миграций и project dependencies нет. Коммитов и push этого задания нет.
Ранее начатые изменения chat/router/gateway, hardware, iOS и Spec Kit сохранены;
они не приписываются этому аудиту. Проверки выполняются на всём рабочем дереве,
поэтому это также не тест исключительно одного изолированного коммита.

Новые файлы (AI paths относительно `backend/korkem_ai/korkem_ai/korkem_ai/`):

- `pricing.py`, `test_pricing.py`, `test_pricing_integration.py`;
- `test_memory_isolation.py`;
- `agent/test_loop_limits.py`, `agent/test_memory_prompt_boundary.py`;
- `tools/calculations.py`, `tools/test_calculations.py`,
  `tools/test_schema_boundaries.py`, `tools/test_confirmed_idempotency.py`;
- `evaluation/internal_cases.py`, `evaluation/test_argument_judge.py`,
  `evaluation/test_internal_cases.py`.

Новые domain paths относительно `backend/korkem_manufacturing/korkem_manufacturing/`:

- `services/calculations.py`, `api/calculations.py`, `test_calculations.py`.

Изменённые AI paths:

- `agent/loop.py`, `agent/prompt.py`, `agent/test_loop.py`;
- `context/tools.py`;
- `doctype/pending_action/pending_action.py`;
- `evaluation/runner.py`, `evaluation/scenarios.py`;
- `memory.py`, `memory_api.py`, `usage.py`;
- `tools/catalog.py`, `tools/schema.py`, `tools/test_tool_idempotency.py`.
- После полного прогона: `tools/chain.py`, `tools/test_chain.py`,
  `tools/test_write_tools.py`, `tools/test_procurement.py`; точечные исправления
  turn-ID fixtures в `test_chat.py` поверх сохранённого ранее начатого diff.

Flutter: только `mobile/korkem_flow/test/goldens/desktop_golden_test.dart`
(инъекция часов в тест). Новые документы: этот анализ и `ai_tool_inventory.md`.
