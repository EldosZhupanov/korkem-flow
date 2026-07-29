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

  /// Route pushes and pops.
  ///
  /// Longer than [standard] because a page transition moves the whole screen:
  /// the same speed that reads as crisp on a chip reads as a flicker here.
  static const page = Duration(milliseconds: 350);
}

abstract final class AppCurves {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// For anything that changes size or position under a finger.
  ///
  /// A slight overshoot is what separates "the software responded" from "the
  /// thing I touched moved". Kept small — a visible bounce on an ERP list is
  /// a toy, not a tool.
  static const Curve emphasised = Curves.easeOutBack;
}

/// Distances and scales that motion moves through.
///
/// Amplitude is a design token exactly like duration is. A 24dp slide and an
/// 8dp slide are different products, and the difference should be decided once.
abstract final class AppMotionScale {
  /// How far a row travels as it enters. Small on purpose: the eye should read
  /// the arrival, not track the journey.
  static const double enterOffsetY = 12;

  /// Press feedback on a card or tile.
  static const double pressedScale = 0.97;

  /// Press feedback on a small control, where the same ratio is imperceptible.
  static const double pressedScaleCompact = 0.92;
}

/// Resolves a duration against the user's reduced-motion preference.
///
/// Call this instead of using [AppDuration] directly in animated widgets.
Duration motionOf(BuildContext context, Duration duration) {
  return MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;
}
