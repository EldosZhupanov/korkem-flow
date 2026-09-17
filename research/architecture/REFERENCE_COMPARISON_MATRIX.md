# Master Comparison Matrix: KORKEM vs. 20 Reference Projects

**Дата:** 2026-09-16  
**Статус:** Системное сопоставление архитектурных возможностей  
**Шкала оценки:**
- **NONE** — возможность полностью отсутствует в архитектуре.
- **WEAK** — зачаточная реализация, нестабильная или требующая глубоких доработок.
- **PARTIAL** — качественная, но неполная реализация или узкоспециализированная.
- **STRONG** — эталонная реализация производственного уровня.

---

## 1. Сводная матрица архитектурных возможностей

| Архитектурная область / Субсистема | Current KORKEM | Twenty | ERPNext | Odoo | n8n | Trigger.dev | Temporal | Directus | Supabase | ElectricSQL | Cal.com | Novu | Medusa | Appsmith | NocoDB | Plane | Browser Use | Agents SDK | Dify | Langfuse | PostHog |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **CRM objects (Лиды, Сделки)** | PARTIAL | STRONG | STRONG | STRONG | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | PARTIAL | PARTIAL | NONE | NONE | NONE | NONE | NONE |
| **Custom fields (Пользовательские поля)** | PARTIAL | STRONG | STRONG | STRONG | NONE | NONE | NONE | STRONG | NONE | NONE | NONE | NONE | PARTIAL | NONE | STRONG | PARTIAL | NONE | NONE | NONE | NONE | NONE |
| **Customer timeline (Лента клиента)** | WEAK | STRONG | PARTIAL | STRONG | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | NONE | STRONG | NONE | NONE | NONE | NONE | NONE |
| **Order state (Автомат заказа)** | WEAK | PARTIAL | STRONG | STRONG | NONE | NONE | STRONG | PARTIAL | NONE | NONE | PARTIAL | NONE | STRONG | NONE | NONE | STRONG | NONE | NONE | NONE | NONE | NONE |
| **Workflow engine (Движок процессов)** | NONE | PARTIAL | PARTIAL | STRONG | STRONG | STRONG | STRONG | STRONG | NONE | NONE | PARTIAL | PARTIAL | STRONG | NONE | NONE | PARTIAL | NONE | PARTIAL | STRONG | NONE | NONE |
| **Durable jobs (Отказоустойчивые задачи)** | WEAK | NONE | PARTIAL | PARTIAL | PARTIAL | STRONG | STRONG | PARTIAL | NONE | NONE | NONE | PARTIAL | PARTIAL | NONE | NONE | NONE | NONE | NONE | PARTIAL | NONE | NONE |
| **Manufacturing (Производство)** | STRONG | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **BOM (Спецификации изделий)** | STRONG | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Routing (Маршруты операций)** | STRONG | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Job cards (Сменные карточки)** | STRONG | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Warehouse (Складской учет)** | STRONG | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Inventory (Резервы и партии)** | PARTIAL | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Procurement (Закупки)** | STRONG | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Finance (Финансы и счета)** | PARTIAL | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Payments (Прием платежей/Каспи)** | PARTIAL | NONE | STRONG | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | PARTIAL | NONE | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Notifications (Многоканальные пуши)** | PARTIAL | NONE | PARTIAL | PARTIAL | PARTIAL | NONE | NONE | PARTIAL | NONE | NONE | PARTIAL | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Calendar (Расписание замера/монтажа)** | WEAK | PARTIAL | PARTIAL | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | STRONG | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE |
| **Local-first (Автономия без сети)** | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **Mobile sync (Синхронизация телефона)** | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | STRONG | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE |
| **AI tools (Инструменты ИИ)** | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | STRONG | STRONG | STRONG | NONE | NONE |
| **AI workflows (Агентские цепочки)** | PARTIAL | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | PARTIAL | STRONG | STRONG | NONE | NONE |
| **Browser automation (Парсинг сайтов)** | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | STRONG | NONE | NONE | NONE | NONE |
| **Observability (AI трассировка)** | WEAK | NONE | NONE | NONE | NONE | PARTIAL | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | PARTIAL | PARTIAL | STRONG | PARTIAL |
| **Product analytics (Воронки и метрики)**| WEAK | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | NONE | STRONG |
| **Audit trail (Журнал аудита мутаций)**| WEAK | STRONG | PARTIAL | STRONG | NONE | PARTIAL | STRONG | STRONG | PARTIAL | NONE | NONE | NONE | PARTIAL | NONE | PARTIAL | STRONG | NONE | NONE | NONE | STRONG | STRONG |
| **RBAC (Ролевой доступ)** | STRONG | STRONG | STRONG | STRONG | PARTIAL | PARTIAL | NONE | STRONG | STRONG | NONE | PARTIAL | PARTIAL | PARTIAL | STRONG | STRONG | STRONG | NONE | NONE | PARTIAL | PARTIAL | STRONG |
| **Multitenancy (Изоляция компаний)** | PARTIAL | STRONG | STRONG | STRONG | NONE | NONE | NONE | STRONG | STRONG | NONE | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | STRONG | NONE | NONE | STRONG | STRONG | STRONG |
| **Webhooks (Шлюзы и события)** | PARTIAL | PARTIAL | STRONG | STRONG | STRONG | STRONG | NONE | STRONG | STRONG | NONE | STRONG | STRONG | STRONG | PARTIAL | STRONG | STRONG | NONE | NONE | STRONG | STRONG | STRONG |
| **Plugin architecture (Расширяемость)** | STRONG | PARTIAL | STRONG | STRONG | STRONG | PARTIAL | NONE | STRONG | NONE | NONE | PARTIAL | NONE | STRONG | NONE | NONE | NONE | NONE | NONE | PARTIAL | NONE | NONE |
| **API (Контракты и эндпоинты)** | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | PARTIAL | PARTIAL | STRONG | STRONG | STRONG |
| **Event bus (Событийная шина)** | WEAK | PARTIAL | PARTIAL | PARTIAL | STRONG | STRONG | STRONG | STRONG | STRONG | STRONG | NONE | STRONG | STRONG | NONE | NONE | PARTIAL | NONE | NONE | PARTIAL | NONE | STRONG |
| **Search (Поиск по сущностям)** | PARTIAL | STRONG | PARTIAL | STRONG | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | PARTIAL | NONE | PARTIAL | STRONG | NONE | NONE | STRONG | NONE | NONE |
| **File storage (Файлы, фото замера)** | PARTIAL | PARTIAL | STRONG | STRONG | NONE | NONE | NONE | STRONG | STRONG | NONE | NONE | NONE | PARTIAL | NONE | PARTIAL | PARTIAL | NONE | NONE | PARTIAL | NONE | NONE |
| **Reporting (Отчеты руководителя)** | PARTIAL | PARTIAL | STRONG | STRONG | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | NONE | PARTIAL | NONE | NONE | NONE | NONE | NONE | STRONG |

