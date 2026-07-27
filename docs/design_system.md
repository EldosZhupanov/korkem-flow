# KORKEM Flow Mobile — Design System

> Material 3 as the foundation, tuned toward the restraint of Linear, Stripe and Notion, and the
> one-handed ergonomics of WhatsApp and Uber Driver. Native on both platforms — never a web view in a
> phone frame.
>
> All contrast ratios below are **computed**, not estimated. WCAG 2.1 AA is the floor (4.5:1 body,
> 3:1 large text and UI boundaries).

## 1. Design principles

1. **The list is the product.** An ERP on a phone is mostly scannable lists. Density, hierarchy and
   touch targets matter more than decoration.
2. **One primary action per screen.** If everything is emphasised, nothing is.
3. **Status is colour + shape + text.** Never colour alone — 8% of male users cannot rely on it.
4. **Built for a gloved hand in a workshop.** Larger targets and higher contrast than a consumer app.
5. **Never an ERPNext form.** Long forms become short, sequential, single-purpose steps.

## 2. Colour

### The brand constraint — measured

KORKEM's brand accent is neon green `#39FF14`. Measured against WCAG:

| Usage | Ratio | Verdict |
|---|---|---|
| `#39FF14` as **text on white** | **1.36:1** | ❌ Fails badly (needs 4.5:1) |
| **White text on** `#39FF14` | **1.36:1** | ❌ Unusable as a filled button with white label |
| **Black text on** `#39FF14` | **15.49:1** | ✅ Excellent |
| `#39FF14` on dark `#121212` | **13.82:1** | ✅ Excellent |

**Rules this dictates — not stylistic preference, but accessibility:**

- In **dark theme**, `#39FF14` is the hero accent. This is where the brand belongs.
- In **light theme**, `#39FF14` may be used **only as a fill carrying black text/icons**. It must
  never be a text or icon colour on white.
- For green text/icons in light theme use `#177A08` (**5.49:1** ✅). Note `#1F8A0A` measures 4.47:1 —
  it *looks* fine and fails by a hair. Do not use it.

### Seed and scheme

`FlexColorScheme` generates both schemes from seeds; the brand green is applied as a **tuned accent**,
not the raw seed, because M3 tonal generation from a near-fluorescent seed produces muddy containers.

| Role | Light | Dark |
|---|---|---|
| `primary` | `#177A08` | `#39FF14` |
| `onPrimary` | `#FFFFFF` | `#0A0A0A` |
| `primaryContainer` | `#C8F5BE` | `#1F4D14` |
| `surface` | `#FCFDFB` | `#121212` |
| `surfaceContainer` | `#F1F4EF` | `#1E1E1E` |
| `outlineVariant` | `#C7CCC3` | `#3A3F38` |

### Semantic colours

Status must survive greyscale. Each pairs with an icon and a label.

| Meaning | Light | Dark | Icon |
|---|---|---|---|
| Success / Completed | `#177A08` | `#5BFF3F` | `check_circle` |
| Warning / Pending | `#8A5A00` | `#FFC14D` | `schedule` |
| Danger / Overdue | `#B3261E` | `#FF897D` | `error` |
| Info / Draft | `#1F5F8B` | `#7FC4F5` | `info` |
| Neutral / Archived | `#5C5F5A` | `#A8ADA4` | `inventory_2` |

### Production-status palette

Mapped to the real lifecycle (`PROJECT.md`), so a worker reads state at a glance:

| Stage | Token |
|---|---|
| Lead → Approval | Info |
| Material → Purchasing | Warning |
| Cutting → Assembly | Primary |
| Packaging → Delivery | Success |
| Warranty / Archive | Neutral |

## 3. Typography

**Inter, bundled** (`assets/fonts/Inter-Variable.ttf`, OFL-1.1) — never fetched at runtime.

Chosen on measured evidence, not taste. The `cmap` table of the bundled file was parsed: 2 849
codepoints, covering all 18 Kazakh letters (Әә Ғғ Ққ Ңң Өө Ұұ Үү Һһ Іі), full Russian including Ёё,
Latin, digits and **₸** (U+20B8).

Two candidates fail this outright and must never be used here: **Manrope** is missing 10 of those
Kazakh letters, **Onest** is missing 14 — both would render tofu for Kazakh users. **SF Pro** is
licensed for Apple platforms only and **Google Sans** is proprietary; neither can ship in an
Android build.

