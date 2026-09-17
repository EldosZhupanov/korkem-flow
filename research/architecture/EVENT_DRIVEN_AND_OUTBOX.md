# Событийно-ориентированная архитектура и Transactional Outbox в KORKEM (Event-Driven Domain & Outbox)

**Дата:** 2026-09-16  
**Версия:** 2.0  
**Статус:** Нормативная спецификация шины событий (P0 Reliability Foundation)  
**Проблема, которую решает:** Устранение рассинхронизации базы данных и внешних действий (WhatsApp, Telegram, Push, AI), исключение фантомных уведомлений при откатах транзакций и обеспечение 100% гарантии доставки событий (At-Least-Once Delivery).

---

## 1. Архитектурная диаграмма Transactional Outbox

```
 [КЛИЕНТ: Mobile / Desktop / AI]
                 │
                 │ 1. HTTP Mutation (например, "Запустить в цех")
                 ▼
+───────────────────────────────────────────────────────────+
|               ЕДИНАЯ ТРАНЗАКЦИЯ MARIADB                   |
|                                                           |
| 2. Доменный сервис обновляет заказ:                       |
|    UPDATE tabFurnitureOrder SET status = 'In Production'  |
|                                                           |
| 3. Запись события в Outbox (в этой же транзакции):        |
|    INSERT INTO tabDomainOutboxEvent (                     |
|      event_id, event_name, aggregate_id, payload_json     |
|    ) VALUES ('evt_101', 'production.started', ...)        |
|                                                           |
| 4. COMMIT TRANSACTIONS (Атомарно!)                        |
+───────────────────────────────────────────────────────────+
                 │
                 │ 5. Мгновенный триггер в Redis (Notify Signal)
                 ▼
+───────────────────────────────────────────────────────────+
|               OUTBOX DISPATCHER WORKER                    |
|             (Асинхронный процесс Frappe / Redis)          |
|                                                           |
| 6. SELECT * FROM tabDomainOutboxEvent                     |
|    WHERE processed = 0 ORDER BY creation ASC FOR UPDATE   |
|                                                           |
| 7. Диспетчеризация подписчикам (с независимыми ретраями): |
|    ├── Notification Worker ──► Telegram / WhatsApp / Push |
|    ├── Automation Worker   ──► Правила n8n-style          |
|    ├── Analytics Worker    ──► Воронка конверсий          |
|    └── AI Assistant Context──► Обновление памяти диалога  |
|                                                           |
| 8. UPDATE tabDomainOutboxEvent SET processed = 1          |
+───────────────────────────────────────────────────────────+
```

---

## 2. Спецификация схемы данных `Domain Outbox Event`

Таблица `tabDomain Outbox Event` создается в MariaDB как системный DocType Frappe со следующей структурой:

| Поле | Тип данных SQL | Назначение |
|---|---|---|
| `name` (PK) | VARCHAR(140) | Уникальный ID события: `evt-<uuid>` |
| `company` | VARCHAR(140) | Скоуп компании (индексирован) |
| `event_name` | VARCHAR(100) | Каноническое имя: `order.production_started` |
| `aggregate_type` | VARCHAR(50) | Тип сущности: `FurnitureOrder`, `Payment`, `Measurement` |
| `aggregate_id` | VARCHAR(140) | ID сущности: `ORD-2026-0042` |
| `payload_json` | LONGTEXT | Полный снимок полезной нагрузки события (JSON) |
| `correlation_id` | VARCHAR(100) | Сквозной ID цепочки запроса (Trace ID) |
| `actor` | VARCHAR(140) | Инициатор: `user@korkem.kz` или `system` или `ai_agent` |
| `processed` | TINYINT(1) | Флаг обработки: `0` (новое), `1` (доставлено) |
| `processed_at` | DATETIME | Время успешной отправки всем подписчикам |
| `retry_count` | INT | Число совершенных попыток доставки |
| `error_log` | TEXT | Ошибка последнего сбойного подписчика |
| `creation` | DATETIME | Время фиксации в транзакции БД |

**Критические индексы:**
- `INDEX idx_outbox_unprocessed (processed, creation)` — быстрый отбор ожидающих событий без full-table scan.
- `INDEX idx_outbox_aggregate (aggregate_type, aggregate_id)` — просмотр истории событий конкретного заказа.

---

## 3. Реестр канонических доменных событий KORKEM

Все события именуются по стандарту: `<сущность>.<действие_в_прошедшем_времени>`.

1. **Коммерческие события (CRM):**
   - `lead.created` — поступило новое обращение.
   - `lead.qualified` — лид квалифицирован, выявлены потребности (Кухня / Шкаф / Прихожая).
   - `measurement.scheduled` — назначен выезд замерщика на конкретную дату и слот.
   - `measurement.completed` — замерщик сохранил размеры и загрузил фото объекта.
   - `design.submitted` — дизайнер загрузил проект и раскладку БАЗИС XML.
   - `design.approved` — чертеж и спецификация согласованы с клиентом.
   - `quote.sent` — коммерческое предложение отправлено заказчику в WhatsApp/Telegram.
   - `quote.accepted` — клиент согласовал стоимость.
   - `contract.signed` — подписан юридический договор.
   - `payment.deposit_received` — поступила предоплата (разблокирует закупку и производство).

2. **Производственные события (Manufacturing):**
   - `stock.materials_reserved` — сырье (плиты ЛДСП, кромка, петли) зарезервировано под заказ.
   - `production.released` — заказ передан в цех, сгенерированы сменные задания (`JobCard`).
   - `production.cutting_completed` — завершен раскрой всех плит на форматно-раскроечном станке.
   - `production.edgebanding_completed` — завершена поклейка кромки.
   - `production.drilling_completed` — завершена присадка отверстий.
   - `production.facades_milled` — завершена фрезеровка фасадов МДФ.
   - `production.assembly_completed` — предварительная сборка модулей завершена.
   - `production.qc_passed` — отдел ОТК подтвердил отсутствие сколов и брака.
   - `production.scrap_reported` — зафиксирован производственный брак (скол, повреждение пленки).

3. **Логистические и сервисные события (Fulfillment & Warranty):**
   - `delivery.scheduled` — согласована дата доставки готовой мебели клиенту.
   - `delivery.completed` — мебель доставлена на адрес и поднята на этаж.
   - `installation.started` — монтажная бригада приступила к установке.
   - `installation.completed` — монтаж завершен, кухня собрана.
   - `acceptance.signed` — клиент подписал Акт приема-передачи без замечаний.
   - `payment.final_received` — получен окончательный расчет 100%.
   - `order.completed` — заказ успешно закрыт, активирован гарантийный талон.
   - `warranty.case_opened` — клиент обратился по гарантии (рекламация).

---

## 4. Гарантии доставки и обработка отказов (Dead-Letter Queue)

1. **At-Least-Once Delivery:** Событие помечается как `processed=1` только после успешного выполнения всех подписчиков.
2. **Экспоненциальный бэкап повторов:**
   При сбое внешнего сервиса (например, временная недоступность WhatsApp API) воркер делает повторные попытки с нарастающим интервалом:
   - Попытка 1: через 1 минуту;
   - Попытка 2: через 5 минут;
   - Попытка 3: через 30 минут;
   - Попытка 4: через 2 часа;
   - Попытка 5: через 8 часов.
3. **Dead-Letter:** После 5 неудачных попыток событие переводится в статус ошибки (`processed = -1`), и администратору узла генерируется предупреждение в системный журнал с сохранением стектрейса.
