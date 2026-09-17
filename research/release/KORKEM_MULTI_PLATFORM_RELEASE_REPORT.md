# KORKEM Flow v2 — Multi-Platform Release Report

**Release Version:** `0.3.0`  
**Build Number:** `5`  
**Release Date:** 2026-09-17  
**Git Branch:** `dev`  
**Release Commit:** `7fc3e05ae2c8cfb1f49a53b2de49e08c89d357cd`  
**Canonical Git Tag:** `v0.3.0` (also tagged `korkem-v0.3.0-release`)  
**Production Domain:** `korkem.asia` / `api.korkem.asia` (IP: `84.235.253.172`)  
**Deployment Timestamp:** 2026-09-17T19:20:15+05:00  
**Author:** Principal Software Architect & Release Engineering  
**Verdict:** **PUBLIC RELEASE READY — IOS DISTRIBUTION PENDING**

---

## 1. Executive Summary

В рамках подготовки к реальному пилоту на мебельном производстве (Pilot v1) выполнен полный релизный цикл (**Release Engineering Pass**) и **Final Public Release Deployment Gate** KORKEM Flow v2.

Все компоненты экосистемы синхронизированы на единый источник истины — **версию `0.3.0` (сборка `5`)**:
1. **Backend (Production)**:
   - Развернут на боевом сервере `84.235.253.172` (`api.korkem.asia`).
   - Версии приложений `korkem_manufacturing` и `korkem_ai` зафиксированы на `0.3.0`.
   - Миграции базы данных применены без ошибок (`bench --site api.korkem.asia migrate`).
   - Добавлены поля `Sales Order.korkem_state` и `advance_paid` для машины состояний мебельного цикла.
   - Зарегистрированы все 10 производственных DocType (`Sales Order`, `Stock Offcut`, `Stock Reservation`, `Stock Entry`, `Job Card`, `App Release`, `Domain Outbox Event`, `Domain Outbox Delivery`, `Durable Job Run`, `Durable Step Run`).
   - Верифицированы 9 hardened Domain AI Tools с защитой R10 Human Approval Gate.
2. **Client Apps & Binaries**:
   - **Android**: Официальный APK (`68.1 МБ`) и App Bundle AAB (`65.7 МБ`), подписанные релизным RSA-4096 сертификатом (`kz.korkem.korkem_flow`, versionCode 5, versionName 0.3.0).
   - **Windows Desktop**: Портативный x64 ZIP-архив (`30.6 МБ`) со всеми рантайм-библиотеками и ассетами.
   - **Linux Desktop**: Автономный x64 tar.gz архив (`29.1 МБ`).
   - **iOS / Apple**: Исходный код нативного Runner готов к подписи в Apple Developer Program; мобильный PWA-клиент полностью доступен прямо сейчас через Safari.
3. **Distribution & Public Download Center**:
   - Официальный сайт `https://korkem.asia/download` полностью пересобран и развернут.
   - Все 5 кнопок скачивания протестированы с внешней точки: прямые URL отдают `HTTP/2 200 OK` с точным соответствием размера и SHA-256.
   - Манифесты `https://korkem.asia/files/latest.json` и `https://korkem.asia/downloads/SHA256SUMS.txt` опубликованы.
   - Механизм In-App Updater протестирован через боевой API: старая сборка 4 получает уведомление об обновлении, актуальная сборка 5 не перезагружается.

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
| **Android APK** | `korkem-flow.apk` (`korkem-flow-0.3.0-android.apk`) | 68,099,982 | 68.1 МБ | **AVAILABLE** | `a22a317e4ae6ca08d4f3edc96101f3e96d0f1f71ecbfe54553b5d2a7f3ab59aa` |
| **Android AAB** | `korkem-flow-0.3.0-android.aab` | 65,715,416 | 65.7 МБ | **AVAILABLE** | `3069a9d994a0cb99efb98c5dc6dffdc5786cf0eadc8ddc87168f645cc0a50f60` |
| **Windows Desktop** | `korkem-flow-windows-x64.zip` (`korkem-flow-0.3.0-windows-x64.zip`) | 30,617,591 | 30.6 МБ | **AVAILABLE** | `5a66e395d265b34def79f0c3f9562767f0a60764793055ed93ea0a9f8aafb295` |
| **Linux Desktop** | `korkem-flow-linux-x64.tar.gz` (`korkem-flow-0.3.0-linux-x64.tar.gz`) | 29,109,606 | 29.1 МБ | **AVAILABLE** | `bef4acfe319bd7097a17430098743e4cdd3b62b5875a7c055c2336fa8933e26e` |
| **iOS** | `mobile/korkem_flow/ios` | — | — | **DISTRIBUTION_PENDING** | Исходный код готов, ожидает Apple Developer ID; PWA доступна |
| **macOS** | Web Portal / PWA | — | — | **AVAILABLE (Web/PWA)** | Нативный десктопный бинарник отсутствует, работает через браузер |
| **Web** | `web/` (Next.js 15) | 15 routes | 109 kB | **AVAILABLE** | Статическая компиляция и SSR без ошибок |

---

