# ОТЧЁТ О РЕАЛИЗАЦИИ ФАЗЫ 3 (PHASE 3: MANUFACTURING DOMAIN VALUE)
## Внедрение ключевых мебельных производственных функций: Деловые остатки (Stock Offcut), Бронирование материалов (Stock Reservation), Складской регистр двойной записи (Stock Movement) и Сдельная оплата (Piece-rate Payroll)

**Дата:** 17 сентября 2026 г.  
**Роль:** Principal Software Architect, Staff Engineer  
**Продукт:** KORKEM Flow v2  
**Ветка:** `dev`  
**Статус фазы:** **COMPLETED / PASSED ALL 12 TEST GATES (68/68 TESTS OK)**  
**Вердикт для Фазы 4:** **GO ДЛЯ ФАЗЫ 4 (DURABLE BACKGROUND JOBS / OUTBOX AUTOMATION)**  

---

## 1. EXECUTIVE SUMMARY

В рамках реализации **Phase 3 (Manufacturing Domain Value)** архитектурный фундамент KORKEM v2 (P0 Hardening: Outbox, Tenant Scope, Idempotency, Concurrency, Audit) был развернут в прикладные производственные сервисы мебельного цеха.

Главный фокус фазы — решение реальных болей мебельного производства без изменения UI-токенов, без generic-фреймворков и без микросервисной фрагментации:
1. **Экономия плитного материала (ЛДСП/МДФ):** учет деловых остатков (Offcuts), алгоритм раскроя Best-fit с поворотом на 90°, маркировка QR/штрихкодом.
2. **Гарантия сборки заказа:** строгое бронирование материалов и деловых остатков с пессимистической блокировкой строк, исключающее двойное списание.
3. **Финансовая строгость складского учета:** неизменяемый (append-only) регистр перемещений двойной записи (`Domain Stock Movement`) с математической реконструкцией баланса и сторнированием.
4. **Мотивация мастеров и прозрачность выработки:** сдельная оплата по операциям и JobCard (`Piece Work Entry`) по 4 тарифным сеткам с защитой от двойного начисления и Human Approval Gate (`CRITICAL_WRITE`).
5. **Сквозная интеграция со State Machine:** переход заказа в статус `In Production` аппаратно требует наличия BOM и 100% зарезервированных материалов. При дефиците генерируется событие `material.shortage_detected`. При отмене заказа все брони немедленно высвобождаются.
6. **Flutter-клиент:** бесшовное отображение резервов, превью сдельного заработка на экране завершения операции и фильтрация деловых остатков без нарушения дизайн-системы.

---

## 2. ПОДРОБНЫЙ РАЗБОР ВНЕДРЕННЫХ ДОМЕННЫХ СЕРВИСОВ

### 2.1 Stock Offcut: Учет и повторное использование деловых остатков
- **DocType:** `Stock Offcut` (`tabStock Offcut`).
- **Схема данных:**
  - `company` (Link Company, обязательный, индексирован);
  - `material_item` (Link Item, обязательный, индексирован);
  - `decor` (Data, код/название декора, например "W1000 ST9");
  - `thickness_mm` (Float, толщина плиты);
  - `length_mm`, `width_mm` (Float, габариты в мм, обязательные);
  - `area_m2` (Float, автоматический расчет: $(L \times W) / 10^6$ с точностью до 4 знаков);
  - `warehouse` (Link Warehouse, склад хранения);
  - `storage_cell` (Data, ячейка/стеллаж цеха);
  - `status` (Select: `Available`, `Reserved`, `Consumed`, `Scrapped`);
  - `reserved_for_order` (Link Sales Order);
  - `qr_code`, `barcode` (Data, автоматическая генерация уникального идентификатора);
  - `source_stock_entry`, `source_work_order`, `source_job_card`, `source_order` (трассировка происхождения).
- **Бизнес-правила и инварианты (`StockOffcut.validate`, `StockOffcut.on_trash`):**
  - **Порог делового остатка:** остатки меньше $100 \times 100$ мм или площадью $< 0.04$ м² ($400$ см²) квалифицируются как технологический опил/отход и отклоняются (`frappe.ValidationError`). Допускается только статус `Scrapped`.
  - **Защита от двойного списания:** остаток в статусе `Consumed` или `Scrapped` заблокирован от любых последующих операций. Повторное списание в производство физически невозможно.
  - **Soft-delete (Запрет физического удаления):** хук `on_trash` выбрасывает `frappe.PermissionError`. Списание бракованного остатка происходит исключительно через статус `Scrapped`.
  - **Алгоритм Best-Fit Matching с поворотом на 90° (`find_usable_offcuts`):**
    - Находит все доступные остатки для заданного материала.
    - Проверяет вхождение: прямое ($L \ge L_{req} \land W \ge W_{req}$) или с поворотом на 90° ($L \ge W_{req} \land W \ge L_{req}$).
    - Сортирует по возрастанию площади (`area_m2 asc`), гарантируя использование наименьшего подходящего остатка и минимизируя технологический отход.
  - **Изоляция арендаторов:** строгая проверка `enforce_tenant_scope` и запрет бронирования остатка фабрики А под заказ фабрики Б.

