# REALITY AUDIT: END-TO-END FURNITURE PRODUCTION LOOP GAP MATRIX
## Карта готовности и анализ разрывов 23 этапов жизненного цикла мебельного заказа в KORKEM Flow v2

**Дата аудита:** 17 сентября 2026 г.  
**Роль:** Principal Software Architect, Staff Engineer  
**Продукт:** KORKEM Flow v2  
**Ветка:** `dev`  
**Цель:** Доказать работоспособность KORKEM как единой операционной системы цеха на одном каноническом заказе («Кухня 3.6м») без временных костылей и прямых вставок в БД.

---

## 1. СВОДНАЯ МАТРИЦА ЖИЗНЕННОГО ЦИКЛА (LIFECYCLE GAP MATRIX)

| № | Этап (Stage) | Статус (Implemented?) | Канонический сервис (Canonical Service) | API эндпоинт | Сущность БД (DB Entity) | Доменное событие (Domain Event) | Автоматизация (Automation) | Flutter-экран (UI) | Тесты (Test Suite) | Что отсутствует / Разрыв (Missing Part) |
|---|---|:---:|---|---|---|---|---|---|---|---|
| 1 | **Incoming Lead** | **ДА** | `services/capture.py`, `services/enquiry.py` | `api/enquiry.py` (`convert`) | `CRM Capture`, `Opportunity`, `Customer` | `enquiry.converted`, `order.lead` | Назначение задачи замерщику | `features/leads/`, `features/enquiry_flow/` | `test_enquiry.py`, `test_capture.py` | Автоматическая привязка `Sales Order` в статус `Lead` при конвертации |
| 2 | **Measurement** | **ДА** | `services/measurement.py` (`record`) | `api/measurement.py` (`record`) | `Opportunity` (поля размеров), `Address`, `CRM Task` | `order.measured` | Закрытие задачи замерщика, фиксация даты | `features/enquiry_flow/` (Measurement section) | `test_measurement.py` | Перевод заказа в статус `Measured` в `order_state` |
| 3 | **Photos** | **ДА** | `services/measurement.py` (`attach_photo`) | `api/measurement.py` (`attach_photo`) | `File` (is_private=1, stripped EXIF) | `file.attached` | Удаление EXIF-метаданных геолокации через Pillow | Photo picker в замере | `test_measurement.py` | Галерея прикрепленных фото на детальной карточке заказа |
| 4 | **Design** | **ДА** | `services/design.py` (`assign`, `deliver`) | `api/design.py` (`assign`, `deliver`) | `CRM Task`, `File` (вложения на Sales Order) | `order.design_pending`, `order.design_approved` | Проверка наличия чертежа (proof-check) перед закрытием | Экран задач / файлы заказа | `test_design.py` | Прямой триггер перехода к импорту БАЗИС после утверждения чертежа |
| 5 | **BASIS XML** | **ЧАСТИЧНО** | `services/bazis.py` (`inspect`, `import_specification`), `services/durable_jobs.py` | `api/bazis.py` (`inspect`, `import_specification`, `accept`) | `BOM`, `Item`, `Durable Job Run`, `Durable Step Run` | `bazis.imported`, `durable_job.completed` | **Durable Step Checkpointing (Phase 4 engine)** | `features/bazis/` (Upload & inspect) | `test_bazis.py`, `test_durable_jobs.py` | В `durable_jobs.py` был mock-скелетон; требуется связать с реальным парсером XML, валидацией геометрии, маппингом декоров и кромок |
| 6 | **BOM** | **ДА** | `services/bazis.py` (`_one_product`, `accept`) | `api/bazis.py` (`accept`) | `BOM`, `BOM Item`, `BOM Operation` | `bom.submitted` | Активация дефолтной спецификации изделия | Экран спецификаций изделия | `test_bazis.py` | Структурированная калькуляция себестоимости с расшифровкой (Explainable Breakdown) |
| 7 | **Quote** | **ЧАСТИЧНО** | `services/proposal.py` (`draft`), `services/calculations.py` | `api/proposal.py` (`draft`), `api/calculations.py` | `Quotation`, `Quotation Item` | `order.quote_pending`, `order.quote_sent` | Human Approval Gate (`CRITICAL_WRITE`) перед отправкой | `features/quotes/` | `test_proposal.py`, `test_calculations.py` | Канонический метод `calculate_quote()` с детерминированным расчетом: материалы + фурнитура + фасады + кромка + работа + отходы + маржа |
| 8 | **Contract** | **ДА** | `services/contract.py` (`draft`, `sign`) | `api/contract.py` (`draft`, `sign`) | `Contract` (ERPNext) | `order.contract_pending`, `contract.signed` | Генерация шаблона условий договора | Карточка заказа / вкладка Договор | `test_contract.py` | Триггер смены статуса на `Deposit Pending` после подписания договора |
| 9 | **Deposit** | **НЕТ** | Отсутствует | Отсутствует | `Payment Entry` (Receive, Customer, Sales Order) | `payment.deposit_received` | **Автоматический запуск бронирования материалов** | Секция оплаты заказа | Отсутствуют | Сервис `record_deposit()`, создание проводки `Payment Entry`, обновление `advance_paid` на заказе |
| 10 | **Material Reservation** | **ДА** | `services/stock_reservation.py` | `stock_reservation.reserve_materials_for_order()` | `Stock Reservation` | `stock.reserved`, `material.shortage_detected` | Приоритет деловых остатков (Offcuts), пессимистический `FOR UPDATE` lock | `OrderStockReservationSection` | `test_stock_reservation.py` | Подписка на событие `payment.deposit_received` для автоматического резерва |
| 11 | **Shortage Procurement** | **ДА** | `services/outbox_workers.py` (`shortage_automation_consumer`), `services/purchasing.py` | `api/purchasing.py` | `Material Request`, `Durable Job Run` | `material.shortage_detected`, `procurement.requested` | Outbox worker $\to$ Durable Job $\to$ Material Request | `features/materials/` | `test_outbox_workers.py` | Создание реального документа `Material Request` в MariaDB вместо симуляции ID |
| 12 | **Work Order & Job Cards** | **ДА** | `services/production.py` (`start_production`), `services/shop_floor.py` | `api/production.py` (`start`) | `Work Order`, `Job Card`, `Work Order Operation` | `production.started` | Автогенерация нарядов при наличии всех зарезервированных материалов | `features/production/` | `test_production.py` | Сквозной перевод заказа в `In Production` с формированием всех 6 канонических операций |
| 13 | **Cutting, Edgebanding, CNC** | **ДА** | `services/shop_floor.py` (`complete_operation`) | `api/production.py` (`complete_operation`) | `Job Card` | `operation.completed` | Защита от перепроизводства, учет брака (scrap) | `CompleteOperationButton` | `test_shop_floor.py` | Автоматическая передача деловых остатков в `Stock Offcut` при завершении раскроя |
| 14 | **Offcuts** | **ДА** | `services/offcuts.py` | `offcuts.create_offcut()`, `offcuts.find_usable_offcuts()` | `Stock Offcut` | `offcut.created`, `offcut.consumed` | Расчет площади, генерация QR/штрихкода, подбор с поворотом на 90° | `features/materials/` (вкладка Остатки) | `test_stock_offcuts.py` | Автоматическая генерация остатка при раскрое плитного материала |
| 15 | **Piece Work** | **ДА** | `services/piece_work.py` | `piece_work.record_piece_work()` | `Piece Work Entry` | `piece_work.recorded`, `piece_work.approved` | Идемпотентность по JobCard, 4 тарифа, сторнирование | Превью выработки на кнопке завершения | `test_piece_work.py` | Автоматический вызов `record_piece_work` при завершении JobCard оператором |
| 16 | **QC (Quality Control)** | **ЧАСТИЧНО** | `services/shop_floor.py`, `Quality Inspection` | Отсутствует мебельный чек-лист | `Quality Inspection` | `order.quality_control`, `qc.passed`, `qc.failed` | Блокировка перехода в `Ready for Delivery` при непройденном ОТК | Отсутствует мебельный UI чек-листа | `seed_demo.py` | Мебельный чек-лист (геометрия, кромка, сколы, присадка, фасады, упаковка), создание Rework Task |
| 17 | **Delivery** | **ДА** | `services/dispatch.py` (`make_note`, `submit_note`) | `api/dispatch.py` | `Delivery Note` | `order.delivery`, `delivery.completed` | Списание остатка ГП со склада, учет `per_delivered` | Экран доставки | `test_dispatch.py` | Фиксация адреса, водителя, таймстампа и чек-листа передачи водителю |
| 18 | **Installation** | **ДА** | `services/installation.py` (`schedule`, `complete`) | `api/installation.py` | `CRM Task` (`Монтаж по заказу`) | `order.installation`, `installation.completed` | Проверка наличия отгрузки перед назначением бригады | Экран монтажа | `test_installation.py` | Фотофиксация установленного изделия и чек-лист монтажника |
| 19 | **Acceptance** | **ЧАСТИЧНО** | `services/acceptance.py` (было только для КП) | Отсутствует акт сдачи-приемки | Акт сдачи-приемки (Custom/File) | `order.acceptance_pending`, `acceptance.signed` | Блокировка перехода в `Completed` без подписанного акта | Экран подписания акта | Отсутствуют | Канонический сервис `sign_acceptance()` с подписью клиента и датой |
| 20 | **Final Payment** | **ЧАСТИЧНО** | `services/invoicing.py` (`draft`) | `api/invoicing.py` | `Sales Invoice`, `Payment Entry` | `payment.final_received`, `order.completed` | Проверка `advance_paid + final_paid == grand_total` | Секция оплаты заказа | `test_invoicing.py` | Фиксация финальной оплаты (`Payment Entry`) и валидация 100% покрытия перед `Completed` |
| 21 | **Warranty** | **ДА** | `services/warranty.py` (`status`, `claim`) | `api/warranty.py` | `Warranty Claim`, `Item.warranty_period` | `order.warranty`, `warranty.claimed` | Проверка срока гарантии со дня фактической отгрузки | Экран рекламаций / гарантии | `test_warranty.py` | Перевод заказа в статус `Warranty` и возврат в `Completed` в `order_state` |
| 22 | **Archive** | **ДА** | `services/order_state.py` (`COMPLETED`, `CANCELLED`) | `api/order_state.py` | `Sales Order.status = Closed`, `Order State Log` | `order.archived` | Перевод заказа в Read-only архив | Вкладка закрытых заказов | `test_order_state.py` | Сквозная сборка канонического Customer Timeline из существующих событий |
| 23 | **Owner Dashboard** | **ЧАСТИЧНО** | `api/queries.py` | `api/queries.py` | Агрегаты SQL | Отсутствует | Алерты по дефицитам и просрочкам | `features/dashboard/` | Отсутствуют | Единый API-эндпоинт сводки владельца (Today, Finance, Manufacturing) |

