# KORKEM Flow v2 — Product Freeze Specification: Pilot 1
## Заморозка программно-аппаратного контура перед развертыванием в реальном цехе

**Дата фиксации:** 17 сентября 2026 г.  
**Тег релиза:** `korkem-v2-pilot1-freeze`  
**Ветка репозитория:** `dev`  
**Базовый коммит (HEAD):** `0ff291f01df917e5da12965d894c97d26084e9ff`  
**Архитектурный статус:** `FROZEN FOR REAL WORKSHOP PILOT`  

---

## 1. СТАТУС И ЦЕЛЬ ЗАМОРОЗКИ (FREEZE OBJECTIVE)

Настоящий документ устанавливает строгую программную и конфигурационную заморозку KORKEM Flow v2 перед проведением первого пилотного внедрения в действующем мебельном цехе (**Pilot 1**).

### Главное правило заморозки:
1. **ЗАПРЕЩЕНО** начинать новую архитектурную фазу (Phase 6) и проектировать абстракции «на будущее».
2. **ЗАПРЕЩЕНО** добавлять новые DocTypes, таблицы БД или изменять существующую структуру реляционной схемы.
3. **ЗАПРЕЩЕНО** внедрять новые API-эндпоинты или менять контракты существующих вызовов без доказанного сбоя в пилоте.
4. **ЗАПРЕЩЕНО** проводить рефакторинг стабильного кода, не вызванный воспроизводимым блокером.
5. **РАЗРЕШЕНЫ ТОЛЬКО:**
   - **P0-фиксы:** устранение ошибок, физически останавливающих работу станочников или менеджеров в цехе;
   - **Маппинг БАЗИС XML:** точечная корректировка парсера под нестандартные номенклатуры реального цеха;
   - **Цеховой UX:** устранение препятствий, мешающих рабочему нажать кнопку или отсканировать QR на планшете.

