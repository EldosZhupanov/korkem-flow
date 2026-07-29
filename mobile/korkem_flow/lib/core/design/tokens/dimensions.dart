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

  /// Narrowest a KPI tile may get before the grid drops a column.
  static const double minTileWidth = 180;
}

/// Heights that exist because a layout has to reserve space before it knows
/// what will fill it. Each one is a promise that the placeholder and the real
/// thing are the same size — get it wrong and content jumps on arrival.
abstract final class AppPlaceholder {
  /// A skeleton row, matching a populated entity card.
  static const double rowHeight = 88;

  /// The KPI number, matching `displaySmall` at its line height.
  static const double metricHeight = 44;
  static const double metricWidth = 72;
}

/// Distances measured along a scroll axis rather than across the layout.
abstract final class AppScrollExtent {
  /// How far from the bottom the next page starts loading — roughly one
  /// viewport, so the page is usually there before the user arrives.
  static const double prefetch = 400;
}
