# ОТЧЁТ ОБ УКРЕПЛЕНИИ АРХИТЕКТУРНОГО ФУНДАМЕНТА (P0 HARDENING GATE REPORT)
## Верификация надежности, конкурентной безопасности, изоляции арендаторов и целостности KORKEM v2

**Дата:** 16 сентября 2026 г.  
**Роль:** Principal Software Architect, Staff Engineer  
**Продукт:** KORKEM Flow v2  
**Ветка:** `dev`  
**Статус шлюза:** **PASSED / GO ДЛЯ ФАЗЫ 3 (Phase 3)**  

---

## 1. НАЙДЕННЫЕ ДЕФЕКТЫ И УЯЗВИМОСТИ (DEFECTS FOUND)

В ходе стресс-тестирования и аудита реализации P0 были выявлены и устранены следующие критические дефекты:

1. **Outbox: Отсутствие изолированного учета доставки подписчикам (Subscribers Side-Effect Replay):**  
   *Дефект:* В исходной реализации `services/outbox.py` статус выполнения фиксировался только на уровне всего события (`Domain Outbox Event`). Если подписчик А (отправка WhatsApp) отрабатывал успешно, а подписчик B (синхронизация с внешней CRM) падал, при повторном запуске воркера подписчик А вызывался повторно, создавая дублирующие сообщения клиенту.
2. **Tenant Isolation: Небезопасная проверка `belongs_to_company` при `company is None`:**  
   *Дефект:* В `services/scope.py` функция `belongs_to_company` содержала условие `return company is None or company == current_company()`. Для несуществующих или угаданных ID документов (`SAL-ORD-GUESSED-999`) вызов `frappe.db.get_value` возвращал `None`, из-за чего функция возвращала `True` вместо отказа! Система пропускала угаданные ID вместо fail-closed отказа.
3. **Отсутствие блокировки строк при переходе состояний (Race Condition в FSM):**  
   *Дефект:* Два параллельных HTTP-запроса могли одновременно прочитать заказ в состоянии `Draft` и оба попытаться выполнить перевод в разные целевые состояния (`Lead` и `Cancelled`), минуя валидацию графа переходов.
4. **Idempotency: Коллизия ключей между разными арендаторами:**  
   *Дефект:* Имя записи `Idempotency Record` вычислялось как `sha256(user + action + key)`. Если два пользователя из разных мебельных фабрик генерировали одинаковый UUID ключа в мобильном оффлайн-клиенте, возникала межтенантная коллизия.
5. **AI Registry: Отсутствие аппаратного запрета на вызов критических инструментов без аппрува:**  
   *Дефект:* Ранее `requires_confirmation` проверялся только на уровне внешнего цикла агента. При прямом вызове `execute()` инструмент с риском `CRITICAL_WRITE` (`quote.send`, `contract.issue`, `payment.record`) мог выполнить побочный эффект в обход Human-in-the-Loop.
6. **Уязвимость аудита к модификации и удалению:**  
   *Дефект:* Документ `Domain Audit Event` не имел жестких хуков `before_save` и `on_trash`, что теоретически позволяло пользователям с правами `System Manager` или скриптам изменять исторические записи аудита.

---

## 2. ВНЕДРЕННЫЕ ИСПРАВЛЕНИЯ И АРХИТЕКТУРНЫЕ ИЗМЕНЕНИЯ (EXACT FIXES)

### 2.1 Outbox Correctness: Per-Consumer Delivery Ledger & Worker Leasing
- Внедрен новый DocType `Domain Outbox Delivery` с полями: `event_id`, `consumer_name`, `company`, `status`, `attempts`, `max_attempts`, `lease_token`, `lease_expires_at`, `next_retry_at`, `processed_at`, `error_message`, `correlation_id`.
- Первичный ключ доставки формируется детерминированно: `del-{sha256(event_id + ':' + consumer_name)[:20]}`, что на уровне MariaDB гарантирует `UNIQUE(event_id, consumer_name)`.
- Реализован **Worker Leasing (Distributed Row Lock)**:
  Воркер захватывает доставку через `SELECT ... FOR UPDATE`, проверяя `(lease_expires_at IS NULL OR lease_expires_at <= NOW())`. Если другой воркер уже удерживает лизинг, запрос пропускает строку (`skipped_conflicts`).