## 4. Backend & API Synchronization Verification

### 4.1. Изменения в API
- В файл `backend/korkem_manufacturing/korkem_manufacturing/api/queries.py` в массив `SALES_ORDER_FIELDS` добавлены поля:
  - `korkem_state`: статус сквозного производственного цикла заказа;
  - `advance_paid`: сумма внесенной предоплаты/аванса.

### 4.2. Миграция базы данных (Production)
- Выполнена боевая миграция базы данных сайта `api.korkem.asia`:
  ```bash
  bench --site api.korkem.asia migrate
  ```
- Результат: схема синхронизирована, патч `add_korkem_state_to_sales_order` применен, DocType `App Release` расширен платформой `Linux`.

### 4.3. Регрессионное тестирование
- Запущен полный сквозной интеграционный тест производственного цикла:
  ```bash
  bench run-tests --module korkem_manufacturing.korkem_manufacturing.doctype.sales_order.test_complete_furniture_order_lifecycle
  ```
- Результат: **5/5 тестов успешно пройдены** (17.7 с).

---

## 5. Mobile & Desktop Client Synchronization

### 5.1. Доменная модель и UI
- Файл `mobile/korkem_flow/lib/features/orders/domain/sales_order.dart`:
  - Добавлены поля `final String? korkemState` и `final double advancePaid`.
  - Реализован безопасный парсинг `korkem_state` и `advance_paid` из JSON ответа бэкенда.
- Файл `mobile/korkem_flow/lib/features/orders/presentation/order_detail_screen.dart`:
  - Добавлены визуальные чипы производственного статуса заказа с цветовым кодированием.
  - Добавлен блок финансового статуса: сумма заказа, внесенный аванс и остаток задолженности.

### 5.2. Статический анализ и тесты клиента
- **Flutter Analyzer:** `flutter analyze` — **0 замечаний** (11.3 с).
- **Golden & Widget Tests:** верифицированы `materials_screen_test.dart` и `order_detail_screen_test.dart`.

---

## 6. Android Signature & Security Verification

Проверено с помощью официального `apksigner` и `aapt2`:
- **Статус верификации подписи:** `Verified using v2 scheme (APK Signature Scheme v2): true`
- **Количество подписей:** 1
- **Субъект сертификата:** `CN=Eldos, OU=Korkem, O=korkemprod, L=Astana, ST=Unknown, C=010000`
- **Алгоритм ключа:** RSA 4096-bit
- **SHA-256 отпечаток сертификата:** `2eebacde6a500522ddabcec363b7e50fa9cc9772c2b27bcee16726e62ffae719`
- **Package ID:** `kz.korkem.korkem_flow`
- **versionCode:** `5`
- **versionName:** `0.3.0`
- **Совместимость обновления:** Сертификат полностью идентичен предыдущему production-релизу. Обновление со сборки 4 на сборку 5 устанавливается поверх без переустановки, сохраняя все локальные сессии и кэш.

---

## 7. Windows Release Inspection

- **Архив:** `korkem-flow-windows-x64.zip` (30,617,591 байт)
- **Состав архива:**
  - `korkem_flow.exe` (91,648 байт) — главный исполняемый файл приложения;
  - `flutter_windows.dll` (21.2 МБ) — графический движок Flutter;
  - `dartjni.dll`, `flutter_secure_storage_windows_plugin.dll`, `speech_to_text_windows_plugin.dll`, `url_launcher_windows_plugin.dll`;
  - `data/app.so`, `data/icudtl.dat`, `data/flutter_assets/`.
- **Запуск:** Не требует инсталлятора, распаковывается в любую директорию.
- **Статус подписи (Honesty):** Исполняемый файл не подписан коммерческим сертификатом Microsoft Authenticode. При первом запуске фильтр Windows SmartScreen выведет предупреждение; пользователь нажимает «Подробнее» → «Выполнить в любом случае» (инструкция размещена в FAQ на сайте).

---

## 8. Distribution, In-App Updater & Web Verification

### 8.1. In-App Updater API (Production)
В базе данных `api.korkem.asia` зарегистрированы актуальные записи `App Release`:
- `Android-0.3.0` (версия 0.3.0, сборка 5, `/files/korkem-flow.apk`)
- `Windows-0.3.0` (версия 0.3.0, сборка 5, `/files/korkem-flow-windows-x64.zip`)
- `Linux-0.3.0` (версия 0.3.0, сборка 5, `/files/korkem-flow-linux-x64.tar.gz`)

**Тестирование боевого эндпоинта:**
- Запрос со старой сборки Android (`build=4`):
  ```json
  {"available": true, "platform": "Android", "version": "0.3.0", "build": 5, "url": "https://api.korkem.asia/files/korkem-flow.apk", "mandatory": false}
  ```
- Запрос с актуальной сборки Android (`build=5`):
  ```json
  {"available": false, "platform": "Android", "version": "0.3.0", "build": 5, ...}
  ```

---

## 9. Backup & Rollback Plan

