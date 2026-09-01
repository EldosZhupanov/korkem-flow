# KORKEM Flow на Windows

Как один раз подготовить Windows-машину, собрать первый настоящий release
bundle и доказать наличие запускаемого `korkem_flow.exe`.

Официальные требования: [Flutter — Windows setup](https://docs.flutter.dev/platform-integration/windows/setup),
[Flutter — Windows build and distribution](https://docs.flutter.dev/platform-integration/windows/building).

---

## Что здесь проверено, а что нет

Фактическое состояние машины на **2026-09-01**:

| Проверка | Статус |
|---|---|
| Windows доступна из WSL через PowerShell | **проверено**, Windows 10.0.26100.9168, PowerShell 5.1.26100.9168 |
| Visual Studio | **проверено**, Community 2022 17.14.33, установка complete/launchable |
| MSVC x64 | **проверено**, tools 14.44.35207 и `cl.exe` присутствуют |
| Windows SDK | **проверено**, 10.0.26100.0 и x64 libraries присутствуют |
| Workload `Desktop development with C++` | **не установлен**, `vswhere -requires Microsoft.VisualStudio.Workload.NativeDesktop` не нашёл instance |
| CMake/Ninja для Visual Studio | **не установлены**, компонент `Microsoft.VisualStudio.Component.VC.CMake.Project` отсутствует и executables не найдены |
| Git for Windows | **не установлен / не доступен**, `Get-Command git` и поиск `git.exe` ничего не нашли |
| Flutter SDK для Windows | **не установлен**, `flutter` не в PATH, `flutter.bat` не найден в профилях и обычных каталогах |
| Windows target проекта | **проверено в Git**, binary name `korkem_flow`, три native plugin и один FFI plugin зарегистрированы |
| `flutter doctor -v` на Windows | **не выполнено**, Windows Flutter отсутствует |
| `flutter build windows` | **не выполнено**, нет Windows Flutter и CMake toolchain |
| `korkem_flow.exe` | **не получен** |

Linux Flutter из WSL (`~/development/flutter`, версия 3.44.8) использовать для
этой сборки нельзя. SDK содержит host tools для Linux; Windows build требует
отдельный Windows SDK с `flutter.bat` и Windows artifacts.

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

### 1. PATH обязан быть полным, и лучше задать его целиком

Самая дорогая. Flutter сообщал по очереди:

```
Error: Unable to find git in your PATH.
Error: PowerShell executable not found.
Error: Unable to determine engine version...
```

**Ни одно не было правдой.** И git, и PowerShell стояли; `where git` находил
их в том же окне, где Flutter «не находил». Причина: `flutter.bat` проверяет
наличие через `WHERE /Q`, а `WHERE` перебирает записи `PATH` и **падает
целиком**, наткнувшись на недоступную — печатая «Отказано в доступе» и
возвращая ошибку. Дальше Flutter честно сообщает «не найдено», имея в виду
совсем другое.

Поэтому PATH задаётся **целиком, а не дописывается**:

```powershell
$env:PATH = "C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;" +
            "C:\Windows\System32\WindowsPowerShell\v1.0;" +
            "C:\src\flutter\bin;C:\Program Files\Git\cmd;C:\src\jdk21\bin"
```

Проверить догадку на чужой машине: `where.exe powershell.exe`. Если она
отвечает «Отказано в доступе» — дело в PATH, а не в том, о чём пишет Flutter.

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
  принимает UNC как текущий каталог, и это ломает `WHERE` (см. п. 1).

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
