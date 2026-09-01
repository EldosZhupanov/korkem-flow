# Передача: первая сборка KORKEM Flow под Windows

**Кому:** агенту, работающему в PowerShell на Windows.
**От:** агента, работавшего в WSL. Дата: 2026-09-02.

Прочитай целиком до первой команды. Здесь десять причин, каждая из которых
уже стоила часов, и почти каждая **сообщала о себе неправдой**.

---

## 1. Что это за проект

KORKEM Flow — операционная система для мебельной фабрики. Один сервер
(Frappe/ERPNext в Docker), один Flutter-клиент под Android, Linux и теперь
Windows. Подробности: `PROJECT.md`, `PLAN.md`, `ROADMAP.md`, `NOW.md`,
`CLAUDE.md` — читать в этом порядке.

**Твоя задача — только одна:** получить работающий
`build\windows\x64\runner\Release\korkem_flow.exe` и убедиться, что он
**запускается**, а не просто существует. Собранный файл, который не
открывается, — не результат.

Не трогай `backend/`, `infra/`, не меняй зависимости, не обновляй пакеты.
Проект зелёный: 480 тестов Flutter, 1061 тест сервера, CI зелёный.
Если что-то ломается — ломается сборка под Windows, а не проект.

---

## 2. Где что лежит

| | путь |
|---|---|
| Проект (клон) | `C:\src\furniture_ai` |
| Flutter SDK 3.44.8 | `C:\src\flutter` |
| JDK 21 | `C:\src\jdk21` |
| Git for Windows | `C:\Program Files\Git\cmd` |
| Visual Studio 2022 Community | стандартный путь, `isComplete=True` |
| Готовый батник со всем окружением | `C:\src\r3.bat` |

**Важно:** `C:\src\furniture_ai` — это клон, сделанный из рабочей копии в WSL.
Он может отставать. Актуальный код в WSL:
`\\wsl.localhost\Ubuntu\home\eldos\furniture_ai`. Из UNC-пути **не собирай**
(см. причину 3), но сверить файлы оттуда можно.

---

## 3. Правильное окружение — целиком

```powershell
chcp 65001
$env:PATH = "C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;" +
            "C:\Windows\System32\WindowsPowerShell\v1.0;" +
            "C:\src\flutter\bin;C:\Program Files\Git\cmd;C:\src\jdk21\bin"
$env:JAVA_HOME = "C:\src\jdk21"
$env:FLUTTER_PREBUILT_ENGINE_VERSION = "0cd610717bde95fd88343c64f81c11ba4e5c0010"
cd C:\src\furniture_ai\mobile\korkem_flow
flutter build windows --release
```

Каждая строка здесь — снятая причина. Ниже объяснено, какая именно.

---

## 4. Десять причин, и что говорила каждая

### 1. Git не установлен
Тривиально. Поставлен.

### 2. Flutter SDK не установлен
Поставлен из архива в `C:\src\flutter`. **Скачивать пришлось через WSL:**
DNS Windows не разрешал `storage.googleapis.com` (перемежающийся сбой).

### 3. `cmd.exe` не принимает UNC-путь как текущий каталог
Собирать из `\\wsl.localhost\...` нельзя. Сообщение:
«CMD.EXE не поддерживает UNC». Кажется безобидным предупреждением — **не
безобидно**: ломает `WHERE`, см. причину 7.

### 4. Не установлена нагрузка Visual Studio «Desktop development with C++»
Плюс компонент «C++ CMake tools for Windows». Ставить **только через GUI
установщика**: тихий `vs_installer modify --quiet` упал с нарушением доступа
и оставил установку в состоянии `isComplete=False`, что пришлось чинить
«Восстановлением».

Проверка:
```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -format json | ConvertFrom-Json | % { $_.isComplete }
```
Должно быть `True`.

### 5. Не включён режим разработчика Windows
```
Building with plugins requires symlink support.
```
Win+R → `ms-settings:developers` → включить.

### 6. Git не признавал каталог Flutter своим
```
Error: The Flutter directory is not a clone of the GitHub project.
```
**Это сообщение видно только с включённым эхом** — обычный запуск показывает
предыдущее, ложное. Лечение:
```powershell
git config --global --add safe.directory C:/src/flutter
git config --global --add safe.directory C:/src/furniture_ai
```

### 7. PATH нужно задавать целиком, а не дописывать
Самая коварная. Flutter сообщал по очереди:
```
Error: Unable to find git in your PATH.
Error: PowerShell executable not found.
```
**Оба раза неправда.** И git, и PowerShell стояли; `where git` находил их в том
же окне. Причина: `flutter.bat` проверяет через `WHERE /Q`, а `WHERE`
**падает целиком**, наткнувшись на недоступную запись в PATH, печатая
«Отказано в доступе».

Проверка догадки: `where.exe powershell.exe`. Если «Отказано в доступе» —
дело в PATH, а не в том, о чём пишет Flutter.

