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

## Illustrations and animations

None bundled yet.

Lottie assets are deliberately kept to a minimum. LottieFiles content carries per-asset licenses —
many require attribution and some forbid commercial use — so each file must be license-checked
individually and recorded here before being added. At most three are planned (success, offline,
empty inbox); every other empty and error state uses a muted Material Symbol, matching the
restraint of Linear, Stripe and Notion.
