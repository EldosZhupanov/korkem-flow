import 'package:flutter/widgets.dart';

/// Raw colour values.
///
/// Widgets must not read these directly — they read `Theme.of(context)` and,
/// for status colours, the `StatusColors` theme extension. These constants
/// exist to build those themes in one place.
///
/// Every contrast ratio quoted here was computed against WCAG 2.1, not
/// estimated. See `docs/design_system.md` §2.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────

  /// KORKEM brand neon green.
  ///
  /// Measured: **1.36:1** against white — it therefore may never be used as a
  /// text or icon colour in the light theme, and never as a filled button with
  /// a white label. Against black it is 15.49:1 and against the dark surface
  /// 13.82:1, which is why it is the hero accent in dark and a fill carrying
  /// black content in light.
  static const brand = Color(0xFF39FF14);

  /// AA-safe green for text and icons on light surfaces (**5.49:1**).
  ///
  /// Do not "brighten" this to `0xFF1F8A0A`: that measures 4.47:1 and fails AA
  /// by a hair while looking almost identical on screen.
  static const brandOnLight = Color(0xFF177A08);

  static const brandContainerLight = Color(0xFFC8F5BE);
  static const brandContainerDark = Color(0xFF1F4D14);

  /// Content colour on top of [brand]. Black, never white — see above.
  static const onBrand = Color(0xFF0A0A0A);

  // ── Semantic ─────────────────────────────────────────────────────────────
  // Each is always paired with an icon and a label; colour alone is never the
  // signal (roughly 8% of male users cannot rely on it).

  static const successLight = Color(0xFF177A08);
  static const successDark = Color(0xFF5BFF3F);
  static const warningLight = Color(0xFF8A5A00);
  static const warningDark = Color(0xFFFFC14D);
  static const dangerLight = Color(0xFFB3261E);
  static const dangerDark = Color(0xFFFF897D);
  static const infoLight = Color(0xFF1F5F8B);
  static const infoDark = Color(0xFF7FC4F5);
  static const neutralLight = Color(0xFF5C5F5A);
  static const neutralDark = Color(0xFFA8ADA4);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  // Dark surfaces step tonally rather than by shadow: shadows are invisible on
  // dark backgrounds and only cost a raster pass. Pure black is avoided because
  // it smears while scrolling on OLED.

  static const surfaceLight = Color(0xFFFCFDFB);
  static const surfaceDark = Color(0xFF121212);
  static const surfaceContainerLight = Color(0xFFF1F4EF);
  static const surfaceContainerDark = Color(0xFF1E1E1E);

  static const outlineLight = Color(0xFFC7CCC3);
  static const outlineDark = Color(0xFF3A3F38);

  // Secondary / tertiary anchors used to seed the Material 3 tonal palettes.
  static const secondaryContainerLight = Color(0xFFD3E7F5);
  static const secondaryContainerDark = Color(0xFF12384F);
  static const tertiaryContainerLight = Color(0xFFE3E5E1);
  static const tertiaryContainerDark = Color(0xFF2A2E29);
}

/// Opacities for tinting a surface with the colour of the thing it describes.
///
/// A status chip, a swipe background and the plate behind an empty-state glyph
/// are all the same move — take an accent, lay it under content at low opacity
/// — and they must be the same strength or the interface reads as if the
/// stronger one means more. Four different values had already appeared for
/// this; these three replace them.
///
/// Values are tuned for the brand green, which is near-fluorescent and blooms
/// on a dark surface at opacities that look restrained on a light one. Raising
/// them is a design-system change, not a local one.
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
