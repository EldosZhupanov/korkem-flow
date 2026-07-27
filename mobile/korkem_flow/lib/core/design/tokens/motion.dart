import 'package:flutter/widgets.dart';

/// Duration tokens.
///
/// Every animation in the app resolves its duration here so timing stays
/// coherent across screens. All motion must also honour
/// `MediaQuery.disableAnimations` — an animation that cannot be switched off is
/// an accessibility defect, not a feature.
abstract final class AppDuration {
  static const instant = Duration(milliseconds: 100);
  static const quick = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);

  /// Per-row delay when staggering a list, capped at [staggerMaxRows].
  static const stagger = Duration(milliseconds: 20);

  /// Beyond about six rows a stagger reads as lag rather than polish.
  static const int staggerMaxRows = 6;
}

abstract final class AppCurves {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

/// Resolves a duration against the user's reduced-motion preference.
///
/// Call this instead of using [AppDuration] directly in animated widgets.
Duration motionOf(BuildContext context, Duration duration) {
  return MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;
}
