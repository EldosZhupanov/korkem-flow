---
name: korkem-design-review
description: Score a KORKEM Flow screen from 0 to 10 on ten points from screenshots — light, dark, a phone in Kazakh — show the owner, then fix everything below 10 within the design system. Load when asked to «проверь дизайн», «оцени экран», review a screen's UI/UX, or before shipping a new screen.
---

# Design review — «оцени экран от 0 до 10 и исправь всё, что ниже 10»

The owner's request of 2026-11-25, after looking at gstack and UI/UX Pro Max
(both rejected — `README.md`). The idea taken from them is the score: every
point gets a number, a number below 10 says what a 10 would look like, and
the fix is made against **this** design system, not a generic one.

Load `korkem-flutter` first. Its rules are the judge here: tokens only, no
literal colour, spacing, radius or duration in a widget file, `StatusColors`
for status, `AppIcons` for icons, Inter (it covers Kazakh — never "replace
it with the system font"), every string through `AppLocalizations`.

## 1. Take the shots

Screens render to PNG through the golden mechanism, with fake data, in three
looks: `wide_light` and `wide_dark` (1400×900, Russian) and `phone_kk`
(390×844, Kazakh). The list is in
`mobile/korkem_flow/test/design/design_shots_test.dart`, `_screens` — a
screen not there is added first, with data that looks like a real shop's
(long names, a debt, a part-paid invoice), because an empty screen hides
every problem. A dialog is shot by naming the keys to tap.

```sh
cd mobile/korkem_flow
flutter test test/design --tags tools --run-skipped --update-goldens
```

The PNGs land in `test/design/shots/` (git-ignored). The cloud container has
no Flutter: run it in the laptop's queue (a step script, as in `korkem-bench`),
stage the PNGs back with `device_stage_files`, and **look at each one** with
Read before scoring. Never score from the code alone.

## 2. Score — ten points, 0 to 10

| # | point | a 10 looks like |
|---|---|---|
| 1 | **Main thing first** | what the screen is for is the biggest, highest thing; a manager finds it in a second |
| 2 | **Nothing extra** | every element earns its place; no repeated figure, no decoration |
| 3 | **Hierarchy** | one weight of emphasis per level; secondary text smaller and `onSurfaceVariant` |
| 4 | **Colour** | only theme colours and `statusColors`; red only for money owed / late / errors; both themes readable |
| 5 | **Spacing and alignment** | `AppSpacing` steps only, edges line up, groups breathe |
| 6 | **Contrast** | muted text still readable on light and on dark (aim at WCAG AA, 4.5:1) |
| 7 | **Touch** | on the phone every button and chip at least 48 px; nothing pressed by mistake |
| 8 | **Phone** | nothing overflows or is cut; the yellow-black overflow stripe is a 0 |
| 9 | **Kazakh** | every word translated; long Kazakh words wrap, not clip; no Russian left in `kk` |
| 10 | **States** | empty, loading and error look meant: `EmptyView`, `ErrorView`, a spinner — not a blank |

Write each point as `N/10 — what is wrong — what a 10 is`, on the shot it
was seen in. A point at 10 gets one line saying why.

## 3. Show the owner, then fix

The owner reads Russian, simply, and decides from a picture. Send the shots
(`SendUserFile`) and the scores as one short list; mark what will change.
Wait for «делай».

Then fix every point below 10:

- In the design system first: a missing token or shared widget goes into
  `lib/core/design/`, not into the screen.
- No new colour, font or icon set. If a fix seems to need one, it is a design
  system decision — say so instead.
- Keys and behaviour stay; a widget test that breaks means the fix changed
  behaviour, not only looks.

Re-shoot, re-score, and show **before and after** side by side. Done is every
point at 10, or a point below 10 with the reason it stays (said, not hidden).

## Limits

- Fake data shows layout, not speed: a screen that loads slowly scores 10
  here and is still slow (measure it on the bench).
- 1400×900 and 390×844 are two sizes, not all of them; a tablet or a
  maximised 1920 window is a separate look, added to `_looks` when it matters.
