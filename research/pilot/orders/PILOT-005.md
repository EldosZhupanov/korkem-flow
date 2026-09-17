# Pilot Order Journal: PILOT-005

**Sales Order Ref:** `SO-PILOT-2026-005`  
**Product Type:** Прямая кухня стандарт (ЛДСП Kronospan Антрацит + Белый Шагрень, столешница Скиф)  
**Customer Anonymized ID:** `CUST-AST-0105` (ЖК «Nova City», Астана)  
**Start Date:** 2026-09-17  
**Users Involved:**
- Менеджер: `ADMIN` (Айгерим)
- Замерщик: `MEASURER` (Ербол)
- Конструктор: `TECHNOLOGIST` (Арман)
- Раскрой: `CUTTING_OPERATOR` (Бауыржан)
- Кромка: `EDGEBANDING_OPERATOR` (Серик)
- Сборка: `ASSEMBLER` (Нурлан)
- Монтаж: `INSTALLER` (Руслан)
- Владелец: `OWNER` (Канат)

---

## 1. Lifecycle Stages & Status Tracking

| Этап | Дата / Время | Статус | Замечания / Трение / Ошибки |
| :--- | :--- | :--- | :--- |
| **1. Lead** | 2026-09-17 11:00 | **SUCCESS** | Заявка на типовую кухню 2400 мм под сдачу квартиры в аренду. |
| **2. Measurement** | 2026-09-17 12:30 | **SUCCESS** | Прямая стена, стандартные выводы воды и электрики. |
| **3. BASIS XML** | 2026-09-17 13:45 | **SUCCESS** | Использован типовой параметрический шаблон модулей. Экспорт без ошибок. |
| **4. Quote** | 2026-09-17 14:00 | **SUCCESS** | Смета: 430,000 ₸ (расхождение со сметой конструктора 0.0%). |
| **5. Contract & Deposit** | 2026-09-17 14:40 | **SUCCESS** | Аванс 70%: 301,000 ₸ зафиксирован. |
| **6. Reservation** | 2026-09-17 15:00 | **SUCCESS** | Зарезервированы плиты Kronospan и стандартные направляющие Boyard. |
| **7. Production Release** | 2026-09-17 15:15 | **SUCCESS** | Наряды сформированы. |
| **8. Cutting & Offcuts** | В очереди (18.09) | **PENDING** | Раскрой в плане на утро. |
| **9. Edgebanding** | В очереди (18.09) | **PENDING** | Кромление корпусов и фасадов. |
| **10. CNC Drilling** | В очереди (18.09) | **PENDING** | Присадка петель и ящиков. |
| **11. QC (ОТК цеха)** | В очереди (18.09) | **PENDING** | Проверка маркировки деталей наклейками со штрихкодами. |
| **12. Delivery** | В графике (19.09) | **PENDING** | Доставка заказчику. |
| **13. Installation** | В графике (20.09) | **PENDING** | Монтаж за 1 рабочий день. |
| **14. Final Payment & Act**| В графике (20.09) | **PENDING** | Окончательный расчет (129,000 ₸). |

---

## 2. Developer Intervention Record

- **Developer Intervention:** `false`
- **Reason:** N/A
- **Duration (minutes):** 0
- **Root Cause:** N/A
- **Severity:** NONE
