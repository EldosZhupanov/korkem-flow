# KORKEM Flow на Windows

Как один раз подготовить Windows-машину, собрать первый настоящий release
bundle и доказать наличие запускаемого `korkem_flow.exe`.

Официальные требования: [Flutter — Windows setup](https://docs.flutter.dev/platform-integration/windows/setup),
[Flutter — Windows build and distribution](https://docs.flutter.dev/platform-integration/windows/building).

---

## Что здесь проверено, а что нет

Фактическое состояние машины на **2026-09-02**:

| Проверка | Статус |
|---|---|
| Visual Studio + workload `Desktop development with C++` | **проверено**, Community 2022 17.14.33 |
| MSVC x64 / Windows SDK / CMake / Ninja | **проверено** |
| Git for Windows, JDK 21, Flutter SDK 3.44.8 для Windows | **проверено**, установлены |
| `flutter build windows --release` | **выполнено** |
| `korkem_flow.exe` | **получен**, 91 648 байт, `build\windows\x64\runner\Release\` |
| Приложение запускается | **проверено глазами**: окно «KORKEM Flow», форма входа, кириллица и Inter отрисованы; прожило 6.5 часов |
| Ворота Flutter на Windows (`analyze`, `format`, `test`) | **не выполнены** — см. «Здоровье машины»: на этой машине их результат недостоверен |
| Вход в приложение с Windows | **не проверен**, стенд живёт в WSL и наружу не открыт |

Сборка сделана с `--no-tree-shake-icons`: шрифты **не** ужаты, около 20 МБ
лишних ассетов. Это обход падений `font-subset.exe` (см. ниже), а не норма —
пересобрать без флага, когда машина будет здорова.

Linux Flutter из WSL (`~/development/flutter`, версия 3.44.8) использовать для
этой сборки нельзя. SDK содержит host tools для Linux; Windows build требует
отдельный Windows SDK с `flutter.bat` и Windows artifacts.

---

## Здоровье машины: читай это перед любым сообщением об ошибке

Относится к **этой конкретной машине** (ASUS TUF A16 FA607NUQ), а не к продукту.
На чистой машине ничего из раздела не нужно. Но пока работаешь на этой —
это первое, что надо исключать.

**Примерно 5% всех запусков процессов здесь падают с `0xC0000005`**
(`STATUS_ACCESS_VIOLATION`, он же `-1073741819`). Измерено 2026-09-02:

| что запускалось | падений |
|---|---|
| `cmd.exe /c exit 0` | 7 из 120 |
| `powershell.exe -Command "exit 0"` | 4 из 40 |
| `dart.exe --version` | 2 из 40 |

Падает не Flutter и не проект. В журнале Windows те же падения у `where.exe`,
`cmake.exe`, `netstat.exe`, `wsl.exe`. В отчёте WER у упавшего `where.exe` —
только модули Microsoft, сбойный модуль `unknown`, адрес в частной памяти:
портится память процесса на старте, чужая DLL не внедряется.

### Маски, которые принимает эта одна причина

Каждая из них выглядит как отдельная осмысленная проблема и ею не является:

* `MSB8066 ... exited with code -1073741819`
* `IconTreeShakerException: Font subsetting failed with exit code -1073741819`
* `Target kernel_snapshot_program failed: Exception` — тот же шаг проходил
  с третьей попытки без единой правки
* `ProcessStarter::StartForExec failed: Отказано в доступе (process_win.cc:703)`
* `Failed to update packages`, `Unable to generate build files`
* `FormatException: Unexpected extension byte` — **не кодировка.**
  Воспроизведено при уже выставленном `chcp 65001`; за исключением прятался
  крах дочернего процесса. Дефект `tool_backend.dart` (жёсткий `utf8.decoder`
  на выводе потомка) реален отдельно, но сборку ломал не он.

### Что проверено и отброшено

Чтобы никто не тратил на это время заново. Каждая гипотеза выглядела
убедительно и не подтвердилась измерением:

| гипотеза | итог |
|---|---|
| Нехватка памяти | **мимо.** Освобождение 9 ГБ (WSL 9→4 ГБ, `wsl --shutdown`, подкачка в ноль) не изменило частоту: те же 7 из 120 |
| Windows Defender | **мимо.** 5 из 100 в исключённом пути против 4 из 100 в обычном |
| Внедрённая DLL | **мимо.** `AppInit_DLLs` пуст, `LoadAppInit_DLLs=0`, в упавшем процессе только модули Microsoft |
| Exploit Protection | **мимо.** ASLR/DEP/CFG все `NOTSET` |
| Осиротевший драйвер `MEmuDrv` | **мимо.** Отключён (`Start=4`), после перезагрузки частота та же |
| Разгон памяти | нет: одна планка Micron 16 ГБ работает на 4800 из 5600 MT/s, ниже номинала |

**По исключению остаётся аппаратная нестабильность** — процессор, контроллер
памяти или планка. Косвенно: 73 исправленные ошибки WHEA (все от PCI Express
Root Port `VEN_1022&DEV_14B8`) и три внезапных выключения за август.
Проверяется `mdsched.exe` или MemTest86, 20+ минут. **Не выполнено**, решение
за владельцем машины.

### Как всё-таки собрать на такой машине

**Сборка инкрементальна между провалившимися попытками.** Каждый успешный
подшаг остаётся на диске — разрешение зависимостей, `flutter assemble`,
генерация CMake, каждый объектный файл MSVC. Поэтому цикл повторов сходится,
даже если ни один отдельный проход не выживает целиком. Ушло около 20 попыток.

Что уменьшает число запусков процессов за попытку:

* `--no-pub` — зависимости уже разрешены, `pub get` стоит десятков запусков;
* `--no-tree-shake-icons` — убирает четыре запуска `font-subset.exe`;
* обход проверок `WHERE` в `flutter.bat` (см. причину 1).

Две ловушки в самом цикле повторов:

1. **Нужен таймаут на попытку и добивание зависших процессов.** Упавший
   потомок оставляет `dart.exe` висеть с нулевым CPU, и `Start-Process -Wait`
   блокируется навсегда. Цикл выглядит работающим и стоит.
2. **Файлы `.bat` писать только латиницей.** Русский комментарий в UTF-8
   ломает разбор файла в `cmd`: переменная становится пустой, и цикл бодро
   запускает пустоту.

---

## Что установить за один заход

Все действия в этом разделе выполняются **из Windows**, не из PowerShell,
запущенного внутри WSL.

1. Открыть **Visual Studio Installer → Community 2022 → Modify**.
2. Отметить workload **Desktop development with C++**.
3. В Individual components убедиться, что включены:
   - MSVC v143 x64/x86 build tools;
   - C++ CMake tools for Windows;
   - Windows 11 SDK (уже стоит 10.0.26100.0).
4. Установить [Git for Windows](https://git-scm.com/download/win).
5. Из [Flutter SDK archive](https://docs.flutter.dev/install/archive?tab=windows)
   скачать **Windows stable 3.44.8** — ту же версию, которой сейчас проверен
   проект в WSL.
6. Распаковать SDK в каталог без пробелов и без прав администратора, например
   `C:\src\flutter`, и добавить `C:\src\flutter\bin` в пользовательский PATH.
7. Разместить checkout проекта на Windows filesystem, например
   `C:\src\furniture_ai`. Не собирать из UNC-пути
   `\\wsl.localhost\Ubuntu\...`: `cmd.exe` не принимает UNC как current
   directory, а CMake/MSBuild должны работать с одним нативным деревом.

Visual Studio workload можно поставить через UI — это предпочтительный первый
прогон, потому что Installer показывает размер и обязательную перезагрузку.
Его machine-readable ID:
`Microsoft.VisualStudio.Workload.NativeDesktop`.

---

## Проверка toolchain

Новый обычный PowerShell на Windows:

```powershell
flutter --version
flutter config --enable-windows-desktop
flutter doctor -v
flutter devices
```

Ожидается:

- Flutter `3.44.8`, channel `stable`, Windows host;
- зелёные секции `Windows Version` и
  `Visual Studio - develop Windows apps`;
- устройство с platform `windows`.

Если `flutter doctor -v` всё ещё сообщает об отсутствии Visual Studio, не
переходить к сборке: вернуться в Installer и поставить именно workload, а не
только отдельный compiler.

Дополнительная фактическая проверка компонентов:

```powershell
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

& $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Workload.NativeDesktop `
  -property installationPath

& $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.CMake.Project `
  -property installationPath
```

Обе команды должны напечатать путь установленной Visual Studio.

---

## Первая release-сборка

Работать из нативного Windows checkout нужного commit:

```powershell
cd C:\src\furniture_ai\mobile\korkem_flow

flutter pub get
flutter analyze
flutter test

flutter build windows --release `
  --dart-define=KORKEM_BASE_URL=https://erp.korkem.kz `
  --dart-define=KORKEM_FLAVOR=prod
```

`KORKEM_BASE_URL` — compiled default для первого входа. Для другой установки
заменить его на фактический публичный HTTPS host. Production flavor намеренно
не должен указывать на `localhost`, `.localhost` или HTTP.

Успешной сборкой считается не последняя строка Flutter, а найденный файл:

```powershell
$release = "build\windows\x64\runner\Release"
$exe = Join-Path $release "korkem_flow.exe"

if (-not (Test-Path $exe -PathType Leaf)) {
    throw "Windows build did not produce $exe"
}

Get-Item $exe | Format-List FullName,Length,LastWriteTime
& $exe
```

Ожидаемый executable:

```text
mobile\korkem_flow\build\windows\x64\runner\Release\korkem_flow.exe
```

Имя доказано из `windows\CMakeLists.txt` (`BINARY_NAME`) и
`windows\runner\Runner.rc`. Архитектурный каталог `x64` соответствует Flutter
3.44.x.

---

## Что передавать пользователю

`korkem_flow.exe` не является самодостаточным. Для запуска нужны лежащие рядом
Flutter/plugin DLL и каталог `data`. Передавать или архивировать нужно
**весь** каталог:

```text
build\windows\x64\runner\Release\
```

Минимальная проверка на второй Windows-машине:

1. распаковать весь Release-каталог;
2. запустить `korkem_flow.exe`;
3. войти на реальный HTTPS server;
4. проверить secure credential restore после перезапуска;
5. проверить открытие внешней ссылки и доступность диктовки.

Для поставки также нужен Microsoft Visual C++ Redistributable либо его
application-local DLL. Installer/MSIX и code signing — отдельное решение; они
не нужны, чтобы доказать первую настоящую `.exe` сборку.

---

## Что выяснилось при первой настоящей попытке (2026-09-02)

Восемь преград подряд, и ни одна не была видна заранее. Ниже — в том порядке,
в каком они встретились, с настоящими сообщениями: **почти каждое врало о
причине.**

### 1. Flutter сообщает «не найден git» о найденном git

Самая дорогая. Flutter сообщал по очереди:

```
Error: Unable to find git in your PATH.
Error: PowerShell executable not found.
Error: Unable to determine engine version...
```

**Ни одно не было правдой.** И git, и PowerShell стояли; `where git` находил
их в том же окне, где Flutter «не находил».

`flutter.bat` проверяет наличие обоих через `WHERE /Q` (строки 26 и 35) и
любой ненулевой код возврата читает как «инструмента нет». А `where.exe` на
этой машине **падает сам** — с `0xC0000005`, как и любой другой процесс здесь
(см. «Здоровье машины»). Flutter честно сообщает «не найдено», имея в виду
совсем другое.

> Раньше здесь было написано, что `WHERE` падает, наткнувшись на недоступную
> запись `PATH`, и что проверить это можно вызовом `where.exe powershell.exe`.
> **Это неверно.** Проверка не диагностична: она проходит в 95% случаев.
> Ошибка исправлена 2026-09-02 после измерения, а не рассуждения.

Задавать PATH целиком, а не дописывать, всё равно стоит — короткий и полный
PATH убирает целый класс других вопросов:

```powershell
$env:PATH = "C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;" +
            "C:\Windows\System32\WindowsPowerShell\v1.0;" +
            "C:\src\flutter\bin;C:\Program Files\Git\cmd;C:\src\jdk21\bin"
```

Но лечит здесь не он, а обход самой проверки.

### 2. Нужен JDK — и не потому, что мы пишем на Java

```
CMake Error: Could NOT find JNI (missing: JVM)
  flutter/ephemeral/.plugin_symlinks/jni/src/CMakeLists.txt:8 (project)
```

Цепочка, о которой невозможно догадаться:

```
flutter_secure_storage_windows ─┐
google_fonts ───────────────────┴→ path_provider → path_provider_android
                                   → jni_flutter → jni
```

Пакет `jni` объявляет себя плагином **и под Windows**, поэтому CMake требует
JVM на этапе настройки. Нужен он при этом только Android'у.

`JAVA_HOME` обязан быть выставлен, иначе генерация падает на `ZERO_CHECK`
с невнятным `MSB8066`. И **в каталоге JDK не должно быть символа `+`** —
Temurin распаковывается как `jdk-21.0.12.1+1`; переименуйте.

### 3. Git должен считать каталог Flutter своим

```
Error: The Flutter directory is not a clone of the GitHub project.
```

Видно только если запустить копию `flutter.bat` с `@echo on` — иначе Flutter
показывает предыдущее, ложное сообщение. Причина: SDK распакован из архива
(или из WSL), и Windows-git считает каталог чужим.

```powershell
git config --global --add safe.directory C:/src/flutter
```

Тот же дефект четыре раза ронял бэкенд в CI, только там uid раннера против uid
контейнера. **Одна природа, разные слова.**

### 4. Мелочи, которые стоили времени

* **`Expand-Archive` не справляется** с архивом на 1.8 ГБ — ни каталога, ни
  ошибки. Используйте `tar.exe`, он встроен в Windows 10/11.
* **Первичная настройка Flutter не терпит помех.** Запуск второй команды
  поверх неё оставляет `bin/cache/dart-sdk` пустым, после чего Flutter качает
  Dart SDK при каждом запуске и падает на сети. Дайте первому `flutter
  --version` доработать до конца.
* **Собирайте из `C:\...`, не из `\\wsl.localhost\...`** — `cmd.exe` не
  принимает UNC как текущий каталог, а CMake и MSBuild должны работать с одним
  нативным деревом.

## Ловушки

**Не вызывайте `wsl.exe` из PowerShell, запущенного из WSL.** Это вешает interop
bridge (`UtilAcceptVsock: accept4 failed 110`). Все команды сборки выше должны
идти из отдельного Windows Terminal/PowerShell.

**Linux Flutter — не кросс-компилятор Windows.** Наличие зелёного
`flutter analyze` в WSL ничего не говорит о C++ runner и Windows plugins.

**Не копируйте только `.exe`.** Без `flutter_windows.dll`, plugin DLL и `data`
приложение не запускается.

**Не называйте build успешным до `Test-Path` и запуска `.exe`.** Наличие
`windows/`, generated CMake и зелёных Dart tests доказывает готовность исходных
файлов, но не нативную линковку.

**Не собирайте production без настоящего HTTPS default.** Иначе первый запуск
смотрит на development host или приложение намеренно отказывает при старте.
