import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Sends Android's back gesture from a secondary tab to the first tab, instead
/// of out of the app.
///
/// Wraps the *root screen of each branch*, and that placement is the whole
/// point. Two earlier attempts failed for the same underlying reason:
///
/// - a `PopScope` in the shell widget is never consulted, because it sits above
///   the branch navigators and back is dispatched to the innermost one;
/// - a `BackButtonListener` in the shell is not consulted either, because it
///   uses the legacy `didPopRoute` channel, while `targetSdk 36` turns on
///   predictive back — which routes through `PopScope` registrations instead.
///
/// Registered here, on a route that genuinely belongs to the branch navigator,
/// it is consulted by both paths. A pushed detail route sits above this one in
/// the same navigator and still pops first, untouched.
class TabBackHandler extends StatelessWidget {
  const TabBackHandler({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shell = StatefulNavigationShell.of(context);
    final atFirstTab = shell.currentIndex == 0;

    return PopScope(
      // Leaving the app is the right outcome from the first tab, and only
      // from there.
      canPop: atFirstTab,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        shell.goBranch(0);
      },
      child: child,
    );
  }
}