Inter also carries true tabular figures, which is why quantity and currency columns stay aligned.

| Token | Size / Line | Weight | Use |
|---|---|---|---|
| `displaySmall` | 36 / 44 | 600 | Dashboard hero metric |
| `headlineMedium` | 28 / 36 | 600 | Screen titles (large app bar) |
| `titleLarge` | 22 / 28 | 600 | Section headers |
| `titleMedium` | 16 / 24 | 600 | List item title |
| `bodyLarge` | 16 / 24 | 400 | Primary body |
| `bodyMedium` | 14 / 20 | 400 | Secondary body |
| `labelLarge` | 14 / 20 | 600 | Buttons |
| `labelSmall` | 11 / 16 | 500 | Chips, captions, timestamps |

Rules: never below **11sp**. Never more than **three** sizes per screen. Numeric columns use
`fontFeatures: [FontFeature.tabularFigures()]` so digits align in lists — without this, quantity
columns visibly jitter.

Text scales with the OS setting, clamped to **1.0–1.6×** so layouts survive accessibility settings.

## 4. Spacing

4pt base scale. Only these values:

| Token | Value | Use |
|---|---|---|
| `xxs` | 2 | icon/label nudge |
| `xs` | 4 | within a chip |
| `sm` | 8 | icon↔text |
| `md` | 12 | inside a list row |
| `lg` | 16 | **screen horizontal margin** |
| `xl` | 24 | between sections |
| `xxl` | 32 | above a primary action |
| `xxxl` | 48 | empty-state padding |

Screen margin is `lg` (16) on compact, `xl` (24) on medium+. Vertical rhythm between cards is `md`.

## 5. Corner radius

| Token | Value | Applies to |
|---|---|---|
| `xs` | 4 | badges |
| `sm` | 8 | chips, text fields, small buttons |
| `md` | 12 | **cards, list tiles** |
| `lg` | 16 | bottom sheets, dialogs |
| `xl` | 28 | FAB, pill buttons |
| `full` | 999 | avatars |

`md` (12) is the default. Consistent radius is a large part of why Linear and Stripe feel calm.

## 6. Elevation and shadows

Material 3 prefers **tonal** elevation. Dark theme uses tone only — shadows are invisible on dark
surfaces and only add cost.

| Level | Light | Dark | Use |
|---|---|---|---|
| 0 | none | `surface` | page background |
| 1 | tint + y1 blur2 @4% | `surfaceContainerLow` | cards at rest |
| 2 | tint + y2 blur4 @6% | `surfaceContainer` | app bar on scroll |
| 3 | tint + y4 blur8 @8% | `surfaceContainerHigh` | FAB, menus |
| 4 | tint + y8 blur16 @10% | `surfaceContainerHighest` | dialogs, sheets |

Never stack more than two elevation levels in one view. Cards **do not** get drop shadows in dark mode.

## 7. Icons

