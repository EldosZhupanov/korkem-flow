import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// The mark that heads an empty, error or success state.
///
/// The ground is the woven ornament from KORKEM's own Ö, laid in faintly, with
/// the state's icon centred inside it. That is not a stylistic flourish — it is
/// the one piece of artwork the company actually owns, and it is already in the
/// repository as an alpha mask cut from `logo/file-001.png`, so no illustration
/// had to be drawn, licensed or downloaded to get here.
///
/// It replaces a generic tinted disc. The disc was fine and could have belonged
/// to any product; a Kazakh lattice could not. Stock sets — unDraw, Storyset —
/// were considered again after the real brand turned up and are a worse fit
/// than before, not better: flat pastel figures next to a serif heritage
/// identity read as borrowed, and no amount of recolouring fixes the drawing
/// style underneath.
///
/// Three layers, and the order matters. A soft halo that reads as light rather
/// than as a ring; the ornament, quiet enough to be texture; and the glyph,
/// solid, because it is the thing carrying the meaning.
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
    final isDark = theme.brightness == Brightness.dark;

    final halo = dense ? AppIllustration.haloDense : AppIllustration.halo;
    final plate = dense ? AppIllustration.plateDense : AppIllustration.plate;
    final glyph = dense ? AppIconSize.normal : AppIconSize.illustration;

    final art = SizedBox.square(
      dimension: halo,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Very low alpha — at anything stronger it stops lighting the
            // ornament and becomes a second shape competing with it.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: AppTint.glow),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SizedBox.square(dimension: halo),
            ),
            // Tinted from `onSurface`, not from the glyph's accent.
            //
            // The ornament carries the brand; the glyph carries the meaning,
            // and they are not the same job. Tying the weave to the accent
            // also made it disappear: on the dark theme `outline` sits almost
            // on top of the forest surface, so a success-toned or neutral
            // state showed no ornament at all however high the alpha went.
            // `onSurface` is the one colour guaranteed to have contrast
            // against whatever it is drawn on.
            Image.asset(
              'assets/brand/korkem_ring.png',
              width: plate,
              height: plate,
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? AppTint.ornamentOnDark : AppTint.ornament,
              ),
              excludeFromSemantics: true,
            ),
            Icon(icon, size: glyph, color: accent),
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
