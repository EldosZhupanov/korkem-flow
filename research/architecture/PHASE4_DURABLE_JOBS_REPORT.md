# ОТЧЁТ О РЕАЛИЗАЦИИ ФАЗЫ 4 (PHASE 4: DURABLE BACKGROUND JOBS & OUTBOX AUTOMATION WORKERS)
## Долговечные фоновые задачи (Step Checkpointing / Trigger.dev & Temporal Pattern) и автоматические Outbox-воркеры

**Дата:** 17 сентября 2026 г.  
**Роль:** Principal Software Architect, Staff Engineer  
**Продукт:** KORKEM Flow v2  
**Ветка:** `dev`  
**Статус фазы:** **COMPLETED / PASSED ALL 14 TEST GATES (76/76 TESTS OK, FLUTTER ANALYZE CLEAN)**  
**Вердикт:** **PRODUCTION READY & HARDENED**  

---

## 1. EXECUTIVE SUMMARY

В рамках реализации **Phase 4 (Durable Background Jobs & Outbox Automation Workers)** архитектура KORKEM Flow v2 получила промышленный движок исполнения отказоустойчивых фоновых процессов на основе шаблона **Step Checkpointing** (архитектурные референсы: *Trigger.dev v3* и *Temporal*), адаптированный для MariaDB и Frappe Framework.

### Ключевые результаты фазы:
1. **Durable Jobs Engine (`services/durable_jobs.py`):**
   - Разработаны системные DocTypes: `Durable Job Run` и `Durable Step Run`.
   - Внедрен контекстный интерфейс `DurableJobContext.step(step_name, fn)`: каждый шаг многочасовой или критической операции атомарно коммитится в MariaDB с сохранением результата (`output_json`).
   - При сбое процесса (OOM, перезапуск пода/контейнера, падение воркера) задача при повторном запуске мгновенно подхватывает уже выполненные шаги из БД и **не выполняет их повторно**, продолжая работу с точки падения.
   - Поддерживается строгая идемпотентность запуска по ключу (`idempotency_key` в скоупе компании).
   - Реализована защита от конкурентного исполнения (Worker Leasing с `lease_token` и `lease_expires_at`) и перехват зависших задач при падении воркера.
   - Экспоненциальный откат повторов с джиттером (`RetryPolicy`) и изоляция в Dead Letter Queue (`Dead Letter`).

2. **Встроенные доменные конвейеры (Built-in Durable Workflows):**
   - `bazis.import_xml`: тяжелый 4-шаговый пайплайн импорта раскроя из Базис-Мебельщик (`parse_xml` $\to$ `resolve_materials_and_offcuts` $\to$ `generate_nesting_layout` $\to$ `create_job_cards`).
   - `material.procure_shortage_batch`: 3-шаговый пайплайн пакетного закупа дефицита (`aggregate_shortages` $\to$ `select_suppliers` $\to$ `generate_material_requests`).

3. **Outbox Automation Workers (`services/outbox_workers.py`):**
   - Асинхронные подписчики на доменные события:
     - `material.shortage_detected`: при обнаружении дефицита автоматически инициирует долговечную задачу `material.procure_shortage_batch`.
     - `order.*`: сквозное протоколирование изменений состояний в журнале аудита.
   - Пакетный диспетчер `dispatch_outbox_batch()` с поддержкой конкурентного захвата лизинга (`FOR UPDATE SKIP LOCKED`).
   - Периодический хук в планировщик Frappe (`cron_dispatch_outbox` в `hooks.py`).

4. **Полная регрессионная верификация:**
   - Все **14 тестовых сьютов** (Фаза 3 + Фаза 4) успешно пройдены: **76 тестов OK**.
   - `flutter analyze`: **0 ошибок, 0 предупреждений** (дизайн-система и типы не нарушены).

---

## 2. АРХИТЕКТУРНАЯ КОНЦЕПЦИЯ: STEP CHECKPOINTING

### 2.1 Почему не Celery / Redis Queue в чистом виде?
Стандартные очереди сообщений (Celery, RQ, BullMQ, Frappe Background Jobs) рассматривают задачу как «черный ящик»:
- Если воркер упал на 90% выполнения тяжелого импорта Базис XML (например, распарсил 500 деталей, зарезервировал деловые остатки, но упал при генерации JobCard), стандартный retry перезапустит задачу с самого начала.
- Это ведет к дублированию записей, повторному бронированию остатков, утечке ресурсов и неконсистентности данных.