---

## 2. Аналитические выводы из матрицы

1. **Где KORKEM уникален и превосходит большинство систем (STRONG):**
   - **Мебельная вертикаль (Manufacturing, BOM, Routing, Job Cards):** Ни один из 18 generic-проектов (кроме ERPNext/Odoo) не имеет ни малейшего представления о раскрое ЛДСП, кромке ПВХ, фасадах МДФ, импорте БАЗИС XML и сменных заданиях на форматно-раскроечных станках.
   - **Автономия на объекте (Local-First On-Premise):** KORKEM физически развертывается на локальном узле в цехе, а мобильный клиент имеет автономный MutationOutbox. Подавляющее большинство систем (Twenty, Trigger.dev, Supabase, Langfuse) рассчитаны на облако.

2. **Главные архитектурные провалы KORKEM (WEAK / NONE):**
   - **Order State Machine (Конечный автомат заказа):** В KORKEM состояние заказа размазано по 12 сервисам. В Plane, Temporal, ERPNext и Medusa переход между фазами — это строгий контролируемый автомат с проверкой предусловий и прав.
   - **Event Bus & Transactional Outbox:** В KORKEM вызов событий синхронный и рискованный. В n8n, Temporal, Medusa, Trigger.dev события фиксируются транзакционно и исполняются асинхронно с гарантией доставки (At-Least-Once).
   - **Customer Timeline & Audit Trail:** В Twenty, Odoo и Plane любое действие фиксируется в сквозную ленту времени. В KORKEM аудит фрагментирован.
   - **Durable Background Jobs:** В Trigger.dev и Temporal сложные цепочки устойчивы к падениям за счет контрольных точек (Step Checkpointing). В KORKEM падение воркера при разборе БАЗИС XML требует начинать сначала.
   - **AI Observability:** В Langfuse каждый вызов модели и инструмента образует структурированный Trace. В KORKEM логи разрознены, нет связи между промптом и совершенным действием в ERP.
   - **Workflow Automation:** В n8n правила автоматизации создаются декларативно. В KORKEM автоматизации требуют хардкода в Python.
