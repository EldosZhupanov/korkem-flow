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

### The brand, as sampled

`logo/file-001.png` is the source of truth, and it is two colours. Both are read from the artwork,
not approximated:

| Role | Value | Share of the artwork |
|---|---|---|
| Field | `#2B382A` — deep forest | 97% |
| Ink | `#DEDAD0` — warm cream | the mark |

They measure **8.84:1** against each other — AAA for body text in either direction.

Everything under `assets/brand/` is cut from that file by
`mobile/korkem_flow/tool/extract_brand_assets.py`, which is committed so the assets are reproducible
rather than a one-off nobody can repeat. Re-run it after any change to the artwork, then regenerate
the launcher icon, the splash and the goldens.

That is a *surface* relationship rather than an accent, and the whole theme falls out of it: **dark
mode is the logo; light mode is the logo inverted.** Forest is the ink on cream paper, cream is the
ink on a forest field, and neither theme has to invent a colour the brand does not own.

> An earlier version of this page described the brand as neon `#39FF14` and spent a table on the
> ways it could not be used. That colour was never KORKEM's — it predated anyone seeing the logo.

### Scheme

| Role | Light | Dark |
|---|---|---|
| `primary` | `#2B382A` forest | `#DEDAD0` cream |
| `onPrimary` | `#DEDAD0` | `#2B382A` |
| `surface` | `#F7F5EE` | `#1B241A` |
| `surfaceContainer` | `#EDEAE0` | `#2B382A` (the brand green *is* the card) |
| `onSurface` | `#1E2A1E` (13.70:1) | `#E6E3D9` (12.45:1) |

Surfaces are pinned, not blended. FlexColorScheme's surface modes tint every surface toward the
primary, and with a primary this dark that turns the cream grey-green.

### Outlines — two roles, two rules

| Token | Light | Dark | Duty |
|---|---|---|---|
| `outline` | `#DAD7CA` | `#3D4A3B` | divides surfaces; carries no meaning, so no ratio applies |
| `outlineStrong` | `#7F8479` (3.51:1) | `#7D8277` (3.13:1) | bounds an interactive component |

The split is not pedantry. A filled input sits **1.10:1** above the page — invisible to a good many
people and gone entirely under glare — so the *line* is what says "you can type here", and WCAG
1.4.11 asks 3:1 of anything that identifies a component. Cards have the same problem and solve it
with depth instead (§6).

### Semantic colours

Status must survive greyscale. Each pairs with an icon and a label, and each is measured against the
**container** it is read on, which is the harder of the two surfaces.

| Meaning | Light | Dark | Icon |
|---|---|---|---|
| Success / Completed | `#1B6B10` (5.53:1) | `#7FD36B` (6.72:1) | `check_circle` |
| Warning / Pending | `#8A5A00` (4.92:1) | `#FFC14D` (7.63:1) | `schedule` |
| Danger / Overdue | `#B3261E` (5.43:1) | `#FF897D` (5.36:1) | `error` |
| Info / Draft | `#1F5F8B` (5.69:1) | `#7FC4F5` (6.53:1) | `info` |
| Neutral / Archived | `#5C5F5A` (5.39:1) | `#A8ADA4` (5.39:1) | `inventory_2` |

Success is deliberately brighter and more saturated than the primary. On a green-branded interface a
success green that resembles the brand reads as chrome rather than as a state.

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
| `headlineMedium` | 28 / 36 | 600 | Detail screen titles |
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

## 6. Elevation and depth

Two shadows per level, never one. A single blurred drop reads as a sticker; a tight contact shadow
that anchors the edge plus a wide ambient one that lifts the shape is what the eye accepts as an
object on a surface.

| Token | Contact | Ambient | Use |
|---|---|---|---|
| `AppElevation.resting` | y1 blur2 @6% | y4 blur12 @5% | a card, a tile, at rest |
| `AppElevation.pressed` | y1 blur1 @5% | y1 blur4 @3% | under a finger |
| `AppElevation.overlay` | y2 blur4 @8% | y12 blur28 @8% | dialogs, sheets, menus |

