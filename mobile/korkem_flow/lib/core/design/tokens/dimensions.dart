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
  /// Beside `labelSmall` on a metadata row, where 16 crowds the text it is
  /// annotating. Previously written as `inline - 2` at five separate call
  /// sites — arithmetic on a token is a token nobody agreed to.
  static const double dense = 14;

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

  /// Narrowest window that keeps the navigation panel on screen permanently.
  ///
  /// A tablet held in portrait — 768 is the classic one — leaves 488 for the
  /// conversation beside a 280 panel, which is wider than any phone this app
  /// runs on, so the column is not squeezed by having the panel there. Above
  /// [readable] + [AppNavigation.sidebarWidth] the column stops growing and the
  /// extra width becomes margin; that is a comfort, not the threshold.
  ///
  /// Width is necessary but not sufficient — see `AdaptiveShell`, which also
  /// requires the window to be taller than [compact].
  static const double sidebar = 768;

  /// Narrowest a KPI tile may get before the grid drops a column.
  static const double minTileWidth = 180;

  /// The list pane in a master-detail layout.
  ///
  /// Wide enough for an order number, a customer name and a status chip on one
  /// line without truncation; narrow enough that at [medium] the detail beside
  /// it still clears [readable]. Below that the layout is single-column
  /// anyway, so this dimension only ever binds on a tablet or a desktop
  /// window.
  static const double listPaneWidth = 380;

  /// The widest a column of content may get before it stops being readable.
  ///
  /// Not a stylistic cap. At 1024dp a deal card ran the full width, which put
  /// its status chip some 600dp from the title it describes — far enough that
  /// the two cannot be taken in together, so a glanceable list stopped being
  /// glanceable. A phone is unaffected; this only ever binds on a tablet, a
  /// foldable or a desktop window.
  static const double readable = 720;
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

/// The composed glyph that heads an empty, error or success state.
///
/// Sized generously: this is the only decorative element in the app, and it
/// only ever appears on a screen that has nothing else to show.
abstract final class AppIllustration {
  /// The tinted plate the glyph sits on.
  static const double plate = 112;

  /// The soft halo behind the plate. Larger by roughly a third — enough to
  /// read as light falling on the plate rather than as a second ring.
  static const double halo = 148;

  /// For an empty state embedded in a section of a populated screen, where the
  /// full-size mark would push its own headline below the fold.
  static const double plateDense = 64;
  static const double haloDense = 84;
}

/// Lines drawn rather than spaces left.
abstract final class AppStroke {
  /// A divider, a rail separator, a rule under a wordmark. One logical pixel:
  /// thicker reads as a border, and a border is a stronger statement than any
  /// of those places wants to make.
  static const double hairline = 1;

  /// A focused field's border. Doubled, because focus has to be visible to
  /// someone navigating by keyboard who cannot see a caret blink.
  static const double focus = 2;
}

/// Marks that carry state rather than content.
abstract final class AppIndicator {
  /// The unread dot on a notification row. Small enough to read as a mark
  /// beside the text rather than as a bullet in front of it.
  static const double dot = 8;

  /// How far the dot sits below the top of its row, to centre it on the first
  /// line of a title set in `bodyMedium`.
  static const double dotBaselineOffset = 6;
}

/// How large the brand mark is drawn.
abstract final class AppLogoSize {
  /// In a list or beside a title.
  static const double compact = 32;

  /// The default: a header, a card.
  static const double standard = 96;

  /// The splash, where the mark is the only thing on screen.
  static const double hero = 132;
}

/// The app's own chrome.
abstract final class AppNavigation {
  /// Bottom bar height. Tighter than Material's 80dp default, which spends a
  /// visible band of a phone screen on nothing, and still clear of the 48dp
  /// touch floor with room for an always-visible label.
  ///
  /// No longer used for the app's own navigation, which is a panel now — kept
  /// because the theme still sizes any `NavigationBar` a future screen builds.
  static const double barHeight = 72;

  /// The navigation panel when it is permanent, on a wide screen.
  ///
  /// 280 + [AppBreakpoints.readable] = 1000, which is what puts the permanent
  /// breakpoint at `medium`: below that the panel would be taking width the
  /// reading column needs.
  static const double sidebarWidth = 280;
}

/// Distances measured along a scroll axis rather than across the layout.
abstract final class AppScrollExtent {
  /// How far from the bottom the next page starts loading — roughly one
  /// viewport, so the page is usually there before the user arrives.
  static const double prefetch = 400;
}