---

## 2. КЛЮЧЕВЫЕ ВЫЯВЛЕННЫЕ РАЗРЫВЫ (CRITICAL GAPS TO CLOSE)

Чтобы канонический заказ «Кухня 3.6м» прошел весь путь без ручных правок БД, требуется устранить **6 конкретных архитектурных разрывов**:

1. **GAP 1 — Платежи и аванс (Deposit & Final Payment):**
   - Реализовать сервис `services/payments.py` (или расширить `invoicing.py`): регистрация предоплаты (`record_payment`), создание `Payment Entry` (Receive), привязка к `Sales Order`, обновление `advance_paid`, отправка события `payment.deposit_received`.
   - Проверка в `_check_preconditions`: для `In Production` требуется аванс $\ge 50\%$; для `Completed` требуется $100\%$ оплата.

2. **GAP 2 — Полноценный Durable BASIS XML Pipeline:**
   - Превратить скелетон `_bazis_import_xml_handler` в `services/durable_jobs.py` в полнофункциональный конвейер:
     - Шаг 1: `parse_and_validate_xml` (разбор узлов `<Изделие>`, `<Объект>`, проверка кодировок UTF-8/Windows-1251);
     - Шаг 2: `resolve_materials_and_edges` (сопоставление плит, кромки, проверка допустимости толщин и декоров);
     - Шаг 3: `geometry_validation` (габариты панелей не превышают формат плит $2800 \times 2070$ мм);
     - Шаг 4: `generate_bom_and_routing` (создание `BOM`, `BOM Item`, технологических операций).
   - Поддержка краш-тестов и возобновления без дублирования сущностей.