**Light mode only, and not for decoration.** A card sits 1.10:1 above the cream page — the same
near-invisibility that forced a real border onto the input fields (§2). The shadow is what makes a
card legible *as a card*. Dark mode gets none: against a forest field a shadow is invisible and
costs a raster pass to prove it, so the `1dp` outline does that job there.

Shadows are the brand dark, never black — black on warm cream goes muddy. They are the one place in
the system written as raw hex, because `const` cannot build a colour from `AppColors.forest` plus an
alpha; `app_elevation_test.dart` asserts each one is the brand colour rather than this page claiming
it.

Never stack more than two levels in one view.

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

Only for **destructive or blocking** decisions — everything reversible gets a snackbar with an undo,
and everything merely optional gets a bottom sheet. A dialog blocks, steals focus and must be
dismissed before anything else can happen; that is worth it only when proceeding destroys something.

`showConfirmDialog` fixes the shape so the rules are structural rather than advisory: title ≤ 5
words, body ≤ 2 lines, two actions maximum, cancel left of confirm, and a destructive confirm
coloured `error` so it does not look like a routine one.

It returns a plain `bool`. `showDialog` hands back `null` on a barrier dismissal, and a nullable
answer to "shall I destroy this?" invites `result ?? true` and `result != false` — two ways to read
*tapped outside the dialog* as consent.

### Bottom sheets

The default surface for anything richer than a confirmation — filters, pickers, detail previews,
forms. Drag handle always present. Radius `lg` top corners only. `DraggableScrollableSheet` for
content that may exceed half the screen.

Sheets are dismissible by drag **and** by a visible close affordance. A drag handle is an affordance
only for someone who already knows sheets drag, and the back gesture is the same bet; someone who
opened a sheet by accident needs something to aim at. The filter sheet shipped without one for
months, which is the argument for a component rather than a rule.

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

The app's navigation is a **panel**: a drawer on a phone, a permanent 280dp
column at `AppBreakpoints.medium` and up.

> This page previously said, in bold: **"No drawer.** A drawer hides navigation
> behind a gesture and is poor one-handed. Overflow goes to a Profile/More tab."
> That was right for an app whose four destinations *were* the product. It is
> wrong for one whose product is a conversation and whose sections are tools it
> reaches — a permanent bar would spend a fifth of a phone screen advertising
> places people visit occasionally, and the assistant needs that space.

The breakpoint is derived, not chosen: 280 (panel) + 720 (`readable`) = 1000, so
`medium` is the first width at which a permanent panel does not squeeze the
reading column.

Two lists, deliberately kept apart:

| List | What it is | Cost |
|---|---|---|
| `appDestinations` | the router's **branches** — places that keep their own stack and scroll position | one `IndexedStack` child alive for the life of the app |
| `sidebarEntries` | what the panel shows, a superset | nothing; non-branch rows navigate by path |

Production is a dashboard child and Settings sits outside the shell; both are
reached with `context.go`, which sets the owning branch *and* its stack in one
move. Conflating the lists would either force those to become branches or force
the branch list to grow rows the router has no route for.

- **Tabs** only for peer views of one subject — Deals and Leads are both the
  pipeline — never for unrelated destinations, which belong in the panel. Always
  **scrollable and start-aligned**, including where two tabs would fit centred:
  deciding per screen is how one tab bar ends up centred and another does not.
- **App bar**: `small` everywhere, title left, max two actions plus overflow.
  A branch root gets a menu button; a pushed screen keeps its back arrow, and a
  wide layout gets neither because the panel is already visible.

  The small bar contradicts what this page said for a long time — `large` on
  top-level, collapsing on scroll — and the app never had one. Keeping it is the
  decision: a large title spends around 52dp of permanent vertical space, and
  every screen here exists to show as many rows as possible to someone holding a
  phone on a factory floor.

### The assistant

`KORKEM AI` is the home screen, and the one rule that governs it is that it
never claims more than it has. Until a language model is connected:

- It matches a few keywords and attaches a **data card**. It writes no prose and
  no figures — every number on a card comes from the provider that already feeds
  the dashboard, so a conversation reopened next week shows next week's data.
- Anything it does not recognise gets a plain statement that no model is
  connected, followed by what it *can* show.
- The header carries `chatLocalMode` at all times.

