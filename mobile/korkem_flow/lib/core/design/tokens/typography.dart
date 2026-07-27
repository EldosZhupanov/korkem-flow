import 'package:flutter/material.dart';

/// The Inter type scale.
///
/// Inter is bundled (see `THIRD_PARTY_LICENSES.md`) rather than fetched at
/// runtime, and was verified to cover Kazakh, Russian, Latin and ₸.
///
/// Two rules the rest of the app depends on:
///
/// * Numeric styles use **tabular figures**. Without them, quantity and
///   currency columns visibly jitter as a list scrolls — the most noticeable
///   typographic defect in an ERP interface.
/// * Nothing is smaller than 11sp, and no screen uses more than three sizes.
abstract final class AppTypography {
  static const fontFamily = 'Inter';

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Applies to numbers that appear in aligned columns.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tabular);

  static TextTheme textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFE6E6E6) // not pure white: reduces halation on dark
        : const Color(0xFF1A1C19);

    TextStyle style(
      double size,
      double height,
      FontWeight weight, {
      double letterSpacing = 0,
      bool numeric = false,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
        fontFeatures: numeric ? _tabular : null,
      );
    }

    return TextTheme(
      // Dashboard hero metric — always a number, always tabular.
      displaySmall: style(36, 44, FontWeight.w600, numeric: true),
      headlineMedium: style(28, 36, FontWeight.w600, letterSpacing: -0.2),
      titleLarge: style(22, 28, FontWeight.w600),
      // List item title.
      titleMedium: style(16, 24, FontWeight.w600),
      titleSmall: style(14, 20, FontWeight.w600),
      bodyLarge: style(16, 24, FontWeight.w400),
      bodyMedium: style(14, 20, FontWeight.w400),
      bodySmall: style(12, 16, FontWeight.w400),
      labelLarge: style(14, 20, FontWeight.w600),
      labelMedium: style(12, 16, FontWeight.w500),
      // Chips, captions, timestamps. The floor at 11sp.
      labelSmall: style(11, 16, FontWeight.w500, letterSpacing: 0.2),
    );
  }
}