### 8. Нужен JDK — и не потому, что мы пишем на Java
```
CMake Error: Could NOT find JNI (missing: JVM)
```
Цепочка, о которой невозможно догадаться:
```
flutter_secure_storage_windows ─┐
google_fonts ───────────────────┴→ path_provider → path_provider_android
                                   → jni_flutter → jni
```
`jni` объявляет себя плагином **и под Windows**. Нужен только Android'у.
`JAVA_HOME` обязателен. **В пути к JDK не должно быть `+`** — Temurin
распаковывается как `jdk-21.0.12.1+1`, переименован в `C:\src\jdk21`.

### 9. Падение декодера на кириллице
```
FormatException: Unexpected extension byte (at offset 120)
  _Utf8Decoder.convertChunked / _Socket._onData
```
`tool_backend.dart` читает вывод дочернего процесса как UTF-8, а на русской
Windows получает CP866. **`chcp 65001` снимает.**

**Это дефект, который ударит по клиенту:** у фабрики система будет русской или
казахской.

### 10. Ошибка в самом Flutter: версия вычисляется из пустоты
`bin/internal/content_aware_hash.ps1`, строка 57:
```powershell
$mergeBase = (git ... merge-base HEAD "$remote/master" 2>$null).Trim()
```
`.Trim()` у пустого результата → «Невозможно вызвать метод для выражения со
значением NULL». У SDK из архива нет ссылки `origin/master`, поэтому падает
**всегда**.

Последствие: в `bin\cache\flutter.version.json` записывалось
`"frameworkVersion": "0.0.0-unknown"`, и pub отвечал
«Try using the Flutter SDK version: 3.47.2».

А ещё скрипт считал хеш **пустой строки** —
`e69de29bb2d1d6434b8b29ae775ad8c2e48c5391`, известная константа git, — и
Flutter шёл качать несуществующий движок, получая `NoSuchKey`.

**Уже исправлено вручную.** Если увидишь `0.0.0-unknown` снова — проверь
`C:\src\flutter\bin\cache\flutter.version.json`, там должно быть:
```json
"frameworkVersion": "3.44.8",
"flutterVersion": "3.44.8",
"frameworkRevision": "058e0af2c2b57e369d905a03ac9748b0ebf543c6"
```

**Вывод для установки клиенту:** Flutter надо ставить **клонированием через
git**, а не из архива. Иначе получишь ровно это.

---

## 5. На чём стоим сейчас

Последняя ошибка:
```
error MSB8066: Custom build for '...flutter_assemble.rule' exited with code 5
```

**Код 5 — «Отказано в доступе».** Это прогресс: раньше был код 1 («сборка
провалилась»), теперь дошло до записи файлов.

Причина: каталоги создавались из WSL, и Windows не могла их перезаписать.
Перед передачей удалены:
`build\`, `windows\flutter\ephemeral\`, `.dart_tool\`.

**Первое, что сделай:** запусти сборку. Windows создаст их своими правами.
Если код 5 повторится — смотри владельца и права:
```powershell
icacls C:\src\furniture_ai\mobile\korkem_flow
```

---

## 6. Правила работы в этом проекте

Они не декоративные, каждое куплено ошибкой.

**Проверяй, а не верь сообщению.** Сегодня дважды: Flutter врал про git, а
golden-тест «чинился» обновлением эталона, которым стал экран в состоянии
ошибки. Если сообщение не сходится — включи эхо, открой картинку, посмотри
своими глазами.

**Читай весь вывод, а не хвост.** Коммит однажды заявил «analyze — No issues
found», когда первой строкой того же вывода стояло «1 issue found».

**Не запускай второе поверх первого.** Два прогона тестов на один стенд дают
`QueryDeadlockError`, который читается как дефект продукта. Для сервера есть
заслон: `infra/frappe_bench/scripts/run_tests.sh`. Для Flutter заслона нет —
проверяй руками, что ничего не идёт.

**Ничего не называй зелёным без прогона.** «Не проверено» — нормальный ответ.
Выдуманное «работает» — нет.

**Ворота Flutter — тремя отдельными командами:**
```powershell
flutter analyze                                # No issues found
dart format --set-exit-if-changed lib test
flutter test                                   # сейчас 480
```
**Никогда `--update-goldens`,** чтобы заглушить падающий эталон. Падение
эталона — вопрос «правильно ли изменился вид», а не рутина.

---

## 7. Что делать, когда `.exe` соберётся

1. **Запусти его.** Окно должно открыться с формой входа.
2. Скажи, что видно: форма, ошибка, пустой экран.
3. Не пытайся войти — сервер живёт в WSL и снаружи не виден
   (это отдельная работа, `ADR-0024`).
4. Отчитайся: что собралось, что запустилось, что нет.

Полный путь установки и ловушки: `docs/operations/WINDOWS_DESKTOP.md`.
