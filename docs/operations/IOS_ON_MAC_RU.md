# KORKEM на iPhone: передача работы на MacBook

Дата: 2026-09-10. Статус: **PREPARED, NOT MAC/DEVICE VERIFIED**.
Это сборка iOS-клиента существующего KORKEM, не новая программа и не хостинг
Render. Backend остаётся на действующем сервере. Поднимать bench на Mac не нужно.

## 1. Что подготовлено и чего ещё нет

- Проект: mobile/korkem_flow; Flutter **3.44.8**, Dart **3.12.2**,
  зависимости сохранены в pubspec.lock.
- ios/ создан штатным Flutter-шаблоном: Swift AppDelegate и SceneDelegate,
  Xcode project/workspace, Swift Package Manager и Podfile для fallback-плагинов.
- Минимум **iOS 15.0**, требуемый установленными Firebase-плагинами.
- Предварительный Bundle ID: **asia.korkem.korkemFlow**. Это не зарегистрированный
  Apple App ID: доступность и выбранную Team нужно проверить на Mac.
- Иконка и launch screen KORKEM; камера, фотогалерея, микрофон, распознавание
  речи и описание доступа к локальной сети; системные тексты ru/kk/en.
- Keychain entitlement подключён для Debug/Profile/Release.
- ATS не ослаблен: основной путь первого запуска — **https://api.korkem.asia**.
  HTTP-узлы в LAN этим этапом не поддержаны; описание Local Network само по себе
  не разрешает HTTP и не доказывает offline.

**Ещё не проверено:** компиляция Xcode, подпись, Simulator, настоящий iPhone,
Keychain после перезапуска, камера, диктовка и устройство без интернета.
Нет .ipa, TestFlight и публикации в App Store.

Firebase Core/Messaging уже были в проекте, этим этапом не добавлялись.
Без GoogleService-Info.plist существующий код отказывается от push и продолжает
работу. APNs, push capability и background delivery **не настроены** и не
входят в первую сборку. Не добавлять фиктивный Firebase-конфиг ради зелёного запуска.
Поддержка казахского интерфейса не означает, что системная диктовка поддерживает
казахский: это отдельно проверяется на конкретном iPhone.

## 2. Перенести актуальные исходники

Обычный git clone не получает незакоммиченные изменения из WSL.
Предпочтительный постоянный путь — ревью и явный коммит нужных файлов, затем
clone на Mac. Коммиты и push в этой подготовке не выполняются.

Для первого запуска есть переносимый **снимок клиента**. В WSL, из корня:

```sh
python3 scripts/package_ios_handoff.py dist/ios/korkem-ios-handoff-2026-09-10.zip
```

Скрипт включает текущие исходники, в том числе новые файлы, и пишет SHA-256.
Повторный запуск с тем же именем откажет: выбрать новое имя, не перезаписывать
единственный переданный снимок.

Файл в Проводнике Windows:

```text
\\wsl.localhost\Ubuntu\home\eldos\furniture_ai\dist\ios\korkem-ios-handoff-2026-09-10.zip
```

Передать архив на Mac обычным способом. SSH-ключи Oracle, .env и Apple-пароли
для этого не нужны. В архиве нет backend, Git-истории, SDK, build, Pods и ключей.
Это не полный monorepo; нельзя пытаться запускать из него backend-проверки.
Снимок содержит основной контекст проекта и выбранные проектные skills.

На Mac проверить SHA-256 архива против значения, показанного в WSL:

```sh
shasum -a 256 ~/Downloads/korkem-ios-handoff-2026-09-10.zip
mkdir -p ~/Projects
unzip -n ~/Downloads/korkem-ios-handoff-2026-09-10.zip -d ~/Projects
cd ~/Projects/korkem-ios-handoff
```

Использовать новую папку: не накладывать архив на старую работу.
SOURCE_MANIFEST.json содержит SHA-256 каждого включённого файла и исходный Git SHA.

## 3. Подготовить Mac — один раз

1. Проверить модель Mac и macOS: меню Apple → «Об этом Mac».
   Нужна macOS, поддерживаемая выбранной версией Xcode.
2. Установить **полный Xcode** из Mac App Store, открыть его и завершить установку.
   Одних Command Line Tools недостаточно.