- При сбое подписчика:
  - Исходный savepoint откатывается.
  - Увеличивается счетчик `attempts += 1`.
  - Вычисляется экспоненциальный retry backoff с джиттером: $2^{\text{attempts}} \times 5\text{с} + \text{jitter}$.
  - При `attempts >= 5` статус переходит в `Dead Letter` (DLQ).
- Добавлен API повтора из DLQ: `replay_event(event_id)` и `replay_delivery(delivery_name)`.

### 2.2 Fail-Closed Tenant Isolation Guard
- В `services/scope.py` переписана функция `belongs_to_company`:
  - Проверяет физическое существование документа `frappe.db.exists(doctype, name)` — несуществующие/угаданные ID возвращают `False`.
  - Проверяет наличие поля `company` через метаданные.
  - Если поле `company` отсутствует или не совпадает с `current_company()`, возвращается `False`.
- `ensure_company(doctype, name)` выбрасывает `frappe.PermissionError` (fail-closed).
- Добавлена функция `enforce_tenant_scope(entity_company, caller_company=None)` с проверкой на отсутствие контекста.

### 2.3 Global API Idempotency с изоляцией арендаторов
- В `Idempotency Record` добавлен столбец `company`.
- Формула ключа стала строго тенантно-изолированной: `_record_name(user, action, key, company)`.
- Внедрена функция очистки устаревших записей `cleanup_expired(days=30)`.
- Повторные запросы с тем же payload возвращают закешированный результат; запросы с тем же ключом, но другим payload, выбрасывают `frappe.ValidationError` (Conflict).

### 2.4 Hardened AI Domain Tool Registry & R10 Approval Gates
- Создан `backend/korkem_ai/korkem_ai/korkem_ai/tools/domain_registry.py`.
- Классификация рисков: `READ`, `REVERSIBLE_WRITE`, `CRITICAL_WRITE`.
- Все критические инструменты (`quote.send`, `contract.issue`, `payment.record`, `payment.refund`, `production.release`, `order.cancel`, `payroll.adjust`, `inventory.write_off`) зарегистрированы со строгими Pydantic-схемами (`gt=0`, `min_length`).
- **Enforced Approval Gate:** если инструмент критический, `execute()` блокирует выполнение и автоматически создает `Pending Action`. Side effect выполняется только при наличии валидного `approval_token` со статусом `Approved`.
- Запрет отрицательных сумм, размеров и попыток подмены компании.

### 2.5 State Machine Concurrency (Row Locking & Optimistic Concurrency)
- В `order_state.transition(...)` внедрен захват эксклюзивной блокировки строки:
  `frappe.db.get_value("Sales Order", sales_order, ..., for_update=True)`.
- Поддержка `expected_state`: если клиент передал устаревший статус, запрос отклоняется с понятной ошибкой: `frappe.ValidationError("Конфликт конкурентного обновления: ожидалось состояние X, но текущее состояние Y...")`.

### 2.6 Immutability & Append-Only Audit Trail
- В `Domain Audit Event` добавлены контроллеры `before_save` (запрет `doc.save()` для существующих записей) и `on_trash` (запрет удаления).
- Добавлено поле `trace_id` для сквозной трассировки агентских вызовов.

---

## 3. ВЫПОЛНЕННЫЕ МИГРАЦИИ БАЗЫ ДАННЫХ (DB MIGRATIONS)

Все миграции успешно применены через `bench migrate` на сайте `korkem.localhost`:
1. Создана таблица `tabDomain Outbox Delivery` с индексами на `event_id`, `consumer_name`, `company`, `status`.
2. В таблицу `tabIdempotency Record` добавлен столбец `company` (Link -> Company).
3. В таблицу `tabDomain Audit Event` добавлен столбец `trace_id` (Data).
4. В таблицу `tabSales Order` добавлен столбец `korkem_state` (Select с 20 каноническими статусами).

---

## 4. СВОДНАЯ МАТРИЦА ТЕСТИРОВАНИЯ (TEST MATRIX & VERIFICATION)

Все тесты запущены в чистом изолированном Docker-контейнере `korkem-clean-bench-1`:

