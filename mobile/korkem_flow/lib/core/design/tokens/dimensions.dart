/// Geometry tokens: spacing, radius and touch targets.
///
/// No literal spacing, radius or size value may appear in a widget file. That
/// rule is the only thing that keeps a design system intact under delivery
/// pressure.
library;

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

  /// The default: cards and list tiles.
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
}

/// Minimum interactive size.
///
/// 48dp is the accessibility floor. Shop-floor primary actions use
/// [comfortable] because they are operated with gloves on.
abstract final class AppTouchTarget {
  static const double min = 48;
  static const double comfortable = 56;
}

abstract final class AppIconSize {
  static const double inline = 16;
  static const double small = 20;
  static const double normal = 24;
  static const double large = 32;
  static const double illustration = 48;
}

/// Width-driven breakpoints. Layout never branches on `Platform.isX`.
abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 1024;
}
