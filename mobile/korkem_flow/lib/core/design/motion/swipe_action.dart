import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';

/// The panel revealed behind a row as it is dragged.
///
/// It grows into the gesture rather than appearing whole at the first pixel of
/// movement. A full-strength panel under a 2dp drag reads as a mis-tap having
/// already done something, which on a destructive action is the worst possible
/// thing for an interface to imply.
///
/// Shared so that one motion keeps meaning one thing: a swipe from the leading
/// edge is always "this is handled", in the same colour and at the same rate,
/// whether the row is a task or a notification.
class SwipeActionBackground extends StatelessWidget {
  const SwipeActionBackground({
    required this.icon,
    required this.color,
    required this.progress,
    super.key,
  });

  final IconData icon;
  final Color color;

  /// How far through the swipe the finger is, 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTint.surface * t),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Icon(icon, color: color.withValues(alpha: t)),
        ),
      ),
    );
  }
}