| Тестовый модуль | Проверяемые сценарии отказа и инварианты | Кол-во тестов | Результат |
|---|---|---|---|
| **`test_outbox_hardening.py`** | Crash после commit, изоляция подписчиков A/B, duplicate dispatch, worker leasing lock, stale lease recovery, retry exhaustion -> DLQ, DLQ manual replay, UNIQUE constraint per consumer | 8 | **8 / 8 PASSED (OK)** |
| **`test_tenant_isolation.py`** | Запрет чтения чужой компании, запрет мутации чужого заказа, fail-closed на угаданных ID, отсутствие контекста компании, AI cross-tenant block, изоляция automation rules, сохранение скоупа в outbox | 7 | **7 / 7 PASSED (OK)** |
| **`test_idempotency_concurrency.py`** | Повтор с тем же payload (кэш), повтор с другим payload (конфликт), изоляция ключей между компаниями A и B, retention cleanup policy (30 дней) | 4 | **4 / 4 PASSED (OK)** |
| **`test_order_concurrency.py`** | Оптимистический конфликт устаревшего экрана (stale expected_state), конфликт одновременного перевода и отмены, идемпотентный production release, полный откат (rollback) при сбое side effect | 4 | **4 / 4 PASSED (OK)** |
| **`test_audit_integrity.py`** | Запрет обновления существующего аудита (append-only), запрет удаления (immutable), фиксация всех обязательных измерений (actor, company, correlation_id, trace_id, diff_json) | 3 | **3 / 3 PASSED (OK)** |
| **`test_order_state.py`** | Полнота 20 канонических состояний FSM, терминальность Cancelled, переходы Draft->Lead, API get_state, list_available_transitions, валидация предусловий | 8 | **8 / 8 PASSED (OK)** |
| **`test_automation_engine.py`** | Листовые операторы предикатов (==, !=, >, <, in, contains, is_set), составные условия AND/OR/NOT, шаблонизация параметров {{order_id}}, защита от рекурсии (depth > 3) | 5 | **5 / 5 PASSED (OK)** |
| **`test_registry_security.py`** | Отказ на неизвестный инструмент, отказ на чужую компанию, Human-in-the-Loop R10 остановка с созданием Pending Action для critical tools, отказ на отрицательные суммы/размеры, повторный вызов с кэшированием, выполнение подтвержденного действия | 6 | **6 / 6 PASSED (OK)** |
| **`test_reminders.py`** | Доставка напоминаний владельцу цеха, дедупликация событий, работа подписчиков доменных событий | 6 | **6 / 6 PASSED (OK)** |
| **Flutter Analyze** | Статический анализ мобильного и десктопного кода `mobile/korkem_flow` | 100% файлов | **No issues found! (0 warnings, 0 errors)** |

**ИТОГО ПО НОВЫМ P0 ТЕСТАМ:** **51 тест из 51 пройден успешно (100% PASS RATE)**.

---

## 5. ОСТАЮЩИЕСЯ РИСКИ И МЕРЫ СНИЖЕНИЯ (REMAINING RISKS & MITIGATION)

1. **Длительная сетевая недоступность внешних сервисов (WhatsApp / Банки):**  
   *Риск:* Доставки будут переходить в `Dead Letter` при отключении интернета в цехе дольше, чем 5 попыток экспоненциального backoff (~3 минуты).  
   *Миграция:* Внедрена функция `replay_event(event_id)`, позволяющая после восстановления связи перезапустить пачку доставок из DLQ в один клик.
2. **Нагрузка на таблицу `tabDomain Audit Event`:**  
   *Риск:* При объеме 100 000 заказов в год таблица аудита вырастет до сотен тысяч строк.  
   *Миграция:* Таблица снабжена индексами по `(entity_type, entity_id)` и `creation`, не участвует в OLTP-джойнах и готова к партиционированию по годам/месяцам.

---

## 6. ЗАКЛЮЧЕНИЕ И РЕШЕНИЕ (GATE DECISION)

Все обязательные критерии **P0 HARDENING GATE** выполнены в полном объеме:
- [x] Исключены любые обходные пути cross-tenant чтения и записи (Fail-Closed).
- [x] Устранены риски повторного выполнения side effects в Outbox (Per-Consumer Ledger).
- [x] Внедрена конкурентная защита переходов стейт-машины (Row Locks + Optimistic Concurrency).
- [x] Обеспечена глобальная тенантно-изолированная идемпотентность API.
- [x] AI-инструменты жестко ограничены `DomainToolRegistry` с Pydantic-схемами и обязательным аппрувом критических операций (R10).
- [x] Аудит стал строго неизменяемым (Append-Only).
- [x] Никаких новых продуктовых функций до закрытия гейта не добавлялось.
- [x] 100% тестов зеленые, `flutter analyze` — чисто.

### **ИТОГОВОЕ РЕШЕНИЕ: GO ДЛЯ ПЕРЕХОДА К СЛЕДУЮЩЕЙ ФАЗЕ.**
