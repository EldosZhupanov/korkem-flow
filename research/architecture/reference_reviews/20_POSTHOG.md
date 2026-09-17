# Reference Review 20: PostHog Product Analytics

**Репозиторий:** `PostHog/posthog`  
**Commit SHA:** `7af12c98c59f1f6f062a4b3e1e78a3ea746d8723`  
**Дата коммита:** `2026-09-16 07:50:37 +0000`  
**Лицензия:** MIT License (Core) / PostHog Commercial (EE)  
**Основной стек:** Python (Django), TypeScript / React, ClickHouse, Kafka, Redis, Rust  
**Приоритет анализа:** P0  

---

### A. Какую проблему решает
PostHog — ведущая open-source платформа продуктовой аналитики (Product Analytics Platform). Решает задачу полного понимания пользовательского поведения, конверсий по воронкам (Funnels), удержания (Retention), работы продуктовых фиче-флагов (Feature Flags) и воспроизведения сессий (Session Replay) без отправки приватных данных в сторонние сервисы вроде Google Analytics или Mixpanel.

---

### B. Архитектура системы
- **Событийно-ориентированный пайплайн (Event-Driven Pipeline):**
  - Клиентские SDK (Flutter, Web, Python) отправляют стандартизированные события:
    `capture(event_name, distinct_id, properties, timestamp)`.
  - Высокопроизводительный приемник (Capture API) сохраняет события в очередь.
  - Аналитическая база данных (ClickHouse) оптимизирована для сверхбыстрых аналитических агрегаций по миллионам событий.
- **Таксономия событий (Event Taxonomy):**
  Постхог вводит четкие стандарты именования: `object_action` (например, `order_created`, `measurement_completed`, `quote_sent`).
- **Свойства сессии и пользователя (Persons & Properties):**
  Каждое событие обогащается свойствами: `$company_id`, `$user_role`, `$app_version`, `$os`.

---

### C. Ключевые модули и файлы
- `posthog/api/event.py` — API приема и валидации аналитических событий.
- `posthog/models/event/` — модель хранения и дедупликации событий.
- `frontend/src/scenes/funnels/` — расчет воронки конверсий между этапами.

---

### D. Каноническая таксономия продуктовых событий для KORKEM
Для мебельной ОС KORKEM критически важно видеть узкие места (Bottlenecks) в производственной цепочке:
- Где застревают заказы?
- Сколько времени проходит от замера до КП?
- Какой процент КП превращается в договор?
- На каком станке чаще всего срываются сменные задания?
- Насколько эффективен AI-ассистент?

```
lead_created
  │
  ├── measurement_scheduled
  ├── measurement_completed
  │     └── measurement_delayed
  │
  ├── design_submitted
  ├── design_approved
  │
  ├── quote_sent
  ├── quote_accepted
  │     └── quote_rejected (reason: "too expensive", "found competitor")
  │
  ├── contract_signed
  ├── deposit_received
  │
  ├── production_started
  │     ├── operation_started (workstation: "Cutting" | "EdgeBanding" | "CNC")
  │     ├── operation_completed
  │     └── production_delayed (reason: "material shortage" | "machine breakdown")
  │
  ├── delivery_completed
  ├── installation_completed
  │
  ├── order_accepted (acceptance_act_signed)
  ├── final_payment_received
  │
  └── warranty_case_opened
```

**Таксономия событий AI-ассистента:**
```
ai_message_sent
ai_tool_called (tool_name, latency_ms)
ai_suggestion_presented (action_type)
ai_suggestion_accepted (turn_id)
ai_suggestion_rejected (reason)
ai_suggestion_edited (diff)
```

---

### E. Что уже есть в KORKEM
- В KORKEM есть бизнес-статусы документов в MariaDB.
- В Flutter-клиенте есть экран аналитики директора (`features/admin_stats` и `features/dashboard`).
- В `korkem_manufacturing/services/attention.py` есть агрегаты «Что застряло сегодня» (`attention.today`).

---

### F. Чего не хватает в KORKEM по сравнению с PostHog
- **Хронологической воронки конверсии по времени (Time-to-Stage Metric):**
  Директор видит, сколько заказов сейчас на замере, но не видит медианное время: «За последний месяц замерщики стали задерживать сдачу замеров с 24 часов до 72 часов».
- **Метрик принятия решений AI (AI ROI):** Нет возможности доказать владельцу ценность подписки: «В этом месяце KORKEM AI сэкономил администратору 42 часа работы и автоматически рассчитал 135 м² фасадов без ошибок».

---

### G. Что KORKEM должен перенять концептуально
1. **Каноническую таксономию событий (`AnalyticsEvent`):**
   При любых переходах статусов в домене и вызовах инструментов AI генерировать легкое аналитическое событие.
2. **Локальный расчет воронки на SQL:**
   Вместо тяжелого ClickHouse вычислять ключевые метрики цеха (Lead -> Quote -> Deposit -> Delivery) простыми агрегатными запросами поверх таблицы событий в MariaDB.

---

### H. Что KORKEM сознательно НЕ должен перенимать
- **Разворачивание ClickHouse, Kafka и Rust-сервисов:**
  Это прямое нарушение инварианта легковесности и работы на мини-ПК/WSL2 (R6, R8). Все аналитические события KORKEM сохраняются в компактную локальную таблицу MariaDB `tabProduct Analytics Event` с автоматической ротацией.

---

### I. Оценка трудоемкости внедрения
- Доктайп `Product Analytics Event` + метод `analytics.capture()`: **1 день**.

---

### J. Архитектурные риски
- Разрастание таблицы аналитики.
  *Защита:* Хранение детальных событий 90 дней, сжатие в помесячные агрегаты (Rollup summaries).

---

### K. Лицензионные последствия
- **MIT License.** Паттерны таксономии событий полностью открыты.

---

### L. Итоговая рекомендация архитектора
**Одобрено (P0):**
Внедрить единую таксономию аналитических событий KORKEM для отслеживания конверсий мебельного цеха и эффективности AI-ассистента.
