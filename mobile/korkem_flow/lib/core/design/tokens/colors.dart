import 'package:flutter/widgets.dart';

/// Raw colour values, taken from the official KORKEM logo.
///
/// Widgets must not read these directly — they read `Theme.of(context)` and,
/// for status colours, the `StatusColors` theme extension. These constants
/// exist to build those themes in one place.
///
/// ## Where these come from
///
/// `logo/file-001.png` is the brand, and it is two colours: a deep forest
/// green field that occupies 97% of the artwork, and a warm cream the mark is
/// drawn in. Both are sampled exactly, not approximated, and they measure
/// **8.84:1** against each other — AAA for body text in either direction.
///
/// That pairing is a *surface* relationship rather than an accent, which is
/// what makes the theme fall out of it so cleanly: dark mode is the logo, and
/// light mode is the logo inverted. Forest is the ink on cream paper; cream is
/// the ink on a forest field. Neither theme has to invent a colour the brand
/// does not own.
///
/// Every ratio quoted below was computed against WCAG 2.1, not estimated.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────

  /// The field the logo sits on. Sampled from the artwork.
  static const forest = Color(0xFF2B382A);

  /// The colour the mark is drawn in. Sampled from the artwork.
  static const cream = Color(0xFFDEDAD0);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  // Light is cream paper; dark is a forest field one step below the brand
  // green, so cards *are* the brand colour and lift off the page.

  static const surfaceLight = Color(0xFFF7F5EE);
  static const surfaceContainerLight = Color(0xFFEDEAE0);

  static const surfaceDark = Color(0xFF1B241A);
  static const Color surfaceContainerDark = forest;

  /// Body text. Measured **13.70:1** on [surfaceLight] and **12.45:1** on
  /// [surfaceDark] — comfortably AAA, which matters on a screen read at arm's
  /// length in a workshop rather than held close on a sofa.
  static const onSurfaceLight = Color(0xFF1E2A1E);
  static const onSurfaceDark = Color(0xFFE6E3D9);

  // ── Outlines ─────────────────────────────────────────────────────────────
  // Two roles, because they answer to different rules.

  /// Divides one surface from another and carries no meaning. WCAG 1.4.11 does
  /// not apply — nothing is identified by it — so it stays quiet.
  static const outlineLight = Color(0xFFDAD7CA);
  static const outlineDark = Color(0xFF3D4A3B);

  /// The boundary of an interactive component: a field, a bordered control.
  /// Here the line *is* the affordance, so it clears **3:1** — measured
  /// **3.51:1** on the light page and **3.13:1** on a dark card.
  ///
  /// Splitting this from [outlineLight] is not pedantry. A filled input sits
  /// only 1.10:1 above the page, which is invisible to a good many people; the
  /// fill is decoration and this line is what says "you can type here".
  static const outlineStrongLight = Color(0xFF7F8479);
  static const outlineStrongDark = Color(0xFF7D8277);

  // ── Semantic ─────────────────────────────────────────────────────────────
  // Each is always paired with an icon and a label; colour alone is never the
  // signal (roughly 8% of male users cannot rely on it).
  //
  // Every value is measured against the *container* it is read on — the card,
  // not the page — because that is the harder of the two.

  /// **5.53:1** on a light card. Deliberately brighter and more saturated than
  /// [forest]: on a green-branded interface a success green that resembles the
  /// primary reads as chrome rather than as a state.
  static const successLight = Color(0xFF1B6B10);
  static const successDark = Color(0xFF7FD36B); // 6.72:1

  static const warningLight = Color(0xFF8A5A00); // 4.92:1
  static const warningDark = Color(0xFFFFC14D); // 7.63:1
  static const dangerLight = Color(0xFFB3261E); // 5.43:1
  static const dangerDark = Color(0xFFFF897D); // 5.36:1
  static const infoLight = Color(0xFF1F5F8B); // 5.69:1
  static const infoDark = Color(0xFF7FC4F5); // 6.53:1
  static const neutralLight = Color(0xFF5C5F5A); // 5.39:1
  static const neutralDark = Color(0xFFA8ADA4); // 5.39:1

  // ── Tonal anchors ────────────────────────────────────────────────────────
  // Seeds for the Material 3 palettes. Kept within the brand's own hue so the
  // generated containers stay in the family rather than drifting toward the
  // saturated greens Material derives from a raw seed.

  static const brandContainerLight = Color(0xFFD7DCD3);
  static const brandContainerDark = Color(0xFF3B4C39);
  static const secondaryContainerLight = Color(0xFFDCE4E9);
  static const secondaryContainerDark = Color(0xFF29383F);
  static const tertiaryContainerLight = Color(0xFFE4E2D8);
  static const tertiaryContainerDark = Color(0xFF33392F);
}

/// Depth, as two shadows rather than one.
///
/// A single blurred drop reads as a sticker. Two — a tight contact shadow that
/// anchors an edge, and a wide ambient one that lifts the whole shape — is what
/// the eye accepts as an object on a surface, and it is the difference between
/// a card that looks pasted on and one that looks placed.
///
/// **Light mode only, and not for decoration.** A card sits 1.10:1 above the
/// cream page — the same near-invisibility that forced a real border onto the
/// input fields. The shadow is what makes a card legible *as a card*. Dark mode
/// gets none: a shadow is invisible against a forest field and costs a raster
/// pass to prove it, so the hairline outline does that job there instead.
///
/// Both shadows are forest, never black. Black on warm cream goes muddy; the
/// brand's own dark tinted down stays in the family.
abstract final class AppElevation {
  /// A card, a tile, a sheet at rest.
  static const List<BoxShadow> resting = [
    BoxShadow(color: Color(0x0F2B382A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D2B382A), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Under a finger. Shallower, not deeper — pressing something pushes it
  /// toward the page, and a card that grows a bigger shadow when touched is
  /// moving the wrong way.
  static const List<BoxShadow> pressed = [
    BoxShadow(color: Color(0x0D2B382A), blurRadius: 1, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x082B382A), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Anything that floats over content and must be read as detached: a menu, a
  /// bottom sheet, a dialog.
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x142B382A), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x142B382A), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// Every shadow above is this colour with an alpha channel — which `const`
  /// cannot express any other way, so `app_elevation_test.dart` proves it
  /// rather than this comment claiming it.
  static const Color source = AppColors.forest;
}

/// Opacities for tinting a surface with the colour of the thing it describes.
///
/// A status chip, a swipe background and the plate behind an empty-state glyph
/// are all the same move — take an accent, lay it under content at low opacity
/// — and they must be the same strength or the interface reads as if the
/// stronger one means more. Four different values had already appeared for
/// this; these three replace them.
abstract final class AppTint {
  /// A filled surface: chip, badge, swipe background.
  static const double surface = 0.12;

  /// The far end of a gradient across such a surface — enough to give it a
  /// direction, not enough to read as a second shape.
  static const double surfaceFaint = 0.04;

  /// Light falling behind a shape rather than a shape of its own.
  static const double glow = 0.07;

  /// A shimmering placeholder rests at [shimmerRest] and travels
  /// [shimmerTravel] above it. Deliberately narrow: a placeholder that pulses
  /// hard competes with the content it is standing in for.
  static const double shimmerRest = 0.4;
  static const double shimmerTravel = 0.3;
}
