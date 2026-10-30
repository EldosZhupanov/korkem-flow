import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';

/// The KORKEM mark, as the company actually draws it.
///
/// This used to be a bold Cyrillic К set in Inter — an invented mark, made
/// before anyone had seen the real one. The brand is a woven Kazakh ornament
/// inside the Ö of a serif wordmark, and no amount of tuning a letterform was
/// going to arrive at it.
///
/// Both layers are shipped as alpha masks and tinted at runtime, so one asset
/// is correct on a cream page and on a forest field. The alpha was recovered by
/// projecting each source pixel onto the field→ink axis, which keeps the
/// anti-aliasing of the original curves instead of hard-thresholding them into
/// a jagged edge.
enum LogoLayout {
  /// The ornamented Ö alone. Legible small, because the wordmark is not: at
  /// launcher size "KORKEM" is a grey smear while the ring and its lattice
  /// still read.
  mark,

  /// The full framed lockup — rules, wordmark, SINCE 2021. For places with the
  /// width to give it, where the company should be named rather than hinted at.
  lockup,
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    this.layout = LogoLayout.mark,
    this.size = AppLogoSize.standard,
    this.color,
    super.key,
  });

  final LogoLayout layout;

  /// The mark's height, or the lockup's width — whichever is the constraining
  /// dimension for that layout.
  final double size;

  /// Defaults to the theme's primary, which is forest on a light surface and
  /// cream on a dark one: the logo, and the logo inverted.
  final Color? color;

  /// The artwork's own proportions, so nothing is ever stretched.
  static const double _markAspect = 452 / 591;
  static const double _lockupAspect = 3245 / 965;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;

    final (asset, width, height, label) = switch (layout) {
      LogoLayout.mark => (
        'assets/brand/korkem_mark.png',
        size * _markAspect,
        size,
        'KORKEM',
      ),
      LogoLayout.lockup => (
        'assets/brand/korkem_lockup.png',
        size,
        size / _lockupAspect,
        'KORKEM — since 2021',
      ),
    };

    return Image.asset(
      asset,
      width: width,
      height: height,
      // Tints the mask rather than drawing over it, so the transparent ground
      // stays transparent and the mark inherits whatever surface it lands on.
      color: tint,
      semanticLabel: label,
    );
  }
}