Каждое изменение в период пилота оформляется исключительно через тикет в журнале трения ([`HUMAN_FRICTION_LOG.md`](file:///home/eldos/furniture_ai/research/pilot/HUMAN_FRICTION_LOG.md)) с указанием роли, номера заказа и точного описания блокера.

---

## 2. ИДЕНТИФИКАЦИЯ ВЕРСИЙ И ОКРУЖЕНИЯ (ENVIRONMENT BILL OF MATERIALS)

### 2.1. Исходный код и репозиторий
- **Git Branch:** `dev`
- **Git Freeze Tag:** `korkem-v2-pilot1-freeze`
- **Git Commit SHA:** `0ff291f01df917e5da12965d894c97d26084e9ff`
- **Clean Tree Invariant:** Полное соответствие всех компонентов зафиксированному коммиту.

### 2.2. Серверная платформа (Backend Runtime)
- **Операционная система хоста:** Linux x86_64 (Ubuntu 24.04 LTS kernel)
- **Python:** `3.14.7` (CPython, bench virtualenv)
- **Frappe Framework:** `v17.x.x-develop` (commit `39dc511`)
- **ERPNext:** `v17.x.x-develop` (commit `273e9f2`)
- **Frappe CRM:** `v2.0.0-dev`
- **KORKEM Manufacturing App:** `v0.0.1` (commit `1a3aef6`)
- **KORKEM AI App:** `v0.0.1` (commit `1a3aef6`)
- **Frappe Bench CLI:** `v5.31.0`

### 2.3. Хранение данных и очереди
- **Реляционная СУБД:** MariaDB `11.8.2-MariaDB-ubu2404`
- **Сетевой порт СУБД:** `127.0.0.1:3306`
- **Кодировка базы данных:** `utf8mb4 / utf8mb4_unicode_ci`
- **Кэш и брокер очередей:** Redis `7.0-alpine` (3 инстанса: cache, queue, socketio)

### 2.4. Клиентский мобильный и цеховой контур
- **Фреймворк:** Flutter `3.44.8` (channel stable)
- **Dart SDK:** `3.12.2`
- **Платформы развертывания:**
  - Цеховые планшеты: Android 11+ (экран $\ge 10$ дюймов, защищенные чехлы)
  - Планшеты/ноутбуки конструктора и замерщика: Linux Desktop / Android / iOS
  - Статус статического анализа: `flutter analyze` $\longrightarrow$ **0 issues**.

### 2.5. Веб-портал и обратный прокси
- **Web Portal:** Next.js `15.x`, React `19.x`, Tailwind CSS `3.4`
- **Reverse Proxy / SSL:** Caddy `2.8-alpine`
- **Маршрутизация:**
  - API & Bench: `https://api.korkem.asia` / `http://korkem.localhost:8000`
  - Web Portal: `https://korkem.asia` / `http://localhost:3000`

---

## 3. ФИКСАЦИЯ СХЕМЫ ДАННЫХ (DATABASE SCHEMA FREEZE)

Схема базы данных заморожена на текущем наборе таблиц и полей.

### 3.1. Замороженные DocTypes KORKEM Manufacturing:
| DocType | Таблица в MariaDB | Назначение |
|---|---|---|
| `Domain Audit Event` | `tabDomain Audit Event` | Неизменяемый журнал доменных событий и аудита действий |
| `Domain Outbox Event` | `tabDomain Outbox Event` | Транзакционный outbox для межсистемных интеграций |
| `Domain Outbox Delivery` | `tabDomain Outbox Delivery` | Журнал доставки событий с контролем повторов и DLQ |
| `Domain Stock Movement` | `tabDomain Stock Movement` | Точный учет перемещений и списаний сырья |
| `Durable Job Run` | `tabDurable Job Run` | Управление долгими фоновыми задачами (импорт Базис и др.) |
| `Durable Step Run` | `tabDurable Step Run` | Пошаговые чекпоинты устойчивого выполнения задач |
| `Order State Log` | `tabOrder State Log` | Хронология смены состояний конечного автомата заказов |
| `Piece Work Entry` | `tabPiece Work Entry` | Начисления сдельной оплаты станочникам с Human Gate |
| `Stock Offcut` | `tabStock Offcut` | Учет физических деловых остатков плитных материалов |
| `Stock Reservation` | `tabStock Reservation` | Бронирование запасов сырья под конкретные заказы |

### 3.2. Расширения стандартных DocTypes ERPNext:
- `tabSales Order`: добавлены поля `korkem_state` (enum 23 состояний), `advance_paid` (валюта), `installation_status`.
- Патч миграции: `backend/korkem_manufacturing/korkem_manufacturing/patches/v0_0/add_korkem_state_to_sales_order.py`.

---

## 4. ФИКСАЦИЯ КОНФИГУРАЦИИ И ФЛАГОВ (CONFIG & FEATURE FLAGS)

| Параметр конфигурации | Значение в Freeze | Инвариант / Ограничение |
|---|---|---|
| `ORDER_SM_ENFORCE_PRECONDITIONS` | `True` | Запрет переходов в FSM при нарушении финансовых и складских условий |
| `DEPOSIT_MIN_PERCENT` | `50%` | Заказ не переходит в производство без подтвержденного аванса $\ge 50\%$ |
| `ACCEPTANCE_FULL_PAYMENT` | `100%` | Заказ не закрывается без 100% доплаты и подписанного Акта |
| `QC_GATE_BLOCKS_DELIVERY` | `True` | Накладная `Delivery Note` не создается без пройденного ОТК (7 пунктов) |
| `OFFCUT_MIN_LENGTH_MM` | `600` | Минимальная длина делового остатка для оприходования |
| `OFFCUT_MIN_WIDTH_MM` | `400` | Минимальная ширина делового остатка для оприходования |
| `OFFCUT_ROTATION_MATCHING` | `True` | Автоматический подбор остатка с поворотом на 90° при отсутствии структуры |
| `PIECE_WORK_REQUIRE_APPROVAL` | `True` | Human Approval Gate: начисления подтверждаются мастером цеха |
| `OUTBOX_MAX_RETRIES` | `3` | Количество попыток отправки события перед переводом в Dead Letter Queue |
| `OUTBOX_POLL_INTERVAL_SEC` | `5` | Интервал опроса фоновым воркером очереди исходящих сообщений |
| `DURABLE_STEP_TIMEOUT_SEC` | `300` | Таймаут шага импорта и тяжелой калькуляции |
| `IDEMPOTENCY_EXPIRY_SEC` | `86400` | Окно дедупликации вебхуков и внешних транзакций (24 часа) |

---

## 5. DOCKER-ОБРАЗЫ И КОНТЕЙНЕРЫ (CONTAINER MANIFEST)

| Контейнер | Базовый образ | Хеш / Тег | Сеть |
|---|---|---|---|
| `korkem-clean-bench-1` | `korkem-clean-bench:latest` | `sha256:current` | `frappe_bench_default` |
| `korkem-mariadb-1` | `mariadb:11.8` | `sha256:current` | `frappe_bench_default` |
| `korkem-redis-cache-1` | `redis:7-alpine` | `sha256:current` | `frappe_bench_default` |
| `korkem-redis-queue-1` | `redis:7-alpine` | `sha256:current` | `frappe_bench_default` |
| `korkem-caddy-1` | `caddy:2-alpine` | `sha256:current` | `frappe_bench_default` |

---

## 6. ПРОТОКОЛ ВНЕСЕНИЯ ИЗМЕНЕНИЙ В ПЕРИОД ПИЛОТА (PATCH PROTOCOL)

Если в процессе выполнения реального заказа цех сталкивается с ошибкой, препятствующей продолжению работы:
1. Инженер или администратор фиксирует инцидент в [`HUMAN_FRICTION_LOG.md`](file:///home/eldos/furniture_ai/research/pilot/HUMAN_FRICTION_LOG.md).
2. Классифицируется приоритет (P0 — производство стоит, P1 — критическое трение с обходным путем).
3. Создается точечный патч в ветке пилота (`pilot-hotfix-*`).
4. Запрещено вносить изменения напрямую в базу данных через SQL (`NO DEVELOPER RESCUE`).
5. Патч проходит тесты жизненного цикла (`test_complete_furniture_order_lifecycle.py`) и применяется штатным развертыванием.
6. В тикете журнала трения фиксируется коммит исправления и время простоя цеха.
