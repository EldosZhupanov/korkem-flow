# KORKEM Flow v2 — Multi-Platform Release Report

**Release Version:** `0.3.0`  
**Build Number:** `5`  
**Release Date:** 2026-09-17  
**Author:** Principal Software Architect & Release Engineering  
**Verdict:** **GO (PRODUCTION RELEASE READY)**

---

## 1. Executive Summary

В рамках подготовки к реальному пилоту на мебельном производстве (Pilot v1) выполнен полный релизный цикл (**Release Engineering Pass**) KORKEM Flow v2.

Все компоненты экосистемы синхронизированы на единый источник истины — **версию `0.3.0` (сборка `5`)**:
1. **Backend**: приложения `korkem_manufacturing` и `korkem_ai` обновлены до `0.3.0`, миграции БД выполнены без сбоев (`bench migrate`), API сериализации `Sales Order` обогащено полями производственного цикла (`korkem_state`, `advance_paid`).
2. **Client Apps**:
   - **Android**: скомпилированы и валидированы релизный APK (`68.1 МБ`) и App Bundle AAB (`65.7 МБ`).
   - **Windows Desktop**: собран и упакован автономный x64 portable ZIP-архив (`30.6 МБ`).
   - **Linux Desktop**: скомпилирован и упакован автономный x64 tar.gz архив (`29.1 МБ`).
   - **iOS / Apple**: подготовлен проект `mobile/korkem_flow/ios`, зафиксирован статус (TestFlight в очереди на подписание; веб-клиент PWA полностью функционален на iPhone/iPad).
3. **Distribution & Web Download Center**:
   - Страница `/download` сайта `web` обновлена: добавлены карточки Android, Windows, Linux, актуальные размеры и контрольные суммы.
   - Опубликованы манифесты `latest.json` и `SHA256SUMS.txt`.
   - Внутренний механизм автообновления (`korkem_ai.korkem_ai.updates.latest`) синхронизирован с базой данных Frappe и протестирован через HTTP.

---

## 2. Single Source of Truth & Version Manifest

- **Центральный файл версионирования:** `release/VERSION`
  ```ini
  VERSION=0.3.0
  BUILD_NUMBER=5
  RELEASE_DATE=2026-09-17
  NAME=korkem-flow
  ```
- **Синхронизированные модули:**
  - `mobile/korkem_flow/pubspec.yaml`: `version: 0.3.0+5`
  - `backend/korkem_manufacturing/korkem_manufacturing/__init__.py`: `__version__ = "0.3.0"`
  - `backend/korkem_ai/korkem_ai/__init__.py`: `__version__ = "0.3.0"`
  - `web/package.json`: `"version": "0.3.0"`
  - `release/0.3.0/manifest/latest.json`: `"version": "0.3.0", "build_number": 5`

---

## 3. Platform Matrix & Artifact Inventory

| Платформа | Файл артефакта | Размер (байты) | Размер (МБ) | Статус | SHA-256 Контрольная сумма |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Android APK** | `korkem-flow.apk` (`korkem-flow-0.3.0-android.apk`) | 68,099,982 | 68.1 МБ | **Готов** | `a22a317e4ae6ca08d4f3edc96101f3e96d0f1f71ecbfe54553b5d2a7f3ab59aa` |
| **Android AAB** | `korkem-flow-0.3.0-android.aab` | 65,715,416 | 65.7 МБ | **Готов** | `3069a9d994a0cb99efb98c5dc6dffdc5786cf0eadc8ddc87168f645cc0a50f60` |
| **Windows Desktop** | `korkem-flow-windows-x64.zip` (`korkem-flow-0.3.0-windows-x64.zip`) | 30,617,591 | 30.6 МБ | **Готов** | `5a66e395d265b34def79f0c3f9562767f0a60764793055ed93ea0a9f8aafb295` |
| **Linux Desktop** | `korkem-flow-linux-x64.tar.gz` (`korkem-flow-0.3.0-linux-x64.tar.gz`) | 29,109,606 | 29.1 МБ | **Готов** | `bef4acfe319bd7097a17430098743e4cdd3b62b5875a7c055c2336fa8933e26e` |
| **iOS** | `mobile/korkem_flow/ios` | — | — | **TestFlight** / **PWA** | Исходный код готов, ожидает сертификата Apple Developer; PWA доступна |
| **Web** | `web/` (Next.js 15) | 15 routes | 109 kB | **Готов** | Статическая генерация и SSR без ошибок |