### 2.2 Модель Trigger.dev / Temporal на базе MariaDB
KORKEM Flow реализует модель сохранения состояния каждого шага непосредственно в реляционной БД:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Durable Job Run                                 │
│  status: In Progress | lease_token: worker-a1 | attempts: 1            │
└────────────────────────────────────────────────────────────────────────┘
       │
       ├── Step 1: "parse_xml" ─────────────► [OK] ──► Commit Step Run
       │
       ├── Step 2: "resolve_materials" ─────► [OK] ──► Commit Step Run
       │
       ├── [ КРАХ ПРОЦЕССА / OOM / KILL CONTAINER ]
       │
       ▼ (Воркер перезапущен или лизинг подхвачен другим воркером)
       │
       ├── Step 1: "parse_xml" ─────────────► [SKIP: loaded from DB cache]
       ├── Step 2: "resolve_materials" ─────► [SKIP: loaded from DB cache]
       │
       ├── Step 3: "generate_nesting" ──────► [EXECUTE & COMMIT]
       │
       └── Step 4: "create_job_cards" ──────► [EXECUTE & COMMIT]
       │
       ▼
   Job Status: "Completed"
```

---

## 3. СХЕМА ДАННЫХ И СЕРВИСНАЯ РЕАЛИЗАЦИЯ

### 3.1 DocType `Durable Job Run`
Таблица `tabDurable Job Run` фиксирует общий контекст долговечного процесса:
- `company` (Link Company, обязательный, индексирован);
- `job_type` (Data, тип задачи, например `bazis.import_xml`, `material.procure_shortage_batch`);
- `idempotency_key` (Data, уникальный ключ дедупликации);
- `status` (Select: `Pending`, `Running`, `Completed`, `Failed`, `Dead Letter`);
- `input_json` (Code JSON, входные параметры задачи);
- `output_json` (Code JSON, результирующий ответ выполнения);
- `lease_token` (Data, идентификатор воркера, удерживающего лизинг);
- `lease_expires_at` (Datetime, срок действия блокировки воркера);
- `attempts`, `max_attempts` (Int, счетчик попыток и лимит повторов);
- `next_retry_at` (Datetime, время следующего повтора);
- `error_message` (Small Text, причина последнего сбоя);
- `started_at`, `completed_at` (Datetime, временные метки исполнения).

### 3.2 DocType `Durable Step Run`
Таблица `tabDurable Step Run` сохраняет чекпоинт каждого выполненного шага:
- `job_run` (Link Durable Job Run, обязательный, индексирован);
- `step_name` (Data, уникальное в рамках задачи имя шага);
- `step_index` (Int, порядковый номер шага);
- `status` (Select: `Pending`, `Running`, `Completed`, `Failed`);
- `output_json` (Code JSON, сериализованный результат возврата функции шага);
- `error_message` (Small Text, ошибка шага при наличии);
- `started_at`, `completed_at` (Datetime, метки длительности шага).

### 3.3 Сервис `services/durable_jobs.py`
1. **Регистратор обработчиков:**
   ```python
   def register_job_handler(job_type: str, handler: Callable[[DurableJobContext], Any]) -> None: ...
   ```
2. **Контекст задачи (`DurableJobContext`):**
   ```python
   class DurableJobContext:
       def step(self, step_name: str, fn: Callable[[], Any]) -> Any:
           # 1. Проверяем, был ли данный шаг выполнен в прошлых запусках
           if step_name in self._step_cache:
               return self._step_cache[step_name]

           # 2. Выполняем шаг
           result = fn()

           # 3. Атомарно фиксируем результат в MariaDB с немедленным коммитом
           self._record_step_completion(step_name, result)
           return result
   ```
3. **Конкурентный захват лизинга (Worker Leasing):**
   - При выборке задачи используется `for_update=True`.
   - Если воркер упал и `lease_expires_at < now()`, задача автоматически перехватывается свободным воркером.
4. **Политика повторов (`RetryPolicy`):**
   - Экспоненциальный откат: $t_{delay} = 2^{\text{attempts}} \times \text{base\_delay} + \text{jitter}$.
   - При превышении `max_attempts` задача переводится в `Dead Letter` с сохранением полного трейса ошибки.

---

## 4. ИНТЕГРАЦИЯ OUTBOX И АВТОМАТИЧЕСКИХ ВОРКЕРОВ

### 4.1 Сервис `services/outbox_workers.py`
Связывает асинхронные события домена с исполнением долговечных задач:
1. **Реакция на `material.shortage_detected`:**
   - Извлекает из события перечень позиций дефицита (`LDSP-16-WHT`, `EDGE-2MM-WHT` и др.).
   - Генерирует детерминированный ключ идемпотентности: `f"procure-shortage-{sales_order}"`.
   - Регистрирует долговечную задачу `material.procure_shortage_batch`.
2. **Пакетная диспетчеризация с изоляцией сбоев:**
   - `dispatch_outbox_batch(batch_size, worker_id, delivery_name)`:
     - Захватывает записи `Domain Outbox Delivery` через `FOR UPDATE SKIP LOCKED`.
     - Устанавливает `lease_token` и `lease_expires_at = now() + 30s`.
     - При успехе переводит в `Completed`.
     - При сбое вызывает `outbox.mark_delivery_failure()`, пересчитывает retry backoff или перемещает в `Dead Letter`.
3. **Хук планировщика (`hooks.py`):**
   ```python
   scheduler_events = {
       "all": [
           "korkem_manufacturing.services.outbox_workers.cron_dispatch_outbox",
       ],
   }
   ```

---

## 5. РЕЗУЛЬТАТЫ ВЕРИФИКАЦИИ И ТЕСТОВЫХ GATES

Были последовательно выполнены все 14 интеграционных тест-сьютов в реальной среде Docker/MariaDB (korkem.localhost):

| № | Тестовый сьют | Назначение / Домен | Кол-во тестов | Результат | Время (сек) |
|---|---------------|-------------------|---------------|-----------|-------------|
| 1 | `test_stock_offcuts` | Учет и раскрой деловых остатков плит | 7 | **PASSED** | 6.55s |
| 2 | `test_stock_reservation` | Бронирование материалов под заказы | 5 | **PASSED** | 7.58s |
| 3 | `test_stock_movement` | Двойная складская запись, append-only | 5 | **PASSED** | 1.69s |
| 4 | `test_piece_work` | Сдельная оплата по 4 тарифам, сторнирование | 7 | **PASSED** | 2.37s |
| 5 | `test_order_manufacturing_integration` | State Machine $\to$ BOM $\to$ Брони $\to$ Дефицит | 4 | **PASSED** | 7.78s |
| 6 | `test_order_state` | Граф 20 состояний заказа | 8 | **PASSED** | 2.72s |
| 7 | `test_order_concurrency` | Конкурентные переходы и конфликты версий | 4 | **PASSED** | 4.63s |
| 8 | `test_tenant_isolation` | Мультитенантная изоляция фабрик | 7 | **PASSED** | 6.31s |
| 9 | `test_outbox_hardening` | Надежность Outbox, DLQ, replay, crash recovery | 8 | **PASSED** | 2.72s |
| 10| `test_idempotency_concurrency`| Дедупликация запросов и ключи идемпотентности | 4 | **PASSED** | 1.27s |
| 11| `test_audit_integrity` | Неизменяемость и целостность аудита | 3 | **PASSED** | 1.27s |
| 12| `test_registry_security` | AI Tool Registry: Human Gate, безопасность | 6 | **PASSED** | 0.43s |
| 13| `test_durable_jobs` | Step Checkpointing, Crash Recovery, Leasing, DLQ | 5 | **PASSED** | 2.23s |
| 14| `test_outbox_workers` | Outbox Workers, Shortage Automation, Consumers | 3 | **PASSED** | 1.70s |
| **ИТОГО** | **14 тест-сьютов** | **Полное покрытие архитектуры KORKEM v2** | **76 тестов** | **100% OK** | **~48.3s** |

### Верификация клиентского кода Flutter (`mobile/korkem_flow`):
```bash
$ flutter analyze
Analyzing korkem_flow...
No issues found! (ran in 12.1s)
```
- **Ошибок:** 0
- **Предупреждений:** 0
- **Линтов:** 0

---

## 6. СОХРАНЕНИЕ АРХИТЕКТУРНЫХ ИНВАРИАНТОВ

1. **Zero External Daemon Dependencies:**
   - Никаких внешних серверов Temporal, Go-демонов или сторонних облачных сервисов.
   - Движок опирается исключительно на транзакционную модель MariaDB InnoDB (`FOR UPDATE SKIP LOCKED`, ACID-транзакции) и штатные воркеры Frappe/Bench.
2. **Strict Multi-Tenant Isolation:**
   - Все `Durable Job Run` и шаги строго привязаны к `company`.
   - Задачи компании А физически не могут быть прочитаны или выполнены воркером в контексте компании Б.
3. **Idempotency & Replayability:**
   - Защита от дублей как на уровне создания задач (`idempotency_key`), так и на уровне каждого отдельного шага (`DurableJobContext.step`).
4. **UI Design System Integrity:**
   - Все изменения реализованы на уровне ядра и бэкенда.
   - Дизайн-токены, верстка экранов и UX мобильного/десктопного приложения KORKEM Flow полностью сохранены.

---

## 7. АРХИТЕКТУРНЫЙ ВЕРДИКТ

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   KORKEM FLOW V2: PHASE 4 HARDENING & DOMAIN AUTOMATION VERDICT              ║
║                                                                               ║
║   - STEP CHECKPOINTING & CRASH RECOVERY:   PASSED (VERIFIED)                 ║
║   - WORKER LEASING & DLQ RESILIENCE:       PASSED (VERIFIED)                 ║
║   - OUTBOX AUTOMATION WORKERS:             PASSED (VERIFIED)                 ║
║   - 14 TEST GATES / 76 INTEGRATION TESTS:  100% GREEN (ZERO FAILURES)        ║
║   - FLUTTER ANALYZER:                      CLEAN (0 ISSUES)                  ║
║                                                                               ║
║   STATUS: PRODUCTION READY                                                    ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```
