# Third-party assets and licenses

Every third-party asset bundled into this application, with its source, license and purpose.
Add a row here **before** committing any new asset.

## Fonts

### Inter

| | |
|---|---|
| **File** | `assets/fonts/Inter-Variable.ttf` |
| **Version** | Variable font (`opsz`, `wght` axes), from `google/fonts` @ `main` |
| **Source** | https://github.com/google/fonts/tree/main/ofl/inter (upstream: https://github.com/rsms/inter) |
| **License** | SIL Open Font License 1.1 — full text in `assets/fonts/Inter-OFL.txt` |
| **Copyright** | Copyright 2020 The Inter Project Authors |
| **Purpose** | The application's only typeface, for every text style |

**Why Inter, verified rather than assumed.** The `cmap` table of this exact file was parsed
(2 849 codepoints, format 12) and confirmed to contain:

- all 18 Kazakh-specific letters — Әә Ғғ Ққ Ңң Өө Ұұ Үү Һһ Іі
- full Russian including Ёё
- Latin and digits
- **₸** (U+20B8, Kazakhstani tenge)

This mattered: two fonts originally under consideration fail here. **Manrope** is missing 10 of
those Kazakh letters and **Onest** is missing 14 — either would render tofu boxes for Kazakh users.
`SF Pro` (Apple-platform license only) and `Google Sans` (proprietary) cannot be redistributed in
an Android build at all.

Inter also ships true tabular figures, which keeps quantity and currency columns from jittering as
lists scroll — the single most visible typographic defect in an ERP UI.

**OFL compliance note:** the font is bundled unmodified and is not sold on its own. The OFL
reserved-font-name clause is respected — the file is not renamed to a new typeface name, only the
filename is normalised from `Inter[opsz,wght].ttf` (the bracketed upstream name confuses some build
tools).

## Icons

### Material Symbols (Rounded)

| | |
|---|---|
| **Package** | `material_symbols_icons` (pub.dev) |
| **License** | Apache License 2.0 |
| **Source** | https://github.com/timmaffett/material_symbols_icons (upstream: Google Material Symbols) |
| **Purpose** | The application's only icon set |

Chosen over Lucide (MIT) and Phosphor (MIT) because it is Material 3's native icon system, is
actively maintained (`phosphor_flutter` has had no release since May 2024), and its variable `fill`
axis provides filled-when-selected / outlined-when-inactive from a single family. Delivered as a
Dart package, so no icon files are vendored into `assets/`.

**One icon set only.** Mixing icon families is the most visible way an interface reads as assembled
rather than designed.

## Plugins

### firebase_core, firebase_messaging

| | |
|---|---|
| **Packages** | `firebase_core` (4.14.0), `firebase_messaging` (16.6.0), pub.dev |
| **License** | BSD-3-Clause — `Copyright 2017 The Chromium Authors` |
| **Source** | https://github.com/firebase/flutterfire |
| **Purpose** | Уведомление на телефон о том, что на узле что-то произошло |

Взяты ради одного: разбудить приложение. Содержания в уведомлении нет и быть не
должно — push идёт через серверы Google, а завод нам доверил обратное. Что
именно уходит наружу и почему так мало, написано в
`backend/korkem_ai/korkem_ai/korkem_ai/integrations/push.py`, и это закреплено
двумя проверками, которые ловят любую попытку добавить туда текст.

Проект Firebase принадлежит владельцу узла — как ключ ИИ и токен Telegram.
`android/app/google-services.json` не секрет: это открытые идентификаторы
проекта, они и так уезжают внутри APK. Настоящий секрет — ключ сервисного
аккаунта — живёт в настройках узла зашифрованным и в репозиторий не попадает.

### image_picker

| | |
|---|---|
| **Package** | `image_picker` (pub.dev), resolved 1.2.3 |
| **License** | BSD-3-Clause — `Copyright 2013 The Flutter Authors` |
| **Source** | https://github.com/flutter/packages/tree/main/packages/image_picker |
| **Purpose** | Photographs taken at a measurement: the wall, the socket, the pipe in the corner |

Maintained by the Flutter team itself, which is the reason it was chosen over the
community pickers: this plugin runs inside a release build behind R8, and a plugin
whose native side stops being maintained is a build that stops working on the next
Android release. It carries its own consumer ProGuard rules, so no entry in
`android/app/proguard-rules.pro` is needed for it.

On Android 13 and later it goes through the system photo picker, which grants access
to the one picture the person chose rather than to the whole gallery — the app never
asks for `READ_EXTERNAL_STORAGE`. Camera permission is requested at the moment the
person taps, not when the screen opens.

### file_picker

| | |
|---|---|
| **Package** | `file_picker` (pub.dev), resolved 12.2.0 |
| **License** | MIT — `Copyright (c) 2018 Miguel Ruivo` |
| **Source** | https://github.com/miguelpruivo/flutter_file_picker |
| **Purpose** | Choosing the XML the technologist exported from БАЗИС |

Chosen because the file is picked from wherever the technologist saved it — a
download folder, a flash drive, a messenger's folder — and the system picker is
the only thing that reaches all of them. It carries no ProGuard rules of its own
(checked, not assumed), and it does not need any: the release build under R8
succeeds with it — three ABIs, 22.0 / 24.1 / 25.6 MB, built 2026-09-03.

A caution earned the same day: a release build that follows an interrupted one
can fail with a compilation error that has nothing to do with the code. It
happened here and was briefly mistaken for a regression. A clean run is the only
run worth believing.

## Illustrations and animations

None bundled yet.

Lottie assets are deliberately kept to a minimum. LottieFiles content carries per-asset licenses —
many require attribution and some forbid commercial use — so each file must be license-checked
individually and recorded here before being added. At most three are planned (success, offline,
empty inbox); every other empty and error state uses a muted Material Symbol, matching the
restraint of Linear, Stripe and Notion.