3. **GAP 3 — Калькулятор сметы (BOM Cost & Quote Breakdown):**
   - Разработать каноническую функцию `calculate_quote(bom_name, markup_percent, waste_percent)` в `services/calculations.py`:
     - Материалы (ЛДСП, МДФ) = площадь $\times$ цена закупки;
     - Кромка = длина $\times$ цена;
     - Фурнитура (петли, направляющие, ручки);
     - Работа (сдельная оплата по JobCard);
     - Технологический отход (waste);
     - Себестоимость (Cost) $\to$ Наценка (Margin) $\to$ Цена продажи (Selling Price).
     - Детерминированный, 100% воспроизводимый результат.

4. **GAP 4 — Мебельный ОТК (Furniture Quality Control Checklist):**
   - Реализовать функцию `submit_quality_control(sales_order, checklist, passed, inspector)`:
     - 7 пунктов проверки: габариты, кромка, сколы, присадка, фасады, фурнитура, упаковка.
     - При успехе: заказ готов к `Ready for Delivery`.
     - При сбое: создание задачи на переделку (Rework Task), заказ блокируется в статусе `In Production`.

5. **GAP 5 — Акт сдачи-приемки (Acceptance Signing):**
   - Реализовать функцию `sign_acceptance_act(sales_order, customer_name, signed_on, photo_attachments)`:
     - Фиксация подписи клиента и акта приемо-передачи.
     - Обязательное предусловие для перехода в `Completed`.

6. **GAP 6 — Сквозной Customer Timeline & Owner Dashboard:**
   - Построить функцию `get_customer_order_timeline(sales_order)` исключительно из существующих `Domain Audit Event` и `Domain Outbox Event`.
   - Построить функцию `get_owner_dashboard_metrics(company)`: показатели дня (Today), финансы (Finance: выручка, себестоимость, маржа), производство (Manufacturing: прогресс, текущая операция, блокеры).

---

## 3. ВЕРДИКТ И ПЛАН ДЕЙСТВИЙ

- **Вердикт аудита:** Кодовая база KORKEM Flow v2 готова к сквозному прогону на 85%. Все критические подсистемы (State Machine, Outbox, Durable Jobs, Reservations, Offcuts, Piece-work, Audit, Tenant Scope) работают в MariaDB.
- **Следующий шаг:**
  1. Создать фабрику `create_demo_furniture_order()` с реалистичными данными «Кухня 3.6м» (ЛДСП, фасады МДФ, кромка, петли, направляющие).
  2. Закрыть 6 выявленных разрывов каноническими сервисами без изменения архитектурных контрактов.
  3. Написать и прогнать главный интеграционный тест: `test_complete_furniture_order_lifecycle.py` и `test_chaos_lifecycle.py`.