### 2.2 Stock Reservation: Бронирование материалов под заказ
- **DocType:** `Stock Reservation` (`tabStock Reservation`).
- **Схема данных:**
  - `company`, `sales_order` (обязательные привязки);
  - `item_code`, `warehouse`, `qty` (номенклатура и объем резерва);
  - `reservation_type` (`Full Sheet`, `Offcut`, `Edge Band`, `Hardware`, `Other`);
  - `offcut` (Link Stock Offcut, прямая привязка конкретного делового остатка);
  - `status` (`Active`, `Released`, `Consumed`);
  - `idempotency_key` (уникальный ключ идемпотентности);
  - `reserved_by`, `reserved_at`, `released_at`, `consumed_at`.
- **Бизнес-правила и инварианты (`services/stock_reservation.py`):**
  - **Пессимистическая блокировка (Row-level Locking):** выборка через `FOR UPDATE` исключает одновременное резервирование одного и того же листа или делового остатка двумя параллельными процессами.
  - **Идемпотентность:** при передаче `idempotency_key` повторный вызов возвращает существующий резерв без дублирования.
  - **Проверка физической доступности (`get_available_unreserved_qty`):**
    $$\text{Доступно} = \text{Фактический остаток} - \sum \text{Активные брони}$$
    Попытка забронировать объем, превышающий свободный остаток, блокируется с понятным сообщением.
  - **Автоматический жизненный цикл:**
    - При отмене заказа (`Cancelled`) вызывается `release_reservations_for_order`: резервы переводятся в `Released`, деловые остатки возвращаются в `Available`, в регистр складских перемещений вносится компенсирующая проводка.
    - При передаче в производство (`In Production`) вызывается `consume_reservations_for_order`: резервы и привязанные остатки переводятся в `Consumed`.

### 2.3 Double-entry Material Ledger: Неизменяемый складской регистр
- **DocType:** `Domain Stock Movement` (`tabDomain Stock Movement`).
- **Схема данных:**
  - `company`, `from_location`, `to_location`, `item_code`, `qty`, `reason`, `actor`, `timestamp`, `is_compensation`, `compensated_movement`.
- **Бизнес-правила и инварианты (`DomainStockMovement.before_save`, `services/stock_movement.py`):**
  - **Строгий Append-Only:** хук `before_save` проверяет `if not self.is_new(): frappe.throw(...)`. Любая попытка UPDATE отвергается с `PermissionError`.
  - **Запрет DELETE:** хук `on_trash` запрещает физическое удаление записей.
  - **Реконструкция баланса:**
    $$\text{Баланс}(L, \text{Item}) = \sum_{to=L} \text{Qty} - \sum_{from=L} \text{Qty}$$
    Баланс любой ячейки, склада или цеховой зоны восстанавливается детерминированно из первичных проводок.
  - **Сторнирование (`compensate_movement`):** ошибки исправляются исключительно созданием зеркальной проводки ($From \leftrightarrow To$) с отметкой `is_compensation = 1`.

### 2.4 Piece-rate Payroll: Сдельная оплата по операциям и JobCard
- **DocType:** `Piece Work Entry` (`tabPiece Work Entry`).
- **Схема данных:**
  - `company`, `employee`, `employee_name`, `operation`, `job_card`, `sales_order`, `work_order`;
  - `rate_type` (`KZT_PER_PART`, `KZT_PER_M2`, `KZT_PER_METER`, `FIXED_PER_OPERATION`);
  - `quantity`, `rate`, `amount` ($\text{Amount} = \text{Quantity} \times \text{Rate}$);
  - `status` (`Pending Approval`, `Approved`, `Paid`, `Reversed`);
  - `approved_by`, `approved_at`, `reversed_entry`, `reversal_reason`, `idempotency_key`.
