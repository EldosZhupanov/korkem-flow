import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// The single decorative element in the app: a glyph on a lit plate.
///
/// Drawn from theme colours rather than shipped as artwork, and that is a
/// deliberate trade. Stock illustration sets — unDraw, Storyset — are free and
/// good, but every one of them arrives with its own palette, its own line
/// weight and its own idea of a human figure, none of which are KORKEM's. On a
/// tool a factory sees forty times a day, art that does not match the product
/// stops reading as friendly within a week and starts reading as clip art. This
/// composition inherits the theme, so it is correct in light and dark, at any
/// accent, forever, and costs no asset, no licence and no download.
///
/// Three layers, which is what separates this from a big icon: a soft halo that
/// reads as light rather than as a ring, a plate with a gradient running across
/// it, and the glyph. The gradient is what gives the plate a direction — flat
/// fill at this size looks like a mistake.
class StateIllustration extends StatelessWidget {
  const StateIllustration({
    required this.icon,
    this.color,
    this.dense = false,
    super.key,
  });

  final IconData icon;

  /// Defaults to the theme's outline: an empty state is information, not a
  /// warning, and should not shout in the app's accent colour.
  final Color? color;

  /// Shrinks the mark for an empty state that shares a screen with content.
  /// At full size it pushes its own headline off the bottom of a section.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.outline;
    final duration = motionOf(context, AppDuration.slow);

    final halo = dense ? AppIllustration.haloDense : AppIllustration.halo;
    final plate = dense ? AppIllustration.plateDense : AppIllustration.plate;
    final glyph = dense ? AppIconSize.normal : AppIconSize.illustration;

    final art = SizedBox.square(
      dimension: halo,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo. Very low alpha — at anything stronger it stops lighting the
            // plate and becomes a second shape competing with it. The brand
            // green is near-fluorescent, so on a dark surface it blooms at
            // values that look restrained on a light one.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.07),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SizedBox.square(dimension: halo),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.12),
                    accent.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: SizedBox.square(
                dimension: plate,
                child: Icon(icon, size: glyph, color: accent),
              ),
            ),
          ],
        ),
      ),
    );

    if (duration == Duration.zero) return art;

    // Eases up from small, which is what makes an empty state feel like an
    // answer arriving rather than a hole in the screen.
    return art
        .animate()
        .fadeIn(duration: duration, curve: AppCurves.enter)
        .scaleXY(begin: 0.85, duration: duration, curve: AppCurves.emphasised);
  }
}
