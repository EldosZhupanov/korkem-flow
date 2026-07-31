import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';

/// Caps a column of content at a readable width and centres it.
///
/// On a phone this does nothing at all — it only binds on a tablet, a foldable
/// or a resized desktop window, which is exactly where the app was worst.
///
/// At 1024dp a deal card ran the full width of the screen. Its title sat at the
/// left edge and its status chip at the right, some 600dp apart: far enough
/// that the eye cannot take in both, so a list whose whole purpose is to be
/// glanced at stopped being glanceable. The phone number underneath had a line
/// to itself wide enough for a paragraph.
///
/// Widening a layout is not the same as using the space. Linear, Notion and
/// Stripe all cap the measure and centre it, and they do it for legibility
/// rather than for looks.
///
/// Applied once, in the two screen shells, rather than at each screen — a rule
/// every screen has to remember is a rule that half of them will not.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      // Top, not centre. A short list should hang from the top of the screen
      // like every other list; centring would float it in the middle of a
      // tablet the moment it had fewer rows than fill the height.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.readable),
        child: child,
      ),
    );
  }
}