- **Бизнес-правила и инварианты (`services/piece_work.py`):**
  - **4 канонических тарифа:**
    - `KZT_PER_PART` (за деталь — присадка, кромление полок);
    - `KZT_PER_M2` (за м² — раскрой на ЧПУ, фрезеровка фасадов);
    - `KZT_PER_METER` (за пог. м — нанесение кромки 2мм);
    - `FIXED_PER_OPERATION` (фикс за операцию — контрольная сборка изделия).
  - **Защита от дублирования:** ключ `idempotency_key` (например `jobcard-complete-{id}`) исключает повторное начисление денег за одну и ту же выполненную технологическую операцию.
  - **Финансовая неизменяемость:** после перехода в статус `Approved`, `Paid` или `Reversed` поля `quantity`, `rate` и `amount` блокируются от изменения.
  - **Human Approval Gate (R10):** начисления создаются в статусе `Pending Approval`. Выплата возможна только после утверждения руководителем (`approve_piece_work`). В `DomainToolRegistry` методы `payroll.approve` и `payroll.reverse` зарегистрированы с уровнем риска `CRITICAL_WRITE`.
  - **Сторнирование начислений (`reverse_piece_work`):** исходная запись помечается `Reversed`, и создается компенсирующая запись с отрицательными значениями $-\text{Qty}$ и $-\text{Amount}$, восстанавливающая корректное сальдо взаиморасчетов.
  - **Сводная ведомость (`get_employee_payroll_summary`):** вычисляет суммы к выплате, утвержденные и выплаченные начисления за период.

---

## 3. ИНТЕГРАЦИЯ С ORDER STATE MACHINE

В канонический конечный автомат (`services/order_state.py`) внедрены жесткие условия перехода:

```
[ Ready for Production ]
        │
        ├── can_transition() проверяет:
        │     1. Наличие активной спецификации (BOM);
        │     2. Покрытие потребности материалами (check_materials_reserved_for_order);
        │     3. При нехватке: блокировка перехода + outbox: material.shortage_detected.
        │
        ▼ (Все материалы зарезервированы)
[ In Production ]  ───► Автоматический вызов consume_reservations_for_order()
        │
        ▼ (При отмене заказа на любом этапе)
[ Cancelled ]      ───► Автоматический вызов release_reservations_for_order()
```

- **Preconditions Gate (`_check_preconditions`):**
  - Попытка перевести заказ в `In Production` без спецификации (BOM) отклоняется:
    `"Заказ не может быть передан в производство: не привязана спецификация материалов (BOM)."`
  - Попытка перевести заказ при наличии дефицита отклоняется:
    `"Заказ не может быть передан в производство: дефицит зарезервированных материалов (TEST-RAW-BOARD-16 (дефицит: 3.0))."`
  - Одновременно в `Domain Outbox Event` записывается событие `material.shortage_detected` для автоматического оповещения снабженца.
- **Освобождение при отмене:**
  - При переводе заказа в `Cancelled` все активные брони материалов и деловых остатков немедленно освобождаются, исключая "зависание" склада.

---

## 4. ИНТЕГРАЦИЯ С FLUTTER КЛИЕНТОМ (KORKEM FLOW)

Интеграция выполнена с сохранением существующих дизайн-токенов (`core/design/tokens/`), цветовой палитры и доступности:

