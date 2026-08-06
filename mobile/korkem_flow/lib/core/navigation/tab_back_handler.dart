import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/navigation/app_shell_scope.dart';

/// Answers Android's back gesture for the shell: it closes the sidebar if that
/// is open, otherwise returns from a secondary tab to the first one, and only
/// then lets the app be left.
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
///
/// The sidebar has to be answered from here for the same reason. A `Drawer`
/// registers a local history entry with its enclosing `ModalRoute` — the
/// shell's, in the root navigator — but go_router dispatches back to the
/// innermost navigator, so that entry is never reached and the app closed with
/// the panel still open. Verified on a device before the fix, and after.
class TabBackHandler extends StatelessWidget {
  const TabBackHandler({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shell = StatefulNavigationShell.of(context);
    final scope = AppShellScope.maybeOf(context);
    final sidebarIsOpen = scope?.isOpen ?? false;
    final atFirstTab = shell.currentIndex == 0;

    return PopScope(
      // Leaving the app is the right outcome from the first tab, and only from
      // there — and never while the sidebar is covering it.
      canPop: atFirstTab && !sidebarIsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (sidebarIsOpen) {
          scope!.close();
          return;
        }
        shell.goBranch(0);
      },
      child: child,
    );
  }
}
