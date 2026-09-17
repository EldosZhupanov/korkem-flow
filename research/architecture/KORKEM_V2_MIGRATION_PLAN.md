# Поэтапный план миграции KORKEM Flow v2 (Migration Roadmap)

**Дата:** 2026-09-16  
**Версия:** 2.0  
**Принцип:** ZERO BIG-BANG REWRITES. Инкрементальное внедрение улучшений без нарушения работы существующего Flutter-клиента, без изменения визуального UI и с сохранением полной обратной совместимости существующих API-эндпоинтов.

---

## 1. Обзор этапов миграции (Migration Phases Overview)

```
[Phase 0: Invariants & Baseline Tests]
       │
       ▼
[Phase 1: Domain Foundation & Order State Machine]  <── P0 Implementation
       │
       ▼
[Phase 2: Transactional Outbox & Event Bus]         <── P0 Implementation
       │
       ▼
[Phase 3: Manufacturing Model & Offcut Management]
       │
       ▼
[Phase 4: Durable Job Engine & Step Checkpoints]
       │
       ▼
[Phase 5: Strict AI Tool Registry & Safety Gates]   <── P0 Implementation
       │
       ▼
[Phase 6: Furniture Automation Engine]
       │
       ▼
[Phase 7: AI Observability & Product Analytics]
       │
       ▼
[Phase 8: Offline Mobile Read Cache Enhancements]
```

---

## 2. Детальное описание фаз миграции

### Phase 0: Фиксация инвариантов и регрессионный базис (Invariants & Baseline)
- **Цель:** Зафиксировать поведение текущей системы тестами до внесения любых изменений в рабочий код.
- **Затрагиваемые файлы:** `test_without_llm.py`, `test_api_*.py`, `desktop_golden_test.dart`.
- **Изменения в БД:** Отсутствуют.
- **Влияние на фронтенд:** Нулевое.
- **Тесты:** Прогон полного набора `korkem_manufacturing` (426 тестов) и `flutter test` (896 тестов).

---

### Phase 1: Доменный фундамент и канонический Order State Machine (P0 Foundation)
- **Цель:** Прекратить фрагментацию состояний заказа по 12 сервисам. Ввести централизованный `OrderStateMachine` с проверкой допустимости переходов и прав ролей.
- **Затрагиваемые файлы:**
  - Создание: `korkem_manufacturing/services/order_state.py`;
  - Создание: `korkem_manufacturing/api/order_state.py`;
  - Интеграция: `services/capture.py`, `services/enquiry.py`, `services/proposal.py`, `services/contract.py`, `services/production.py`, `services/dispatch.py`, `services/acceptance.py`, `services/warranty.py`.
- **Изменения в БД:**
  - Создание DocType `Order State Log` (фиксация `from_state`, `to_state`, `actor`, `timestamp`, `reason`).
- **Влияние на API:** Полная обратная совместимость: существующие эндпоинты (`production.start`, `dispatch.deliver`, `acceptance.sign`) сохраняют свои сигнатуры, но внутри делегируют проверку переходов в `OrderStateMachine`.
- **Влияние на фронтенд:** Нулевое (существующие экраны заказов работают без изменений; мобильное приложение получает более понятные и консистентные ошибки при невалидных переходах).
- **План отката:** Флаг отключения строгой проверки в настройках сайта: `order_state_machine_strict=False`.

---

### Phase 2: Транзакционный Outbox и событийно-ориентированная шина (P0 Reliability)
- **Цель:** Устранить проблему потери событий и фантомных уведомлений при откатах транзакций.
- **Затрагиваемые файлы:**
  - Создание: `korkem_manufacturing/services/outbox.py`;
  - Модификация: `korkem_manufacturing/domain_events.py` (переключение с синхронного вызова на запись в Outbox в транзакции);
  - Создание фонового воркера: `korkem_manufacturing/tasks/outbox_dispatcher.py`.
- **Изменения в БД:**
  - Создание DocType `Domain Outbox Event` (поля: `event_name`, `aggregate_type`, `aggregate_id`, `payload_json`, `processed`, `retry_count`, `error_log`).
- **Влияние на фронтенд:** Нулевое.
- **План отката:** При сбое воркера fallback на прямой вызов подписчиков с логированием ошибок.

---

### Phase 3: Усиление мебельного домена (Деловой остаток и сдельная оплата)
- **Цель:** Автоматизировать учет обрезков плит ЛДСП и расчет сдельной оплаты мастеров за раскрой и кромление.
- **Затрагиваемые файлы:**
  - `korkem_manufacturing/services/shop_floor.py`;
  - `korkem_manufacturing/services/warehouse.py`;
  - DocType `Stock Offcut` (деловой остаток).
- **Влияние на фронтенд:** Добавление полей длины/ширины обрезка в диалог закрытия раскроя на терминале цеха без ломки основного интерфейса.

---

### Phase 4: Отказоустойчивые фоновые задачи (Step Checkpointing)
- **Цель:** Исключить падения тяжелого импорта БАЗИС XML и смет.
- **Затрагиваемые файлы:**
  - `korkem_manufacturing/services/durable_jobs.py`;
  - `korkem_manufacturing/services/bazis.py`.
- **Изменения в БД:** DocTypes `Durable Job Run` и `Durable Step Run`.

---

### Phase 5: Строгий AI Tool Registry и барьеры безопасности (P0 AI Safety)
- **Цель:** Гарантировать соблюдение инвариантов R1, R2, R10: очистить AI-инструменты от остатков доменной логики, ввести строгие Pydantic-схемы и обязательное подтверждение для финансовых/производственных мутаций.
- **Затрагиваемые файлы:**
  - `korkem_ai/tools/registry.py`;
  - `korkem_ai/tools/domain_bridge.py`;
  - Очистка legacy-инструментов: `orders.py`, `production.py`, `buying.py`.
- **Изменения в БД:** Добавление поля `trace_id` в `tabPending Action` и `tabAI Usage Log`.
- **Влияние на фронтенд:** Нулевое: мобильные карточки подтверждения (`PendingActionCard`) получают строго типизированный контекст.

---

### Phase 6: Доменный движок бизнес-правил цеха (Automation Engine)
- **Цель:** Дать возможность настраивать правила цеха без программирования.
- **Затрагиваемые файлы:**
  - `korkem_manufacturing/services/automation/`;
  - DocTypes `Automation Rule` и `Automation Run`.

---

### Phase 7: AI Observability и продуктовая аналитика
- **Цель:** Сквозная трассировка стоимости AI и выявление узких мест в воронке производства.
- **Затрагиваемые файлы:**
  - `korkem_ai/tracing.py`;
  - `korkem_manufacturing/services/analytics.py`.

---

### Phase 8: Усиление офлайн-кеша мобильного клиента
- **Цель:** Кеширование карточек назначенных замеров на устройстве замерщика для чтения при отсутствии связи.
- **Затрагиваемые файлы во Flutter:**
  - `mobile/korkem_flow/lib/features/enquiry_flow/`;
  - `mobile/korkem_flow/lib/core/api/mutation_outbox.dart`.