3. Выбрать Xcode и установить компоненты:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license
xcodebuild -downloadPlatform iOS
```

Лицензию читает и принимает владелец, не агент автоматически.

4. Установить Flutter **3.44.8 stable** из официального архива SDK:
   Apple Silicon — arm64, Intel — x64. Добавить его bin в PATH по инструкции Flutter.
   Не переносить Linux Flutter из WSL, не делать flutter upgrade в первом прогоне.
   Например, распаковать папку flutter в ~/development/flutter и в терминале выполнить:

```sh
export PATH="$HOME/development/flutter/bin:$PATH"
flutter --version
```

   Для новых окон терминала добавить ту же строку export в ~/.zshrc через редактор,
   не перезаписывая существующий файл.
5. Установить CocoaPods по официальной инструкции. Если Homebrew уже есть:
   `brew install cocoapods`. Установку Homebrew согласовать отдельно.
6. Проверить:

```sh
flutter --version
xcodebuild -version
pod --version
python3 --version
flutter doctor -v
```

Android SDK для iOS не нужен. Ошибки секции Xcode исправить до сборки.
Если актуальный Xcode несовместим с закреплённым Flutter, сначала записать ошибку
и выбрать совместимую пару; не обновлять все пакеты вслепую.

## 4. Первый прогон — Simulator

Из корня снимка/репозитория:

```sh
bash scripts/ios_on_mac.sh check
cd mobile/korkem_flow
flutter pub get --enforce-lockfile
flutter analyze
dart format --output=none --set-exit-if-changed lib test
python3 tool/test_ios_scaffold.py
flutter test
cd ../..
bash scripts/ios_on_mac.sh simulator
```

Flutter сам создаёт ephemeral-пакеты, регистрирует плагины и выполняет
необходимую CocoaPods-интеграцию. Не открывать Xcode для сборки раньше этого шага.
Не копировать Generated.xcconfig, Pods и .dart_tool с Linux.

Затем:

```sh
open -a Simulator
cd mobile/korkem_flow
flutter devices
flutter run -d <SIMULATOR_ID> --dart-define=KORKEM_BASE_URL=https://api.korkem.asia --dart-define=KORKEM_FLAVOR=prod
```

Вместо <SIMULATOR_ID> подставить ID из flutter devices, без угловых скобок.
Войти своим существующим пользователем через интерфейс; пароль не писать
в командную строку, исходники или архив.

Если есть golden-различия macOS/Linux: сохранить failure images, проверить,
не является ли причиной шрифт/рендеринг. Не выполнять массовый --update-goldens.
Остановившийся скрипт не означает успешную сборку.

## 5. Запуск на своём iPhone

1. Подключить iPhone кабелем, разблокировать, подтвердить доверие к Mac.
2. Включить Developer Mode в настройках конфиденциальности и безопасности.
3. В Xcode → Settings → Accounts добавить свой Apple Account.
4. Открыть **workspace**, не только project:

```sh
open mobile/korkem_flow/ios/Runner.xcworkspace
```

5. Runner → Signing & Capabilities: выбрать свою Team и automatic signing.
   Проверить Bundle Identifier. Если занято, выбрать свой уникальный идентификатор,
   согласовать его до Firebase/TestFlight; не вводить чужую Team.
6. Выбрать подключённый iPhone. Первый запуск — из Xcode либо flutter run:

```sh
cd mobile/korkem_flow
flutter devices
flutter run -d <IPHONE_ID> --dart-define=KORKEM_BASE_URL=https://api.korkem.asia --dart-define=KORKEM_FLAVOR=prod
```

Для личного тестирования можно начать с бесплатной Personal Team, с ограничениями
Apple и необходимостью периодически переподписывать приложение. Для TestFlight
и App Store нужна подходящая платная Apple Developer membership.
Сертификаты и provisioning создаются на Mac. Не пересылать их в чат.

## 6. Приёмка на настоящем устройстве

- Вход по HTTPS, нормальная ошибка неверного пароля, выход.
- После принудительного закрытия вход сохраняется в Keychain.
- Языки ru/kk/en, клавиатура, Safe Area, крупный текст, тёмная тема.
- Списки заказов, уведомлений, склада; чат и поток ответа.
- Камера и галерея: разрешить, отказать, прикрепить снимок.
- Микрофон: разрешить, отказать; текст остаётся доступен при отказе.
- Очередь: отсутствие сети, закрытие/повторное открытие, однократная отправка
  после восстановления связи — **только на отдельном тестовом узле**.
- При отключённом AI кнопки действий работают — на тестовом узле.
- После logout пользователь другой компании не получает старые данные.

На живом Oracle не запускать bench run-tests и не создавать тестовые закупки,
отгрузки или складские проводки. Для мутаций нужен согласованный тестовый контур.
Проверка UI не является разрешением менять настоящие заказы.

## 7. IPA / TestFlight — после запуска на устройстве

Сначала unsigned-компиляция для диагностики:

```sh
bash scripts/ios_on_mac.sh unsigned
```

Это не устанавливаемый IPA. Затем с выбранной Team и подписанием:

```sh
bash scripts/ios_on_mac.sh archive
```

Архив и IPA появляются под mobile/korkem_flow/build/ios/.
Скрипт **не загружает** приложение в App Store Connect.
Загрузка — отдельное решение владельца после проверки Bundle ID, версии/build,
privacy declarations, privacy manifests SDK, иконок, скриншотов, прав на данные,
пользовательских аккаунтов и требований Apple к актуальному Xcode/SDK.
Не заполнять декларации «данные не собираются» предположением.
Не использовать Android APK-механизм обновления на iOS.

## 8. Поручение агенту на Mac — можно скопировать

> Прочитай docs/operations/IOS_ON_MAC_RU.md и основной контекст проекта.
> Это подготовка существующего KORKEM для iPhone. Сначала выясни: полный clone
> или client-only snapshot; сохрани текущие изменения. Используй korkem-flutter
> и verification-before-completion. Проверь Mac, Flutter 3.44.8, Xcode и CocoaPods.
> Выполни статические проверки, analyze и тесты, собери Simulator, затем помоги
> владельцу выбрать Team и запустить на его iPhone. Не переустанавливай проект
> через flutter create, не обновляй зависимости без причины. Не читай/переноси
> секреты из WSL, не меняй Oracle, не запускай backend-тесты, не публикуй приложение.
> Если нужна авторизация Apple или принятие лицензии — передай этот шаг владельцу.
> Запиши реальные результаты и ограничения, не называй Linux-проверки iOS-сборкой.

## 9. Проверка подготовки в WSL

Проверено 2026-09-10 на Flutter 3.44.8 / Dart 3.12.2:

| Команда | Фактический результат |
|---|---|
| flutter pub get | exit 0, lockfile без изменений |
| flutter analyze | No issues found, 13.5 s |
| dart format --output=none --set-exit-if-changed lib test | 391 файлов, 0 изменений |
| flutter test --reporter compact | 896 passed, exit 0, 4 min 27 s по reporter |
| python3 mobile/korkem_flow/tool/test_ios_scaffold.py | 7 OK |
| python3 scripts/test_ios_handoff.py | 6 OK |
| bash -n scripts/ios_on_mac.sh | exit 0 |
| bash scripts/ios_on_mac.sh check в Linux | ожидаемый отказ, exit 2, требует macOS |
| Проверка пробного ZIP | 544 файла: CRC и все SHA-256 совпали; overwrite отвергнут |
| git diff --check | exit 0 |

Лог Flutter в WSL: /tmp/korkem_ios_flutter_test.log. Обычный набор не запускает
tools-tagged генераторы и не выполняет integration_test против живого backend.
Статические тесты сначала выявили отсутствующие разрешения, Keychain,
локализации и слишком низкий deployment target в стандартном шаблоне,
затем прошли после настройки. Android/Windows, main.dart, pubspec.yaml и lockfile
этим поручением не изменены. Прежние изменения рабочего дерева сохранены.

Xcode и устройство здесь недоступны — это не отчёт о готовом iPhone-приложении.

## Официальные источники

- [Настройка iOS-разработки Flutter](https://docs.flutter.dev/platform-integration/ios/setup).
- [Архив Flutter SDK](https://docs.flutter.dev/install/archive).
- [Выпуск iOS-приложения](https://docs.flutter.dev/deployment/ios).
- [Установка CocoaPods](https://guides.cocoapods.org/using/getting-started.html).
- [Выбор Apple membership](https://developer.apple.com/support/compare-memberships/).

Инструкция разделяет локальное тестирование и распространение; требования
Apple к публикации повторно проверяются перед загрузкой, а не замораживаются здесь.