### 9.1. Резервная копия перед релизом
- **Время создания:** 2026-09-17 19:11:03
- **Местоположение на сервере:** `/home/ubuntu/backups/pre_v0.3.0/`
- **Состав архивов:**
  - База данных: `20260917_191059-api_korkem_asia-database.sql.gz` (`1.2 MiB`, не пустая)
  - Публичные файлы: `20260917_191059-api_korkem_asia-files.tar` (`187.6 MiB`)
  - Приватные файлы: `20260917_191059-api_korkem_asia-private-files.tar` (`10.0 KiB`)
  - Конфигурация: `20260917_191059-api_korkem_asia-site_config_backup.json` (`410 B`)

### 9.2. Процедура отката (Rollback Procedure)
В случае обнаружения P0-дефекта во время пилота:
1. Переключить код бэкенда на точку отката:
   ```bash
   cd /home/ubuntu/korkem-flow && git checkout pre-v0.3.0-rollback
   ```
2. Восстановить базу данных:
   ```bash
   docker exec -i korkem-bench-bench-1 bench --site api.korkem.asia restore /home/frappe/frappe-bench/sites/api.korkem.asia/private/backups/20260917_191059-api_korkem_asia-database.sql.gz
   ```
3. Отключить автообновление клиентов:
   ```python
   frappe.db.set_value("App Release", "Android-0.3.0", "published", 0)
   frappe.db.commit()
   ```

---

## 10. PUBLIC RELEASE VERIFICATION

Таблица сквозной внешней проверки скачивания и установки из открытого интернета:

| Platform | Version | Build | Signed | Public URL | HTTP | SHA256 Verified | Fresh Install | Upgrade | Real Device Tested | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Android** | 0.3.0 | 5 | Yes (RSA-4096) | `https://korkem.asia/files/korkem-flow.apk` | **200 OK** | **PASSED** (`a22a31...`) | Yes | Yes (from v4) | Yes (Samsung/Pixel) | **AVAILABLE** |
| **Windows** | 0.3.0 | 5 | Unsigned | `https://korkem.asia/files/korkem-flow-windows-x64.zip` | **200 OK** | **PASSED** (`5a66e3...`) | Yes | Yes (Portable) | Yes (Win 11 x64) | **AVAILABLE** |
| **Linux** | 0.3.0 | 5 | N/A (tar.gz) | `https://korkem.asia/files/korkem-flow-linux-x64.tar.gz` | **200 OK** | **PASSED** (`bef4ac...`) | Yes | Yes (Portable) | Yes (Ubuntu 24.04) | **AVAILABLE** |
| **iOS** | 0.3.0 | 5 | Pending Apple | `https://korkem.asia/download` | **200 OK** | N/A | PWA | PWA | Yes (Safari iOS 17) | **DISTRIBUTION_PENDING** |
| **macOS** | 0.3.0 | 5 | N/A (Web/PWA) | `https://korkem.asia/app` | **200 OK** | N/A | Web/PWA | Web/PWA | Yes (Chrome/Safari) | **AVAILABLE (Web/PWA)** |
| **Manifest**| 0.3.0 | 5 | N/A (JSON) | `https://korkem.asia/files/latest.json` | **200 OK** | **PASSED** (`798836...`) | N/A | N/A | Verified by Updater | **AVAILABLE** |
| **Checksums**| 0.3.0| 5 | N/A (TXT) | `https://korkem.asia/downloads/SHA256SUMS.txt` | **200 OK** | **PASSED** (`f071a5...`) | N/A | N/A | Verified by curl | **AVAILABLE** |

### Ключевые параметры развертывания
- **Production Domain:** `korkem.asia`, `api.korkem.asia`, `www.korkem.asia`
- **TLS Terminator:** Caddy 2 с автоматическими сертификатами Let's Encrypt (HSTS, HTTP/2).
- **Release Commit:** `7fc3e05ae2c8cfb1f49a53b2de49e08c89d357cd`
- **Git Tag:** `v0.3.0`
- **Deployment Timestamp:** 2026-09-17T19:20:15+05:00
- **Rollback Version:** `pre-v0.3.0-rollback` (`commit 8ee0b45`)
- **Backup Status:** Полный бэкап БД и файлов сохранен и верифицирован.

---

## 11. Final Verdict

**ВЕРДИКТ:**  
# **PUBLIC RELEASE READY — IOS DISTRIBUTION PENDING**

- Клиенты для **Android**, **Windows** и **Linux** полностью собраны, развернуты и доступны для скачивания через официальный веб-сайт `https://korkem.asia/download`.
- Боевой бэкенд на `https://api.korkem.asia` успешно мигрирован, протестирован и синхронизирован.
- Нативная сборка iOS Runner ожидает корпоративного подписания в Apple Developer Program; мобильный доступ с устройств Apple полностью обеспечен через PWA.
- Для реального мебельного пилота (**PILOT V1**), проводимого в цеху на планшетах/смартфонах Android и ПК Windows, система на 100% укомплектована и готова.

**РАЗРАБОТКА ОСТАНОВЛЕНА.**  
Новые фазы и архитектурные изменения не инициируются.  
Следующий этап — запуск **REAL WORKSHOP PILOT V1**.
