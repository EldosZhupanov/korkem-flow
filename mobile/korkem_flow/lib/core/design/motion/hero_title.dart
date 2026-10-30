import 'package:flutter/material.dart';

/// An entity's name, carried from its row into its detail screen.
///
/// The app's page transition is a fade-through, which says "different subject".
/// Opening a record is not a different subject — it is the same one, closer —
/// and without something crossing the cut the user has to re-find the name they
/// just tapped. This is that something: one line of text that stays put while
/// everything around it changes.
///
/// Only the title flies. A card that morphs wholesale into a page is the
/// showier effect and the wrong one here: it animates a container the detail
/// screen does not actually have, and it is the kind of motion that reads as
/// expensive the fortieth time you see it in a shift.
///
/// Both ends must use this widget with the same [tag], and a tag must be unique
/// among everything mounted at once — Flutter asserts on a duplicate rather
/// than picking one. Tags are therefore built from the route id, which is
/// unique by construction, and only the three sales lists emit them.
class HeroTitle extends StatelessWidget {
  const HeroTitle({
    required this.tag,
    required this.text,
    required this.style,
    this.maxLines,
    super.key,
  });

  /// Route-derived, e.g. `deal-CRM-DEAL-2026-00001`.
  final String tag;

  final String text;

  /// Where this end of the flight sits typographically. The shuttle
  /// interpolates between the two ends, so a list's `titleMedium` grows into a
  /// header's `headlineMedium` rather than swapping size at the cut.
  final TextStyle? style;

  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: _shuttle,
      child: _Title(text: text, style: style, maxLines: maxLines),
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final from = _titleOf(fromContext);
    final to = _titleOf(toContext);

    // `animation` runs 0 → 1 in the direction of the *route*, not of the
    // flight: 0 is the screen underneath and 1 is the screen on top. On a pop
    // it therefore counts down, while `from` is the screen being left. Picking
    // the ends by direction is what keeps the interpolation the right way
    // round both times, and getting it backwards is invisible on a push.
    final isPush = direction == HeroFlightDirection.push;
    final begin = isPush ? from : to;
    final end = isPush ? to : from;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => _Title(
        text: end.text,
        style: TextStyle.lerp(begin.style, end.style, animation.value),
        // The larger allowance, so a two-line list title does not clip
        // mid-flight on its way to a header that would have shown it whole.
        maxLines: (begin.maxLines ?? 1) > (end.maxLines ?? 1)
            ? begin.maxLines
            : end.maxLines,
      ),
    );
  }

  static _Title _titleOf(BuildContext context) =>
      (context.widget as Hero).child as _Title;
}

class _Title extends StatelessWidget {
  const _Title({
    required this.text,
    required this.style,
    required this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
