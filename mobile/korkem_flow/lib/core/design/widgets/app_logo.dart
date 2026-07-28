import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/typography.dart';

/// The KORKEM mark: a bold К on the brand green.
///
/// A letterform rather than an invented pictogram. An abstract mark has to be
/// taught before it means anything, and at 48dp on a launcher grid a legible
/// initial beats a shape nobody recognises. Cyrillic К, because that is how the
/// company writes its own name.
///
/// Drawn from tokens, never from literals, so it stays in step with the theme —
/// and it doubles as the source image for the launcher icon
/// (`test/tools/generate_app_icon_test.dart`).
class AppLogo extends StatelessWidget {
  const AppLogo({
    this.size = 96,
    this.transparent = false,
    this.glyphScale = 0.58,
    this.fullBleed = false,
    super.key,
  });

  final double size;

  /// Omits the background plate. Used for the Android adaptive-icon
  /// foreground layer, where the background is a separate solid layer.
  final bool transparent;

  /// Glyph height as a fraction of [size].
  final double glyphScale;

  /// Square corners, for the exported launcher asset.
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: transparent ? null : AppColors.surfaceDark,
          // Rounded only where it is drawn *in* the app. The exported launcher
          // asset stays full-bleed: Android masks adaptive icons and Play
          // rounds the store icon itself, so baking corners in would show as a
          // dark ring inside the mask.
          borderRadius: (transparent || fullBleed)
              ? null
              : BorderRadius.circular(size * 0.22),
        ),
        child: Center(
          child: Text(
            'К',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              // Tight tracking and heavy weight: at launcher size the counters
              // close up before the stems do, so weight reads before shape.
              fontWeight: FontWeight.w800,
              fontSize: size * glyphScale,
              height: 1,
              letterSpacing: -size * 0.02,
              color: AppColors.brand,
            ),
          ),
        ),
      ),
    );
  }
}
