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

  /// One sweep of a loading placeholder. Slow on purpose — a shimmer is
  /// ambient, and anything quicker asks to be watched.
  static const shimmer = Duration(milliseconds: 1200);

  /// One breath of a busy indicator. Slow enough to read as waiting rather
  /// than as urgency — a control that pulses fast tells the user something is
  /// wrong when nothing is.
  static const pulse = Duration(milliseconds: 1400);

  /// A figure rolling up to its value.
  ///
  /// Longer than [standard]: the eye has to read digits changing, not just
  /// notice that something moved. Short of half a second, though — a dashboard
  /// that makes you wait to learn a number is a dashboard that is showing off.
  static const count = Duration(milliseconds: 420);

  /// Long enough that a user has decided something is wrong.
  ///
  /// The threshold for admitting to a delay: below it, an explanation arrives
  /// before anyone wondered, and the app looks slower than it is.
  static const deliberate = Duration(milliseconds: 600);
}

/// How long the app waits on a person before acting.
///
/// Separate from [AppDuration] on purpose: these are not animations and must
/// not be shortened by reduced-motion. Never pass one through [motionOf].
abstract final class AppDebounce {
  /// Typing in a search field. Each keystroke would otherwise be a backend
  /// round trip — the fastest way to make a list feel slow and get rate
  /// limited. Roughly the gap between two characters at conversational typing
  /// speed, so a pause reads as "finished the word".
  static const search = Duration(milliseconds: 300);

  /// The window in which a completed row can be taken back, and the exact
  /// lifetime of the snackbar that offers the undo.
  ///
  /// The two must be the same value or the feature is broken in one direction
  /// or the other: a window outliving its affordance is one nobody can use,
  /// and an affordance outliving its window is a button that silently stops
  /// working while still on screen. Longer than Material's 4s default because
  /// a swipe is easy to make by accident and this is the only way back.
  static const undo = Duration(seconds: 6);
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
