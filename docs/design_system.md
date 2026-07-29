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

Never stack more than two elevation levels in one view.

Cards land at **elevation 0** in both themes, not the level 1 the table would suggest. Dark mode
separates them with a `1dp` outline instead of a shadow — a shadow is invisible against a dark
surface and only costs a raster pass — and light mode gets its separation from the container tone,
which at this density reads more cleanly than a shadow under every row of a long list.

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

Transient, non-critical feedback. Bottom, above the nav bar. One at a time; a new one replaces the
old. **Never** for errors requiring action — those are inline or a dialog.

Every destructive action that can be undone shows an `Undo`, in preference to a confirmation dialog:
a worker performs these dozens of times a shift and a modal in front of each is a tax, while a way
back afterwards costs nothing until it is needed.

An undo snackbar lasts exactly `AppDebounce.undo`, because that is also how long the request is
held. The two are one value on purpose — a button outliving the window it controls silently stops
working while still on screen. Where the backend offers no reversal (`CRM Task` has no reopen call),
deferring the write is what makes the undo real rather than a compensating write that cannot be
made.

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

Height 24, radius `sm`, `labelSmall`, container = semantic colour at `AppTint.surface`, text = the
AA-safe semantic colour. Icon + text always — never a bare colour swatch.

`AppTint` is the shared scale for laying an accent under content, and a chip, a swipe background and
an empty-state plate must all use it. They had drifted to four different opacities, which made the
strongest one look like it meant more.

### State illustration

Empty, error and success states are headed by a mark drawn from theme colours — a glyph on a lit
plate, three layers, in `StateIllustration`. **No illustration is shipped as an asset**, and there is
no `assets/images/` or `assets/lottie/`.

That is a trade, not an oversight. unDraw, Storyset and the rest are free and good, but each arrives
with its own palette, its own line weight and its own idea of a human figure, none of which are
KORKEM's. On a tool a factory opens forty times a day, art that does not match the product stops
reading as friendly within a week and starts reading as clip art. A composition built from tokens
inherits the theme instead: correct in light and dark, at any accent, with no asset, no licence and
nothing to download. The same reasoning rules out Lottie and Rive — nothing here needs a narrative
animation, and a runtime plus a binary would be weight without a job.

A `dense` variant exists for an empty state that shares a screen with content; at full size the mark
pushes its own headline below the fold.

### Empty states

Never a bare "No data". Illustration, headline, one sentence, and a way forward. A list filtered to
nothing and a list that is genuinely empty are different facts and get different offers: the first
leads with "clear filter", the second with "refresh". Refresh earns a button even though every list
also pulls to refresh — pull-to-refresh is discoverable only to someone who already suspects it is
there, and an empty screen is exactly when a user decides the app is broken.

## 9. Motion

| Token | Duration | Use |
|---|---|---|
| `instant` | 100ms | press feedback, state flip, ripple |
| `quick` | 200ms | chips, tooltips, a field's own controls |
| `standard` | 300ms | sheets, dialogs, row entrance |
| `page` | 350ms | route push and pop |
| `slow` | 500ms | the splash mark, an empty state arriving |
| `shimmer` | 1200ms | one sweep of a loading placeholder |
| `deliberate` | 600ms | how long the app may take before it owes an explanation |
| `stagger` | 20ms/row | capped at 6 rows |

Curves: `standard` (`easeInOutCubic`), `enter` (`easeOutCubic`), `exit` (`easeInCubic`), and
`emphasised` (`easeOutBack`) for anything that changes size or position under a finger — a slight
overshoot is what separates "the software responded" from "the thing I touched moved". Kept small; a
visible bounce on an ERP list is a toy, not a tool.

`AppDebounce` is deliberately **not** part of this table. A search debounce and an undo window are
waits on a person, not animations, and must never be shortened by reduced-motion.

Page transitions are **one fade-through on every platform**, chosen rather than inherited. Material's
default varies by host OS, so the same push looked different on a phone and on the Linux desktop
build while the shell was identical. Fade-through is right for a tabbed app where a push is a change
of subject.

Where a push is *not* a change of subject — opening a record from the list that names it — the title
flies across as a shared element (`HeroTitle`), growing from `titleMedium` to `headlineMedium`. Only
the title: a card morphing wholesale into a page animates a container the detail screen does not
have. Tags come from the route (`Routes.heroTag`) so both ends cannot be spelled differently, and
only the list that owns a record claims one — a card reused elsewhere must not, or it flies on
transitions nobody made.

Lists stagger entry by `stagger` per row, capped at 6 — beyond that it reads as lag rather than
polish.

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

The system lives in `lib/core/design/`: `tokens/` (`AppSpacing`, `AppRadius`, `AppColors`, `AppTint`,
`AppDuration`, `AppDebounce`, `AppStroke`, `AppIndicator`, `AppTypography`, …), `theme/` (the
`ThemeData` builders and the `StatusColors` extension), `motion/` and `widgets/`.

**No literal colour, radius, duration or spacing value may appear in a widget file.** This is what
keeps the system from eroding under delivery pressure — and for a long time it was enforced by
nothing at all. The claim that "the lint config enforces this" was never true: no lint rule can see
the difference between a design opacity and any other double, and the rule had already drifted to
four opacities for one idea, two hand-typed copies of one heading tracking, and three inline
durations.

`test/core/design/token_discipline_test.dart` enforces it now. It reads every widget file and fails
on an inline `Duration(...)` or `alpha: 0.x`, naming the file and line. Its scope is widget files
rather than all of `lib/`, and that is deliberate: `lib/core/api/` holds HTTP timeouts and a retry
backoff which are real durations, correctly named where they are, and none of them motion. Moving
those into the token files to satisfy a test would teach the next person that the token files are
where unrelated numbers go to become legal.
