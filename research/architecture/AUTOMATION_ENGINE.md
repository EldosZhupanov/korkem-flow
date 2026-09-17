# Мебельный движок автоматизации KORKEM (Automation Engine)

**Дата:** 2026-09-16  
**Версия:** 2.0  
**Статус:** Нормативная спецификация движка бизнес-правил цеха  
**Основа:** Адаптация принципов n8n и Directus Flows под мебельную специфику (Trigger -> Condition -> Action).

---

## 1. Назначение и концепция

KORKEM Automation Engine позволяет владельцу мебельного цеха или управляющему настраивать автоматические сценарии без программирования. Движок слушает события из `Transactional Outbox`, сопоставляет условия и инициирует детерминированные доменные команды.

```
       СОБЫТИЕ ИЗ OUTBOX                     ПРОВЕРКА УСЛОВИЯ                   ВЫПОЛНЕНИЕ ДЕЙСТВИЯ
+─────────────────────────────+       +─────────────────────────────+       +─────────────────────────────+
|           TRIGGER           |       |          CONDITION          |       |           ACTION            |
|                             |       |                             |       |                             |
|  payment.deposit_received   | ────► |   deposit_percent >= 50%    | ────► | 1. stock.reserve_materials  |
|  (ORD-2026-0104, 300000KZT) |       |                             |       | 2. order.release_production |
+─────────────────────────────+       +─────────────────────────────+       +─────────────────────────────+
```

---

## 2. Модели данных движка автоматизации

### 2.1 Таблица `tabAutomation Rule` (Правило автоматизации)
- `name` (PK): Уникальный код правила (например: `rule-deposit-auto-reserve`).
- `company`: Скоуп организации.
- `title`: Человекопонятное название («Авторезерв материалов при получении аванса»).
- `is_active`: Флаг включения (1 / 0).
- `trigger_event`: Имя отслеживаемого события (`payment.deposit_received`, `measurement.completed`, `stock.below_threshold`).
- `condition_expression_json`: Предикат проверки данных (JSON-выражение).
- `actions_json`: Список вызываемых действий с параметрами.
- `max_runs_per_hour`: Ограничение частоты срабатываний (защита от флуда).

### 2.2 Таблица `tabAutomation Run` (Журнал выполнения правил)
- `name` (PK): UUID запуска (`run-<uuid>`).
- `rule`: Ссылка на `Automation Rule`.
- `trigger_event_id`: Ссылка на событие в `Domain Outbox Event`.
- `matched`: Выполнилось ли условие (1 / 0).
- `status`: `SUCCESS` | `FAILED` | `SKIPPED`.
- `action_results_json`: Результаты выполнения вызванных сервисов.
- `error_message`: Текст ошибки при сбое.
- `execution_time_ms`: Латентность обработки.

---

## 3. Каталог базовых мебельных правил (Factory Standard Presets)

Система поставляется с набором готовых рецептов для цеха:

### Правило 1: Создание задачи на замер при квалификации лида
- **Trigger:** `lead.qualified`
- **Condition:** `payload.measurement_required == True`
- **Action:** `task.create(role="MEASURER", subject="Замер: " + payload.customer_name, address=payload.address)`

### Правило 2: Резервирование сырья и открытие производственного заказа по авансу
- **Trigger:** `payment.deposit_received`
- **Condition:** `payload.paid_amount >= payload.quote_total * 0.5`
- **Action:**
  1. `inventory.reserve_bom_materials(order_id=payload.order_id)`
  2. `production.create_work_order(order_id=payload.order_id)`
  3. `notification.send(channel="whatsapp", recipient=payload.customer_phone, template="order_in_production")`

### Правило 3: Автоматическая заявка снабженцу при дефиците ЛДСП
- **Trigger:** `inventory.stock_below_minimum`
- **Condition:** `payload.item_group == "Плитные материалы"`
- **Action:** `procurement.create_purchase_request(item_code=payload.item_code, suggested_qty=payload.min_batch)`

### Правило 4: Предупреждение владельца о риске срыва дедлайна (Escalation)
- **Trigger:** `order.daily_progress_check`
- **Condition:** `payload.days_until_deadline <= 2 AND payload.current_stage not in ["Packaging", "Ready for Delivery"]`
- **Action:** `notification.notify_owner(message="ВНИМАНИЕ: Заказ #" + payload.order_id + " отстает от графика! Срок сдачи через 2 дня, текущий этап: " + payload.current_stage)`

### Правило 5: Запрос подписания Акта и отзыва после монтажа
- **Trigger:** `installation.completed`
- **Condition:** `payload.crew_confirmed == True`
- **Action:**
  1. `notification.send(channel="whatsapp", recipient=payload.customer_phone, template="request_acceptance_act")`
  2. `invoicing.issue_final_payment_link(order_id=payload.order_id)`

---

## 4. Защита от бесконечных циклов и рекурсии (Infinite Loop Protection)

1. **Глубина рекурсии:** В контексте выполнения события передается счетчик `depth`. При `depth > 3` обработка немедленно прекращается с логированием ошибки.
2. **Запрет самозапуска:** Правило не может слушать события, которые само же генерирует, без явного флага идемпотентного изменения состояния.