---

## 4. Backend & API Synchronization Verification

### 4.1. Изменения в API
- В файл `backend/korkem_manufacturing/korkem_manufacturing/api/queries.py` в массив `SALES_ORDER_FIELDS` добавлены поля:
  - `korkem_state`: статус сквозного производственного цикла заказа;
  - `advance_paid`: сумма внесенной предоплаты/аванса.

### 4.2. Миграция базы данных
- Выполнена миграция базы данных сайта `korkem.localhost`:
  ```bash
  bench --site korkem.localhost migrate
  ```
- Результат: схема синхронизирована, DocType `App Release` расширен опцией платформы `Linux`, системные дашборды и фикстуры обновлены.

### 4.3. Регрессионное тестирование бэкенда
- Запущен полный сквозной интеграционный тест производственного цикла:
  ```bash
  bench --site korkem.localhost run-tests --module korkem_manufacturing.korkem_manufacturing.doctype.sales_order.test_complete_furniture_order_lifecycle
  ```
- Результат: **5/5 тестов успешно пройдены** (17.7 с).

---

## 5. Mobile & Desktop Client Synchronization

### 5.1. Доменная модель и UI
- Файл `mobile/korkem_flow/lib/features/orders/domain/sales_order.dart`:
  - Добавлены поля `final String? korkemState` и `final double advancePaid`.
  - Реализован безопасный парсинг `korkem_state` и `advance_paid` из JSON ответа бэкенда.
- Файл `mobile/korkem_flow/lib/features/orders/presentation/order_detail_screen.dart`:
  - Добавлены визуальные чипы производственного статуса заказа (с локализованными наименованиями и цветовым кодированием).
  - Добавлен блок финансового статуса: сумма заказа, внесенный аванс и остаток задолженности.

### 5.2. Статический анализ и тесты клиента
- **Flutter Analyzer:**
  ```bash
  flutter analyze
  # Result: No issues found! (ran in 11.3s)
  ```
- **Golden & Widget Tests:**
  - Обновлены и верифицированы Golden-скриншоты (`--update-goldens`).
  - Тесты `materials_screen_test.dart` и `order_detail_screen_test.dart` успешно пройдены.

---

## 6. Distribution, In-App Updater & Web Verification

### 6.1. In-App Updater API
В базе данных зарегистрированы актуальные записи `App Release`:
- `Android-0.3.0` (версия 0.3.0, сборка 5, `/files/korkem-flow.apk`)
- `Windows-0.3.0` (версия 0.3.0, сборка 5, `/files/korkem-flow-windows-x64.zip`)
- `Linux-0.3.0` (версия 0.3.0, сборка 5, `/files/korkem-flow-linux-x64.tar.gz`)

**Тестирование эндпоинта `korkem_ai.korkem_ai.updates.latest`:**
- Запрос со старой сборки Android (`build=4`):
  ```json
  {"message":{"available":true,"platform":"Android","version":"0.3.0","build":5,"url":"http://korkem.localhost:8000/files/korkem-flow.apk","mandatory":false}}
  ```
- Запрос с актуальной сборки Android (`build=5`):
  ```json
  {"message":{"available":false,"platform":"Android","version":"0.3.0","build":5,...}}
  ```
