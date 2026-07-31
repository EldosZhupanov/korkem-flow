import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// A number that counts to its value instead of appearing at it.
///
/// The dashboard's numbers are the only thing on that screen a user came for,
/// and a figure that rolls up reads as *measured* — the difference between a
/// dashboard and a list of constants. It is also the cheapest
/// animation possible: one `Text` rebuilt per frame for a third of a second,
/// no layout change, no repaint boundary crossed.
///
/// Three rules keep it from becoming a gimmick:
///
/// * It animates from the **previous value**, not from zero. Once a number is
///   on screen, re-running it from nothing every refresh would say "this was
///   zero a moment ago", which is false and, on an overdue count, alarming.
/// * The first appearance *does* come up from zero: there is nothing to
///   contradict, and the movement is what draws the eye to the figure.
/// * A null value — the backend withholding a number the user may not see — is
///   a dash, and a dash does not count.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    required this.value,
    required this.placeholder,
    this.style,
    super.key,
  });

  /// Null when the caller has no number: not zero, and never animated.
  final int? value;

  /// Shown in place of a number. A dash, not a "0" — the backend returns null
  /// when the signed-in role may not see a figure, and stating zero would
  /// assert something the user has no standing to know.
  final String placeholder;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final target = value;
    if (target == null) return Text(placeholder, style: style, maxLines: 1);

    final duration = motionOf(context, AppDuration.count);
    if (duration == Duration.zero) {
      return Text('$target', style: style, maxLines: 1);
    }

    return TweenAnimationBuilder<double>(
      // Deliberately unkeyed, and `begin` is only ever honoured once.
      //
      // `TweenAnimationBuilder` re-bases its own `begin` to whatever is
      // currently on screen when `end` changes, which gives both rules for
      // free: zero on the first build, and the previous figure on every
      // refresh after it. Keying this on the value defeats exactly that — the
      // element is destroyed and rebuilt, `begin` is applied afresh, and the
      // widget animates nothing at all. It shipped that way for one commit and
      // a test caught it.
      tween: Tween<double>(begin: 0, end: target.toDouble()),
      duration: duration,
      curve: AppCurves.enter,
      builder: (context, shown, _) =>
          Text('${shown.round()}', style: style, maxLines: 1),
    );
  }
}
