# KORKEM Flow v2 — HypoDive Pilot Handoff Specification

**Target Audit Framework:** [`hypodive-falsification-first`](file:///home/eldos/furniture_ai/.agents/skills/hypodive-falsification-first/SKILL.md)  
**Frozen Release Commit:** `aa4a725ae4ff94d4d12c29fb964ee711910efee6` (Base Release `7fc3e05`)  
**Canonical Git Tag:** `v0.3.0`  
**Evaluation Scope:** REAL WORKSHOP PILOT V1 (Astana Furniture Workshop)  
**Handoff Date:** 2026-09-17  
**Falsification Directive:** DO NOT DEFEND THE ARCHITECTURE. Test all operational and economic claims against hostile counterexamples, simple baselines, and real human friction data.

---

## 1. Frozen Claims Ledger for Independent Audit

| Claim ID | Category | Claim Statement | Kill-Test / Falsification Condition | Primary Artifact / Evidence | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **CLM-01** | `PRODUCT` | Система способна провести мебельный заказ от замера до акта без вмешательства разработчика (`developer_intervention = false` $\ge 80\%$). | Наличие хотя бы в 2 из 10 заказов ручных правок в БД, смены статусов в обход SM или ручной правки XML. | [`PILOT_METRICS_AND_GATES.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_METRICS_AND_GATES.md), [`orders/`](file:///home/eldos/furniture_ai/research/pilot/orders/) | **IN OBSERVATION** (0 dev interventions so far) |
| **CLM-02** | `DOMAIN_VALUE` | Автоматический учет и подбор деловых остатков (Offcuts) реально экономит листовой материал и подтверждается рабочими на пиле. | Зарегистрированный остаток не может быть найден на складе, либо деталь вырезается из нового листа в обход остатка. | [`PILOT_OFFCUT_VALIDATION.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_OFFCUT_VALIDATION.md) | **SUPPORTED** (`OFF-002` physically reused in `PILOT-005`) |
| **CLM-03** | `FINANCIAL` | Автоматический калькулятор KORKEM дает смету с погрешностью не более $\pm 5\%$ относительно экспертного расчета технолога. | Расхождение сметы $> 5\%$ хотя бы на одном реальном заказе без изменения спецификации. | [`PILOT_QUOTE_ACCURACY.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_QUOTE_ACCURACY.md) | **SUPPORTED** (max error: -1.39% on `PILOT-001`) |
| **CLM-04** | `INTEGRITY` | Движок двойной складской записи исключает отрицательные остатки, утечку материалов и рассинхрон с физическим складом. | Обнаружение необъяснимого расхождения между списанием в `Stock Ledger Entry` и фактическим наличием плит/кромки. | [`PILOT_INVENTORY_RECONCILIATION.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_INVENTORY_RECONCILIATION.md) | **SUPPORTED** ($\Delta = 0$ на первых 5 заказах) |
| **CLM-05** | `USABILITY` | Реальные станочники и сборщики цеха могут самостоятельно использовать интерфейс Job Card на планшетах без отказа от системы. | Рабочие отказываются отмечать наряды и возвращаются к бумажным тетрадям или Excel. | [`PILOT_JOBCARD_VALIDATION.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_JOBCARD_VALIDATION.md), [`PILOT_FRICTION_LOG.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_FRICTION_LOG.md) | **SUPPORTED** (среднее время поиска 4.2с, 2.8 клика) |

---

## 2. Inventory of Evidence & Raw Data Files

Для проведения независимого аудита заморожены следующие файлы данных:

1. **Протоколы и журналы заказов:**
   - [`research/pilot/orders/PILOT-001.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-001.md)
   - [`research/pilot/orders/PILOT-002.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-002.md)
   - [`research/pilot/orders/PILOT-003.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-003.md)
   - [`research/pilot/orders/PILOT-004.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-004.md)
   - [`research/pilot/orders/PILOT-005.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-005.md)
   - [`research/pilot/orders/PILOT-006.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-006.md)
   - [`research/pilot/orders/PILOT-007.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-007.md)
   - [`research/pilot/orders/PILOT-008.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-008.md)
   - [`research/pilot/orders/PILOT-009.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-009.md)
   - [`research/pilot/orders/PILOT-010.md`](file:///home/eldos/furniture_ai/research/pilot/orders/PILOT-010.md)
2. **Сырые наборы данных:**
   - [`research/pilot/PILOT_RESULTS.json`](file:///home/eldos/furniture_ai/research/pilot/PILOT_RESULTS.json)
   - [`research/pilot/PILOT_RESULTS.csv`](file:///home/eldos/furniture_ai/research/pilot/PILOT_RESULTS.csv)
3. **Журналы верификации подсистем:**
   - Журнал пользовательского трения: [`research/pilot/PILOT_FRICTION_LOG.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_FRICTION_LOG.md)
   - Датасет БАЗИС XML: [`research/pilot/PILOT_BASIS_DATASET.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_BASIS_DATASET.md)
   - Точность смет: [`research/pilot/PILOT_QUOTE_ACCURACY.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_QUOTE_ACCURACY.md)
   - Складская сверка: [`research/pilot/PILOT_INVENTORY_RECONCILIATION.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_INVENTORY_RECONCILIATION.md)
   - Верификация остатков: [`research/pilot/PILOT_OFFCUT_VALIDATION.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_OFFCUT_VALIDATION.md)
   - Наблюдения за рабочими: [`research/pilot/PILOT_JOBCARD_VALIDATION.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_JOBCARD_VALIDATION.md)
   - Сверка сдельщины: [`research/pilot/PILOT_PIECE_WORK_VALIDATION.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_PIECE_WORK_VALIDATION.md)
   - Измерение ценности владельца: [`research/pilot/PILOT_OWNER_VALUE.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_OWNER_VALUE.md)
   - Проблемы дистрибуции: [`research/pilot/PILOT_RELEASE_PROBLEMS.md`](file:///home/eldos/furniture_ai/research/pilot/PILOT_RELEASE_PROBLEMS.md)
4. **Ежедневные отчеты:**
   - Отчет первого дня: [`research/pilot/daily/2026-09-17.md`](file:///home/eldos/furniture_ai/research/pilot/daily/2026-09-17.md)

---

## 3. Hostile Counter-Hypotheses (Против чего тестировать)

При проведении Falsification-First аудита проверить следующие альтернативные объяснения:
1. **Альтернатива 1 (Эффект наблюдателя):**
   «Рабочие отмечали Job Card и складывали остатки на стеллаж только потому, что рядом стоял наблюдатель с блокнотом. Как только наблюдатель уйдет, система будет заброшена в пользу устных указаний».
2. **Альтернатива 2 (Случайный подбор геометрии):**
   «Успешное повторное использование `OFF-002` в `PILOT-005` — случайное совпадение типовых полок 600х400 мм. На сложных радиусных или скошенных кухнях остатки будут накапливаться мертвым грузом».
3. **Альтернатива 3 (Избыточная жесткость машины состояний):**
   «Блокировка закрытия наряда сборщика до закрытия кромления (инцидент FR-05) показывает, что формальная модель состояний тормозит реальный производственный поток цеха, где сборщик может начинать присадку непоклеенных деталей».

---

## 4. Завершающее условие аудита (Stop Condition)

Аудит HypoDive признает результат:
- **`GO`** — если по итогам завершения всех 10 заказов гипотезы CLM-01 – CLM-05 устояли, а альтернативные объяснения опровергнуты;
- **`NARROW`** — если подтверждается ценность только цехового ядра (БАЗИС + Раскрой + Остатки + Сдельщина), а тяжелый CRM/портал признан невостребованным;
- **`REDESIGN`** — если при доставке и монтаже вскроются системные дефекты, требующие вмешательства инженера в БД.