**Material Symbols Rounded**, via `material_symbols_icons` (Apache-2.0) — the only icon set in the
app. Chosen over Lucide (MIT) and Phosphor (MIT) because it is Material 3's native set, is actively
maintained (Phosphor's Flutter package has had no release since May 2024), and its variable `fill`
axis gives selected/unselected from one family so the transition can animate. Rounded matches the
12dp radius language.

Icons are referenced through the semantic vocabulary in `lib/core/design/tokens/icons.dart`
(`AppIcons.deal`, `AppIcons.workOrder`), never by glyph name — so changing one is a single edit. Sizes: 20 (inline), 24 (default), 32 (empty states),
48 (illustrations). Every icon-only control carries a `Semantics` label.

## 8. Components

### Buttons

| Variant | M3 widget | Use | Rule |
|---|---|---|---|
| Primary | `FilledButton` | the one main action | **max one per screen** |
| Secondary | `FilledButton.tonal` | alternative action | |
| Tertiary | `OutlinedButton` | low-emphasis | |
| Text | `TextButton` | dialogs, inline | |
| Destructive | `FilledButton` + error colour | delete/reject | always confirms first |

Min height **48dp** (56dp for shop-floor primary actions — gloves). Full-width in sheets and forms;
intrinsic width inline. Loading state replaces the label with a 16dp spinner and **keeps the button
width fixed** — a resizing button shifts everything under it.

### Cards

Default: `surfaceContainerLow`, radius `md`, padding `lg`, elevation 1. No border in light mode; a
`1dp outlineVariant` border in dark mode instead of a shadow.

Card layout for an entity (Deal, Work Order, Task):

```
┌────────────────────────────────────┐
│ ●  Title                    [chip] │   status dot + title + status chip
│    Secondary line                  │   customer / item
│    ─────────────────────────────   │
│    meta · meta            action → │   date, qty, assignee
└────────────────────────────────────┘
```

Whole card is tappable; inline actions get their own hit areas with `≥8dp` separation to prevent
mis-taps.

### Dialogs

Only for **destructive or blocking** decisions. Title ≤ 5 words, body ≤ 2 lines, two actions maximum,
confirm on the right. Everything else is a bottom sheet.

### Bottom sheets

The default surface for anything richer than a confirmation — filters, pickers, detail previews,
forms. Drag handle always present. Radius `lg` top corners only. `DraggableScrollableSheet` for
content that may exceed half the screen. Sheets are dismissible by drag **and** a visible close
affordance (drag alone is undiscoverable).

### Snackbars

Transient, non-critical feedback. Bottom, above the nav bar, 4s (10s with an action). One at a time;
a new one replaces the old. **Never** for errors requiring action — those are inline or a dialog.
Every destructive action that can be undone shows an `Undo` action; this is preferable to a
confirmation dialog for reversible operations.

### Navigation

- **`NavigationBar`** (M3) — 3–5 destinations, per role (see `mobile_app_structure.md`).
- **No drawer.** A drawer hides navigation behind a gesture and is poor one-handed. Overflow goes to a
  Profile/More tab.
- **Tabs** only for peer views of one entity (e.g. Work Order: Overview / Materials / Tasks).
- **App bar**: `large` on top-level (collapses on scroll), `small` on detail. Title left, max two
  actions plus overflow.

### FAB rules

- At most **one** FAB per screen; only on screens whose primary action is *creation*.
- Extended FAB (with label) on primary list screens; regular FAB on secondary.
- Hides on scroll-down, returns on scroll-up.
- **Never** a FAB on a detail screen — the primary action there belongs in a bottom action bar where
  it can be labelled unambiguously.

### Status chip

Height 24, radius `sm`, `labelSmall`, container = semantic colour at 12% opacity, text = the AA-safe
semantic colour. Icon + text always — never a bare colour swatch.

## 9. Motion

| Token | Duration | Curve | Use |
|---|---|---|---|
| `instant` | 100ms | `easeOut` | state flip, ripple |
| `quick` | 200ms | `easeOutCubic` | chips, tooltips |
| `standard` | 300ms | `easeInOutCubic` | sheets, dialogs, page transitions |
| `slow` | 500ms | `easeInOutCubic` | hero, celebratory |

Page transitions are platform-native: Cupertino slide on iOS, fade-through on Android. Lists stagger
entry by 20ms per row, capped at 6 rows — beyond that it reads as lag rather than polish.

**All motion respects `MediaQuery.disableAnimations`**; when set, durations collapse to zero. An
animation that cannot be disabled is an accessibility defect, not a feature.

## 10. Light and dark mode

Both are first-class, following the system by default with a manual override in Settings. Dark is not
an inverted light theme: surfaces are tonal (`#121212` → `#1E1E1E` → `#242424`), pure black is avoided
(smearing on OLED scroll), pure white text is avoided (`#E6E6E6` at 87% reduces halation).

Every component is golden-tested in **both** themes.

## 11. Accessibility

Non-negotiable, and cheaper to build in than retrofit:

- Contrast **4.5:1** body, **3:1** large text and UI boundaries — the measured basis of §2.
- Touch targets **≥48×48dp**, spacing ≥8dp.
- Every interactive element has a semantic label; icon-only buttons always.
- Status conveyed by **icon + text + colour**, never colour alone.
- Text scaling to 1.6× without clipping or overlap.
- Focus order follows visual order; all actions reachable by screen reader.
- `MediaQuery.disableAnimations` honoured globally.
- Forms: labels outside the field (not placeholder-only), errors announced, never colour-only.

## 12. Implementation

The system lives in `core/theme/` as tokens (`AppSpacing`, `AppRadius`, `AppDuration`, `AppColors`)
plus `ThemeData` builders. **No literal colour, radius, duration or spacing value may appear in a
widget file** — the lint config enforces this, and it is what keeps the system from eroding under
delivery pressure.
