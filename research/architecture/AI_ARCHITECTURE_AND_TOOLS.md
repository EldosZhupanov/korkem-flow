# Архитектура искусственного интеллекта и реестр инструментов KORKEM (AI Architecture & Tool Registry)

**Дата:** 2026-09-16  
**Версия:** 2.0  
**Статус:** Нормативная спецификация AI-слоя (P0 Invariants R1, R2, R10)  
**Главный закон:** AI — это равноправный клиент доменного API, а не администратор базы данных. Любые действия модели исполняются через детерминированные доменные службы со строгой валидацией типов, проверкой прав и подтверждением человеком (Human-in-the-loop).

---

## 1. Архитектурный конвейер вызова инструментов (Tool Execution Pipeline)

```
        ПОЛЬЗОВАТЕЛЬ (Голос / Текст / Фото / Документ)
                             │
                             ▼
                 [KORKEM AI AGENT LOOP]
                             │
                             │ 1. Генерация намерения (Tool Call Proposal)
                             ▼
                 [TOOL REGISTRY & DISPATCHER]
                             │
                             ├──► 2. Input Guardrail: Валидация JSON Schema (Pydantic)
                             ├──► 3. Security Guardrail: Проверка прав роли и Scope Компании
                             ├──► 4. Idempotency Guardrail: Дедупликация по ключу
                             │
                             ▼
             Нужно ли подтверждение человеком?
                     /                \
        [ДА: Опасное действие]      [НЕТ: Безопасное чтение/расчет]
                 │                                  │
                 ▼                                  ▼
      [PENDING ACTION CARD]               [DOMAIN COMMAND]
   (Показ карточки пользователю:                    │
    "Подтвердить смету 450 000 KZT")                ▼
                 │                         [DOMAIN SERVICES]
                 ▼                       (korkem_manufacturing)
   Человек нажал: [ПОДТВЕРДИТЬ]                     │
                 │                                  ▼
                 └─────────────────────────► [БАЗА ДАННЫХ MARIADB]
                                                    │
                                                    ▼
                                            [AUDIT & OUTBOX]
```

---

## 2. Категории риска инструментов (Tool Risk Taxonomy)

Каждый инструмент в реестре `DomainToolRegistry` обязан иметь явно декларированный уровень риска:

### Уровень 1: READ_ONLY (Безопасное чтение и математика)
- **Правило исполнения:** Выполняется мгновенно без подтверждения.
- **Примеры:**
  - `customer.search(query)` — поиск контрагента в базе;
  - `warehouse.get_stock(material_code)` — проверка остатка листов ЛДСП на складе;
  - `manufacturing.calculate_facade_area(height_mm, width_mm, count)` — точный геометрический расчет;
  - `order.get_status(order_id)` — получение текущего статуса и этапа производства;
  - `order.list_delayed_orders()` — список заказов с угрозой срыва дедлайна;
  - `schedule.get_measurer_slots(date, measurer_id)` — свободные окна замерщика.

### Уровень 2: REVERSIBLE_WRITE (Обратимые операционные мутации)
- **Правило исполнения:** Выполняется с автоматическим логированием в аудит-трейл. При взаимодействии с клиентом формируется карточка предпросмотра.
- **Примеры:**
  - `lead.create(name, phone, source)` — регистрация нового обращения;
  - `measurement.attach_photo(measurement_id, photo_url)` — прикрепление снимка к замеру;
  - `measurement.record_dimensions(measurement_id, dimensions_json)` — сохранение замеров;
  - `task.assign_employee(task_id, employee_id)` — назначение мастера на сменное задание.

### Уровень 3: CRITICAL_FINANCIAL_OPERATIONAL (Критические операции)
- **Правило исполнения:** **БЕЗУСЛОВНО ТРЕБУЕТ ПОДТВЕРЖДЕНИЯ ЧЕЛОВЕКОМ (Инвариант R10).** Инструмент НЕ производит запись в рабочую таблицу, а создает `Pending Action`. Запись в ERP происходит только после физического нажатия кнопки «Подтвердить» пользователем с соответствующей ролью.
- **Перечень критических действий:**
  1. `quote.create_and_send(order_id, total_amount)` — выставление коммерческого предложения клиенту;
  2. `contract.issue_and_sign(order_id)` — выпуск юридического договора;
  3. `payment.record_manual(order_id, amount)` — ручное оприходование наличных денег;
  4. `payment.refund(order_id, amount, reason)` — возврат денег клиенту;
  5. `production.release_to_workshop(order_id)` — запуск распила и бронирование плит;
  6. `order.cancel(order_id, reason)` — аннулирование заказа;
  7. `payroll.adjust_rate(employee_id, new_rate)` — изменение сдельного тарифа мастера;
  8. `inventory.write_off_scrap(item_id, qty, reason)` — списание испорченного материала в брак.

---

## 3. Спецификация класса `DomainToolSpec`

```python
@dataclass(frozen=True)
class DomainToolSpec:
    name: str                          # Уникальное имя: "manufacturing.calculate_facade_area"
    description: str                   # Описание для LLM (назначение, единицы измерения)
    risk_level: ToolRiskLevel          # READ_ONLY | REVERSIBLE_WRITE | CRITICAL
    required_role: str                 # Роль пользователя: "Sales Manager", "Production Manager"
    parameters_schema: type[BaseModel] # Pydantic модель валидации входных аргументов
    response_schema: type[BaseModel]   # Pydantic модель выходного результата
    handler: Callable[..., dict]       # Ссылка на доменный сервис в korkem_manufacturing
    requires_approval: bool            # True для уровня CRITICAL (R10)
```

---

## 4. Архитектура наблюдаемости AI (AI Observability & Tracing)

На основе принципов *Langfuse* для каждого обращения к модели формируется структурированный контекст:
1. **`trace_id`:** Сквозной UUID диалоговой сессии;
2. **`run_id`:** UUID конкретного шага цикла размышления агента;
3. **`tool_call_id`:** Идентификатор вызова конкретного инструмента;
4. **Фиксация метрик:**
   - Входные и выходные токены;
   - Точная стоимость в KZT/USD по датированным тарифам (`korkem_ai_pricing`);
   - Время выполнения инструмента (`latency_ms`);
   - Фиксация решения человека: `ACCEPTED`, `REJECTED`, `EDITED`.