A demo assistant that improvises is not a demo, it is a claim; and the first
time somebody acts on an invented number out of an ERP, the damage is real.

`AssistantRepository` is the seam a real model plugs into — one method, and the
chat screen does not change when it is implemented.

### Screen shells

Two, and between them they cover everything with chrome:

| Shell | For | Owns |
|---|---|---|
| `AppScreen` | lists, hubs, settings | bar, title, actions, optional tabs |
| `DetailScaffold` | one record | the same bar, plus loading / error / empty |

A bare `Scaffold` is correct only for a screen with no bar at all — Splash and Login. Everywhere
else, going direct is how nine screens each ended up with their own idea of the chrome.

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

Empty, error and success states are headed by three layers in `StateIllustration`: a soft halo that
reads as light rather than as a ring, **the woven ornament from KORKEM's own Ö** laid in as texture,
and the state's glyph on top, solid, because it is the thing carrying the meaning.

The ornament is the one piece of artwork the company owns, already in the repository as an alpha mask
cut from `logo/file-001.png`. Nothing had to be drawn, licensed or downloaded.

It is tinted from `onSurface`, not from the glyph's accent — the ornament carries the brand and the
glyph carries the meaning, which are different jobs — and it takes a different alpha per theme,
because light ink on a dark ground is perceptually weaker than dark ink on a light ground at the same
value.

Stock sets were considered twice. unDraw, Storyset and the rest are free and good, and they are a
worse fit here than before the real brand turned up, not better: flat pastel figures beside a serif
heritage identity read as borrowed, and recolouring does not touch the drawing style underneath. The
same reasoning rules out Lottie and Rive — nothing here needs a narrative animation, and a runtime
plus a binary would be weight without a job.

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
| `count` | 420ms | a figure rolling to its value |
| `slow` | 500ms | the splash mark, an empty state arriving |
| `deliberate` | 600ms | how long the app may take before it owes an explanation |
| `shimmer` | 1200ms | one sweep of a loading placeholder |
| `pulse` | 1400ms | one breath of a busy indicator |
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

### Interaction

Every response answers the same question — *what did my finger just do?* — and the answers must
agree with physics or they read as decoration.

| Interaction | Response |
|---|---|
| Press a card or tile | Scale to 0.97 **and** the shadow shallows: the object sinks toward the page |
| Press a small control | Scale to 0.92 — the same ratio is imperceptible at that size |
| Focus a field | Border doubles to `AppStroke.focus` in the primary colour |
| Swipe a row | The action panel grows with the drag, from nothing, never appearing whole |
| Row arrives | Fade and rise `AppMotionScale.enterOffsetY`, staggered, first six rows only |
| Open a record | The title flies (§9), everything else fades through |
| Waiting, in place | Skeleton that mirrors the real layout |
| Waiting, in a control | `AppBusyIndicator` — three dots, staggered, dimming to 30% and never to zero |

A card that grows a *deeper* shadow when pressed is moving the wrong way. It looks fine in a paused
frame and wrong in the hand, which is why the rule is written down rather than left to taste.

**No spinning circles.** A rotation says "something is turning over there"; a control that pulses
says "this is working". `CircularProgressIndicator` appears nowhere in `lib/`.

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

### Looking at it

`DesignGallery` — Settings → Debug → Design system, in a debug build — shows every component on one
screen in three tabs, and six goldens cover it in both themes. It is the cheapest coverage in the
suite: a change to a shared token fails there with everything it affects visible in the same diff,
rather than surfacing in whichever feature screen happened to be goldened and looking like a bug in
that feature.

It is also the answer to how the drift below happened. Four opacities for one idea and two tab bars
behaving differently are obvious side by side and invisible one file at a time.

### Keeping it

`test/core/design/token_discipline_test.dart` enforces it now. It reads every widget file and fails
on an inline `Duration(...)` or `alpha: 0.x`, naming the file and line. Its scope is widget files
rather than all of `lib/`, and that is deliberate: `lib/core/api/` holds HTTP timeouts and a retry
backoff which are real durations, correctly named where they are, and none of them motion. Moving
those into the token files to satisfy a test would teach the next person that the token files are
where unrelated numbers go to become legal.
