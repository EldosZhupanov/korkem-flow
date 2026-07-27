import 'package:flutter/widgets.dart';

/// Design tokens. No literal colour, spacing, radius or duration may appear in
/// a widget file — that rule is what keeps the design system from eroding.
///
/// Contrast ratios quoted below were computed, not estimated. See
/// docs/design_system.md §2.
abstract final class AppColors {
  /// KORKEM brand neon green.
  ///
  /// Measured: 1.36:1 against white — it therefore may NEVER be used as text or
  /// an icon colour in light theme. Against black it is 15.49:1 and against the
  /// dark surface 13.82:1, so it is the hero accent in dark theme and a fill
  /// carrying black content in light theme.
  static const brand = Color(0xFF39FF14);

  /// AA-safe green for text and icons on light surfaces (5.49:1).
  ///
  /// Do not "brighten" this to 0xFF1F8A0A — that measures 4.47:1 and fails AA
  /// by a hair while looking almost identical.
  static const brandOnLight = Color(0xFF177A08);

  static const brandDarkContainer = Color(0xFF1F4D14);
  static const brandLightContainer = Color(0xFFC8F5BE);

  // Semantic — each pairs with an icon and a label, never colour alone.
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

  static const surfaceLight = Color(0xFFFCFDFB);
  static const surfaceDark = Color(0xFF121212);
}

/// 4pt base scale. Only these values are permitted.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// Screen horizontal margin on compact widths.
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;

  /// Default: cards and list tiles.
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
}

abstract final class AppDuration {
  static const instant = Duration(milliseconds: 100);
  static const quick = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
}

abstract final class AppCurves {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
}

/// Minimum interactive size. 48dp is the accessibility floor; shop-floor
/// primary actions use 56 because they are operated with gloves.
abstract final class AppTouchTarget {
  static const double min = 48;
  static const double comfortable = 56;
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 1024;
}
