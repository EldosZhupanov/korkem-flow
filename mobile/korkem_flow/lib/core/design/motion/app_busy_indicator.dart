import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// Three dots breathing in sequence: what a button shows while it waits.
///
/// It replaces a `CircularProgressIndicator`, and not only because a spinner
/// looks dated. A spinner is a *rotation*, and rotation reads as "something is
/// turning over there"; a row of dots rising and settling reads as "this
/// control is working". At 20dp inside a button that difference is most of the
/// tactile quality of the whole screen.
///
/// It also fixes something a spinner gets wrong here. Material's indicator
/// carries its own colour from the theme's primary, so in a filled button
/// it drew the *page's* accent on the button's fill — cream on cream, in
/// the dark theme, which was very nearly invisible. This inherits
/// `DefaultTextStyle`, so it is whatever colour the label it replaced was.
class AppBusyIndicator extends StatefulWidget {
  const AppBusyIndicator({
    this.size = AppIconSize.small,
    this.color,
    super.key,
  });

  /// The width of the whole group, not of one dot.
  final double size;

  /// Defaults to the surrounding text colour, which inside a button is its
  /// foreground — the one colour guaranteed to be legible on that fill.
  final Color? color;

  @override
  State<AppBusyIndicator> createState() => _AppBusyIndicatorState();
}

class _AppBusyIndicatorState extends State<AppBusyIndicator>
    with SingleTickerProviderStateMixin {
  static const _dots = 3;

  /// How far through the cycle each dot lags the one before it. Small enough
  /// that the group reads as one object rather than three racing separately.
  static const _stagger = 0.18;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour reduced motion: a perpetual pulse is exactly what the setting is
    // for. The dots stay, evenly lit, so the control still reads as busy.
    if (motionOf(context, AppDuration.standard) == Duration.zero) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color;
    final dot = widget.size / (_dots * 2 - 1);

    return SizedBox(
      width: widget.size,
      height: dot,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dots; i++) ...[
              if (i > 0) SizedBox(width: dot),
              Opacity(
                opacity: _opacityOf(i),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: dot),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A dot's brightness at this instant.
  ///
  /// A cosine rather than a triangle: a linear fade has a visible corner at the
  /// top and bottom of every cycle, and three corners in a row is a flicker.
  double _opacityOf(int index) {
    if (!_controller.isAnimating) return 1;
    final t = (_controller.value - index * _stagger) % 1.0;
    final wave = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
    return _dim + (1 - _dim) * wave;
  }

  /// How far a dot dims at the bottom of its cycle. Never to nothing — three
  /// dots that vanish one at a time read as a fault, not as progress.
  static const double _dim = 0.3;
}
