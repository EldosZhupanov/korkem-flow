# KORKEM Flow v2 — Release Engineering: Current State Audit
## Анализ текущей архитектуры релизов, платформ, артефактов и каналов дистрибуции

**Дата аудита:** 17 сентября 2026 г.  
**Роль:** Principal Software Architect, Release Engineer  
**Статус:** `AUDIT COMPLETE`  

---

## 1. СВОДНАЯ МАТРИЦА ПЛАТФОРМ И ТАРГЕТОВ (TARGET PLATFORMS MATRIX)

| Платформа | Таргет / Каталог | Текущий статус в коде | Механизм сборки | Артефакт дистрибуции | Текущий канал доставки |
|---|---|---|---|---|---|
| **Android** | `mobile/korkem_flow/android` | Полная конфигурация (SDK 36, R8 ProGuard) | `flutter build apk / appbundle` | `korkem-flow.apk`, `app-release.aab` | Прямая ссылка на сайте (`/files/korkem-flow.apk`), подготовка к Play Store |
| **iOS / iPhone** | `mobile/korkem_flow/ios` | Сконфигурирован (`Runner/Info.plist`, разрешения камеры, микрофона, фото) | `flutter build ios --release` | Runner.app / IPA | PWA на сайте (`korkem.asia`), подготовка к TestFlight |
| **Windows Desktop** | `mobile/korkem_flow/windows` | Сконфигурирован (Win32 runner, `Runner.rc`, CMake) | `flutter build windows --release` | `korkem-flow-windows-x64.zip` (`korkem_flow.exe` + DLLs) | Прямая ссылка на сайте (`/files/korkem-flow-windows-x64.zip`) |
| **Linux Desktop** | `mobile/korkem_flow/linux` | Базовый GTK runner (`CMakeLists.txt`) | `flutter build linux --release` | `bundle/korkem_flow` | Доступен для внутренней сборки разработчиков |
| **macOS Desktop** | Отсутствует | Каталог `macos/` не создан | N/A | N/A | Веб-портал PWA / Safari (`korkem.asia/app`) |
| **Web Portal** | `web/` | Next.js 15, React 19, Tailwind CSS 3.4 | `npm run build` (Docker) | Docker image `web:3000` | Caddy reverse proxy (`https://korkem.asia`) |
| **Backend API** | `backend/korkem_manufacturing`, `korkem_ai` | Frappe v17, ERPNext v17, CRM v2.0 | Python 3.14, bench migrations | Docker image `bench:8000` | Caddy reverse proxy (`https://api.korkem.asia`) |

---

## 2. ИССЛЕДОВАНИЕ ВЕРСИОНИРОВАНИЯ И РАССИНХРОНИЗАЦИИ (VERSION DRIFT AUDIT)

До настоящего момента в репозитории наблюдалась следующая разрозненность версий:

1. **Flutter Client (`mobile/korkem_flow/pubspec.yaml`):**
   - Указано: `version: 0.3.0+4` (версия 0.3.0, номер сборки 4).
   - Android `build.gradle.kts`: динамически считывает `flutter.versionCode` и `flutter.versionName`.
   - iOS `Info.plist`: динамически считывает `$(FLUTTER_BUILD_NAME)` и `$(FLUTTER_BUILD_NUMBER)`.
   - Windows `Runner.rc`: динамически использует макросы `FLUTTER_VERSION` и `FLUTTER_VERSION_BUILD`.
2. **Backend Apps (`pyproject.toml` и `__init__.py`):**
   - `korkem_manufacturing`: `__version__ = "0.0.1"`.
   - `korkem_ai`: `__version__ = "0.0.1"`.
   - Рассинхронизация: сервер декларировал версию `0.0.1`, в то время как клиенты были на `0.3.0`.
3. **Веб-сайт (`web/app/(public)/download/page.tsx`):**
   - Статически отображал `v0.3.0 Release` (Android, 68 МБ) и `v0.3.0 Desktop` (Windows, 30.6 МБ).
   - Ссылки вели на статические адреса `/files/korkem-flow.apk` и `/files/korkem-flow-windows-x64.zip`.
4. **Центр загрузок и манифесты (`latest.json`):**
   - Манифест `latest.json` или `version.json` на диске и веб-сервере отсутствовал.
   - Загрузки осуществлялись по жестко закодированным относительным путям.