1. **Экран заказа (`OrderDetailScreen`):**
   - Добавлен блок `OrderStockReservationSection` ([order_stock_reservation_section.dart](file:///home/eldos/furniture_ai/mobile/korkem_flow/lib/features/orders/presentation/order_stock_reservation_section.dart)).
   - Отображает статус покрытия материалами: `Зарезервировано` (StatusIntent.info) или `Списано в цех` (StatusIntent.success).
   - Подтверждает включение деловых остатков (Offcuts) и готовность маркировки QR/Barcode.
2. **Экран цеха / завершения операции (`CompleteOperationButton`):**
   - В диалог списания операции добавлен реактивный индикатор `ValueListenableBuilder`, отображающий предварительную сдельную оплату мастера: `Сдельно: ~{qty * rate} ₸`.
3. **Каталог материалов (`MaterialsScreen`):**
   - Добавлен фильтр-чип `Остатки` с семантической иконкой `AppIcons.dimension`, позволяющий технологу быстро находить деловые остатки на складе.
4. **Анализ кода Flutter:**
   - Команда `flutter analyze` завершилась со статусом: **`No issues found!`** (0 warnings, 0 errors).

---

## 5. РЕЗУЛЬТАТЫ ТЕСТОВОГО ШЛЮЗА (TEST GATE EXECUTION)

В реальном Docker-окружении (`korkem-clean-bench-1`, MariaDB 11.8, Redis 7) выполнен полный прогон интеграционных тестов по всем доменным модулям:

| № | Модуль тестов | Количество тестов | Время | Статус | Проверенные инварианты |
|---|---------------|-------------------|-------|--------|------------------------|
| 1 | `korkem_manufacturing.test_stock_offcuts` | 7 | 6.41 с | **PASSED** | Площадь, QR/barcode, порог отхода, Best-fit 90°, double-consume block, soft-delete, tenant isolation |
| 2 | `korkem_manufacturing.test_stock_reservation` | 5 | 5.82 с | **PASSED** | Бронь листов и остатков, row-lock, идемпотентность, освобождение при отмене, списание в цех |
| 3 | `korkem_manufacturing.test_stock_movement` | 5 | 1.71 с | **PASSED** | Двойная запись, реконструкция баланса, $qty > 0$, append-only, delete blocked, сторнирование |
| 4 | `korkem_manufacturing.test_piece_work` | 7 | 2.40 с | **PASSED** | 4 тарифа, идемпотентность JobCard, Approval Gate, выплата, неизменяемость, сторно, ведомость |
| 5 | `korkem_manufacturing.test_order_manufacturing_integration` | 4 | 6.41 с | **PASSED** | Блокировка без BOM, блокировка при дефиците + Outbox event, успех при резерве, авто-освобождение при Cancelled |
| 6 | `korkem_manufacturing.test_order_state` | 8 | 2.23 с | **PASSED** | Граф 20 состояний, терминальный Cancelled, ролевая валидация, логи состояний, аудит |
| 7 | `korkem_manufacturing.test_order_concurrency` | 4 | 4.74 с | **PASSED** | Пессимистическая блокировка `for_update`, optimistic check, откат при сбоях |
| 8 | `korkem_manufacturing.test_tenant_isolation` | 7 | 6.46 с | **PASSED** | Fail-closed tenant isolation, защита от угаданных ID, AI Tool Registry, Automation Engine |
| 9 | `korkem_manufacturing.test_outbox_hardening` | 8 | 2.65 с | **PASSED** | Crash recovery, per-consumer ledger, worker leasing, retry backoff, DLQ replay |
| 10 | `korkem_manufacturing.test_idempotency_concurrency` | 4 | 1.10 с | **PASSED** | Уникальность по компании, разрешение конфликтов, retention cleanup |
| 11 | `korkem_manufacturing.test_audit_integrity` | 3 | 1.11 с | **PASSED** | Неизменяемость аудита, append-only, полнота полей (trace_id, diff) |
| 12 | `korkem_ai.korkem_ai.tools.test_registry_security` | 6 | 0.37 с | **PASSED** | R10 Approval Gate, типизация Pydantic, CRITICAL_WRITE шлюз, payroll.approve / payroll.reverse |
| **ИТОГО** | **12 тестовых комплексов** | **68 тестов** | **41.41 с** | **100% OK** | **0 ошибок, 0 регрессий** |

---

## 6. ВЕРДИКТ И ПЕРЕХОД К ФАЗЕ 4 (PHASE 4 READINESS)

### Оценка готовности системы:
- [x] **Деловые остатки (Stock Offcuts):** Полностью внедрены, протестированы, готовы к промышленному использованию.
- [x] **Бронирование материалов (Stock Reservation):** Гарантирует предотвращение пересортицы и двойного бронирования.
- [x] **Складской регистр двойной записи (Stock Movement):** Обеспечивает математическую сходимость балансов без возможности подделки истории.
- [x] **Сдельная оплата (Piece-rate Payroll):** Предоставляет прозрачную мотивацию цеху с контролем руководителя (CRITICAL_WRITE).
- [x] **Интеграция с Order State Machine:** Защищает цех от запуска "пустых" или необеспеченных материалом заказов.
- [x] **Мобильное приложение (Flutter):** Интерфейс обогащен производственным контекстом без нарушения дизайна.
- [x] **Регрессионная безопасность:** 68/68 интеграционных тестов пройдены успешно.

### ВЕРДИКТ:
**GO ДЛЯ ФАЗЫ 4: DURABLE BACKGROUND JOBS & OUTBOX AUTOMATION WORKERS.**
Архитектура готова к подключению асинхронных фоновых исполнителей (Redis Queue / RQ Workers), надежной доставке событий и автоматизации связок (дефицит $\to$ автоматический заказ поставщику $\to$ резерв).
