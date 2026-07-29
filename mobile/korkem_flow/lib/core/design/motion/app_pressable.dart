import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// Adds a scale-down response to a press.
///
/// An ink ripple says *the framework noticed*; a scale says *this object is
/// under your finger*. On a list of cards the difference is most of what
/// separates an interface that feels direct from one that feels remote, and it
/// costs one transform — no repaint of the child.
///
/// Wraps rather than replaces the ink response: the ripple still communicates
/// hit-area, which a scale alone does not.
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    this.onTap,
    this.scale = AppMotionScale.pressedScale,
    super.key,
  });

  final Widget child;

  /// When null the widget is inert and no press feedback is shown — a control
  /// that reacts to touch but does nothing is worse than one that ignores it.
  final VoidCallback? onTap;

  final double scale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      // Translucent, so the gesture is seen without stealing it: the child's
      // own InkWell still receives the tap and draws its ripple.
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        // Fast on the way down, so the response feels immediate; the release
        // rides the same duration because an asymmetric spring reads as lag.
        duration: motionOf(context, AppDuration.instant),
        curve: AppCurves.standard,
        child: widget.child,
      ),
    );
  }
}