5. **Серверная проверка обновлений (`App Release`):**
   - В `korkem_ai` реализован DocType `App Release` и эндпоинт `@frappe.whitelist(allow_guest=True) def latest(platform, build)`.
   - На клиенте Flutter реализован `UpdateRepository`, запрашивающий `/api/method/korkem_ai.korkem_ai.updates.latest`.
   - Однако в БД не были внесены актуальные записи опубликованных сборок `App Release`.

---

## 3. СЕТЕВАЯ МАРШРУТИЗАЦИЯ И РАЗДАЧА ФАЙЛОВ (ROUTING & FILE SERVING)

В конфигурации Caddy (`infra/frappe_bench/proxy/portal.Caddyfile`):
```caddy
@apk path *.apk
header @apk {
    Content-Type "application/vnd.android.package-archive"
    Content-Disposition "attachment; filename=korkem-flow.apk"
}

@backend_routes path /api/* /files/* /assets/* /desk*
handle @backend_routes {
    reverse_proxy bench:8000 { ... }
}

handle {
    reverse_proxy web:3000 { ... }
}
```
- Путь `/files/*` перенаправляется на Frappe Bench (`bench:8000`), который отдает файлы из `sites/korkem.localhost/public/files/`.
- Файлы, помещенные в каталог публичных файлов Frappe, мгновенно становятся доступны по HTTPS для скачивания через браузер и клиентский авто-апдейтер.
- Дополнительно Next.js отдает статические файлы из `web/public/` (например, `/downloads/latest.json`).

---

## 4. СТАТУС ПОДПИСАНИЯ И БЕЗОПАСНОСТИ (SIGNING & SECURITY STATUS)

- **Android:**
  - При отсутствии `android/key.properties` сборка APK использует дефолтный дебаг-сертификат, а сборка AAB жестко завершается с ошибкой в `build.gradle.kts` для предотвращения выгрузки неподписанного бандла в Play Console.
  - Поддерживается раздача чистого release APK для прямой установки сотрудниками цеха.
- **iOS:**
  - Файлы проекта `Runner.xcodeproj` и `Info.plist` полностью настроены.
  - В среде сборки Linux отсутствует Xcode и профайлы Apple Developer (TestFlight / App Store).
  - Статус: **`BUILD READY / SIGNING BLOCKED ON MACOS XCODE RUNNER`**. На сайте должно отображаться: *«iPhone — скоро в TestFlight / используйте PWA-версию»*.
- **Windows:**
  - Сборка формирует независимый переносимый каталог со всеми необходимыми DLL и манифестом без требования коммерческого EV-сертификата (с инструкцией обхода предупреждения SmartScreen).

---

## 5. ПЛАН СИНХРОНИЗАЦИИ РЕЛИЗА (RELEASE PLAN)

1. **Единый источник истины (Single Source of Truth):**
   - Зафиксировать релизную версию **`0.3.0`** (номер сборки `5`).
   - Создать канонический файл `release/VERSION`.
   - Синхронизировать `pubspec.yaml`, `pyproject.toml`, `__init__.py`, `latest.json`, `download/page.tsx`.
2. **Проверка API-совместимости Flutter:**
   - Проинспектировать все эндпоинты в `mobile/korkem_flow/lib/`.
   - Добавить/проверить клиентские вызовы для новых сервисов (Order Transitions, Stock Reservations, Offcuts, Piece-Work, QC, Payments, Dashboard).
3. **Генерация релизных артефактов и контрольных сумм:**
   - Собрать APK `korkem-flow-0.3.0.apk` и Windows/Linux артефакты;
   - Рассчитать SHA-256 хеши и выпустить `SHA256SUMS.txt`;
   - Сформировать манифест `downloads/latest.json`.
4. **Обновление веб-портала и страницы загрузки:**
   - Отображение актуальной версии `v0.3.0 (Build 5)`, даты релиза, точных размеров файлов и хешей SHA-256;
   - Замена устаревших ссылок на актуальные артефакты.
5. **Верификация и сквозное тестирование (Smoke & Migration Tests):**
   - Проверка чистой установки и обновления с сохранением данных.