- Запрос с Windows (`build=0`):
  ```json
  {"message":{"available":true,"platform":"Windows","version":"0.3.0","build":5,"url":"http://korkem.localhost:8000/files/korkem-flow-windows-x64.zip","mandatory":false}}
  ```

### 6.2. Проверка доступности скачивания файлов через HTTP
Все эндпоинты возвращают корректный `HTTP/1.1 200 OK` с точным `Content-Length`:
- `http://127.0.0.1:8000/files/korkem-flow.apk` (200 OK, 68,099,982 bytes)
- `http://127.0.0.1:8000/files/korkem-flow-windows-x64.zip` (200 OK, 30,617,591 bytes)
- `http://127.0.0.1:8000/files/korkem-flow-linux-x64.tar.gz` (200 OK, 29,109,606 bytes)
- `http://127.0.0.1:8000/files/latest.json` (200 OK, 2,065 bytes)
- `http://127.0.0.1:8000/files/SHA256SUMS.txt` (200 OK, 757 bytes)

### 6.3. Веб-портал (`web`)
- Страница `/download` оптимизирована под все платформы (Android, Windows, Linux, Apple/iOS, macOS).
- Сборка `npm run build` завершена успешно (15/15 страниц скомпилированы).

---

## 7. Installation & Upgrade Guidelines

### 7.1. Android (Чистая установка и обновление)
- **Установка:**
  1. Скачать `korkem-flow.apk` по ссылке из центра загрузок.
  2. Открыть файл и разрешить установку из источника (при запросе ОС).
  3. Запустить приложение, ввести URL сервера предприятия (`http://<ip>:8000` или домен).
- **Обновление:**
  - При наличии версии 0.2.x / сборки < 5 приложение автоматически получает сигнал через `updates.latest` и предлагает обновиться без потери локальных сессий.

### 7.2. Windows Desktop
- **Установка:**
  1. Скачать `korkem-flow-windows-x64.zip`.
  2. Распаковать архив в рабочую директорию пользователя.
  3. Запустить `korkem_flow.exe`. Приложение работает автономно, все зависимости (Flutter engine, ICU, runtime DLLs) включены в архив.

### 7.3. Linux Desktop
- **Установка:**
  1. Скачать `korkem-flow-linux-x64.tar.gz`.
  2. Распаковать: `tar -xzf korkem-flow-linux-x64.tar.gz`.
  3. Запустить: `./korkem_flow/korkem_flow`.

---

## 8. Rollback & Disaster Recovery Plan

1. **База данных:**
   - Перед проведением пилота создается резервная копия:
     ```bash
     bench --site korkem.localhost backup --with-files
     ```
2. **Откат релизных записей обновлений:**
   - В случае необходимости приостановки автообновления флаг `published` в `App Release` снимается:
     ```python
     frappe.db.set_value("App Release", "Android-0.3.0", "published", 0)
     frappe.db.commit()
     ```
3. **Откат клиентских версий:**
   - Предыдущая стабильная версия сохранена под тегом `korkem-v2-pilot1-freeze` (`commit 3e4df45`).

---

## 9. Final Verdict

| Критерий проверки | Результат |
| :--- | :--- |
| Версионирование синхронизировано (0.3.0+5) | **PASSED** |
| Бинарные сборки для Android, Windows, Linux созданы | **PASSED** |
| Контрольные суммы SHA-256 сверены и опубликованы | **PASSED** |
| Миграции базы данных Frappe применены | **PASSED** |
| Интеграционные тесты бэкенда пройдены | **PASSED (5/5)** |
| Статический анализ и тесты Flutter пройдены | **PASSED (0 errors)** |
| In-App Updater API протестирован | **PASSED** |
| Страница загрузки сайта обновлена и скомпилирована | **PASSED** |

**ФИНАЛЬНЫЙ ВЕРДИКТ: GO. Релиз KORKEM Flow v0.3.0 готов к передаче пользователям и запуску Pilot v1.**
