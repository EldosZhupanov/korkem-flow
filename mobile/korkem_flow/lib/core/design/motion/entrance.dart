import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// Fades and lifts a widget into place, optionally staggered by its position.
///
/// This is the concrete use of [AppDuration.stagger] and
/// [AppDuration.staggerMaxRows], which the design system has always specified
/// and nothing has ever applied.
///
/// Two rules are enforced here rather than left to call sites, because both are
/// easy to get wrong and expensive to notice:
///
/// * The delay is **capped** at [AppDuration.staggerMaxRows]. Uncapped, row 40
///   of a list waits 800ms and the list reads as broken. Rows past the cap all
///   share the last delay, so a long list still arrives as one gesture.
/// * Reduced motion collapses this to nothing — not to a faster animation, to
///   [Duration.zero]. `motionOf` returns zero and `flutter_animate` then jumps
///   straight to the end state, leaving the widget fully visible.
class Entrance extends StatelessWidget {
  const Entrance({required this.child, this.index = 0, super.key});

  final Widget child;

  /// Position in the list. Anything at or beyond [AppDuration.staggerMaxRows]
  /// shares the same delay.
  final int index;

  @override
  Widget build(BuildContext context) {
    final duration = motionOf(context, AppDuration.standard);
    if (duration == Duration.zero) return child;

    final steps = index.clamp(0, AppDuration.staggerMaxRows);

    return Animate(
      delay: AppDuration.stagger * steps,
      effects: [
        FadeEffect(duration: duration, curve: AppCurves.enter),
        SlideEffect(
          duration: duration,
          curve: AppCurves.enter,
          // Fractional, so the travel scales with the row rather than being a
          // fixed drop that looks heavy on a chip and weightless on a card.
          begin: const Offset(0, AppMotionScale.enterOffsetY / 100),
          end: Offset.zero,
        ),
      ],
      child: child,
    );
  }
}
