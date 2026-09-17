# Спецификация отказоустойчивых фоновых задач KORKEM (Durable Background Jobs)

**Дата:** 2026-09-16  
**Версия:** 2.0  
**Статус:** Нормативная спецификация фоновой обработки (Trigger.dev & Temporal concepts)  
**Проблема, которую решает:** Устранение падений при выполнении длительных, составных и ресурсоемких операций (импорт БАЗИС XML, AI-анализ чертежей, генерация смет, отправка сообщений) с сохранением контрольных точек шагов.

---

## 1. Архитектурный паттерн Step Checkpointing

Вместо монолитной фоновой функции, которая при малейшем сбое падает целиком, задача разбивается на именованные шаги (Steps). Результат каждого шага атомарно коммитится в таблицу `tabDurable Step Run`.

```python
def import_bazis_xml_job(job_context: DurableJobContext, file_path: str):
    # Шаг 1: Валидация и парсинг XML в структуры данных
    raw_data = job_context.step("parse_xml", lambda: parse_bazis_file(file_path))
    
    # Шаг 2: Создание или сопоставление материалов в номенклатуре ERP
    materials = job_context.step("resolve_materials", lambda: match_materials(raw_data.panels, raw_data.edges))
    
    # Шаг 3: Формирование многоуровневой спецификации изделия (BOM)
    bom_id = job_context.step("generate_bom", lambda: build_bom(raw_data, materials))
    
    # Шаг 4: Генерация сменных заданий (JobCards) по операциям
    job_context.step("create_job_cards", lambda: generate_job_cards(bom_id, raw_data.operations))
```

Если воркер упал на Шаге 4 (например, OOM или перезагрузка контейнера), при повторном запуске Шаги 1, 2 и 3 **НЕ ВЫПОЛНЯЮТСЯ ПОВТОРНО**, а мгновенно восстанавливают свои результаты из базы данных, продолжая выполнение ровно с Шага 4.

---

## 2. Перечень задач, требующих долговечного исполнения (Durable Jobs)

1. **Импорт файлов БАЗИС-Мебельщик (`bazis.import_xml`):**
   - До 200 деталей, 5 типов плит, 4 вида кромки, сложные присадки.
   - Шаги: `parse -> validate_geometry -> create_items -> create_bom -> create_routing`.
2. **AI-анализ фотографий замера (`ai.process_measurement_photos`):**
   - Пакет из 5–15 фотографий высокого разрешения.
   - Шаги: `strip_exif -> resize_and_compress -> detect_obstacles_vision -> attach_to_enquiry`.
3. **Транскрибация голосовых заметок мастера (`ai.transcribe_voice_note`):**
   - Аудиозапись из WhatsApp/Telegram.
   - Шаги: `download_audio -> whisper_transcription -> extract_measurements_intent -> create_capture`.
4. **Пакетная генерация коммерческих предложений и договоров (`documents.generate_pdf_bundle`):**
   - Сборка PDF со сметой, эскизом кухни, договором и счетом на оплату.
5. **Массовая рассылка уведомлений в WhatsApp (`channels.whatsapp_bulk_dispatch`):**
   - Отправка напоминаний о готовности или актах приема с соблюдением лимитов WhatsApp API (rate limiting: 1 сообщение в 2 секунды).

---

## 3. Политика повторов (Retry Policy with Jitter)

Каждая задача и каждый шаг конфигурируются параметрами устойчивости:

```python
@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int = 5                  # Максимум 5 попыток
    initial_interval_sec: float = 2.0      # Начальная задержка 2 сек
    backoff_coefficient: float = 2.0       # Экспоненциальный множитель x2
    max_interval_sec: float = 300.0        # Максимальная задержка 5 минут
    jitter: float = 0.2                    # Случайный разброс 20% (защита от Thundering Herd)
```

Формула вычисления интервала перед попыткой $N$:
$$T_{wait} = \min(T_{init} \cdot K_{backoff}^{N-1}, T_{max}) \cdot (1 \pm \text{jitter})$$

---

## 4. Схема персистентного хранения задач и шагов

### Таблица `tabDurable Job Run`
- `name` (PK): `job-<uuid>`
- `job_type`: `bazis_xml_import`, `ai_photo_processing`, `pdf_generation`
- `idempotency_key`: Клиентский ключ дедупликации (индексирован)
- `status`: `PENDING` -> `RUNNING` -> `COMPLETED` / `FAILED` / `DEAD_LETTER`
- `current_step`: Имя текущего исполняемого шага
- `attempt`: Текущая попытка (1..5)
- `payload_json`: Входные параметры задачи
- `result_json`: Финальный результат выполнения
- `error_traceback`: Стектрейс ошибки при сбое
- `timeout_seconds`: Жесткий дедлайн выполнения (например, 600 сек)

### Таблица `tabDurable Step Run`
- `name` (PK): `step-<uuid>`
- `parent_job`: Ссылка на `Durable Job Run`
- `step_name`: Имя шага (`parse_xml`, `create_items`)
- `status`: `COMPLETED` | `FAILED`
- `result_json`: Сериализованный результат возврата функции шага
- `duration_ms`: Время выполнения конкретного шага
