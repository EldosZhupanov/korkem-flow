import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/navigation/app_shell_scope.dart';
import 'package:korkem_flow/core/navigation/app_sidebar.dart';

/// Top-level chrome: a drawer on a phone, a permanent panel on a wide screen.
///
/// The switch is driven by available width, never by `Platform.isX` — a folded
/// foldable and a tablet in split view are both "narrow" regardless of the
/// platform they run on.
///
/// Each branch keeps its own navigation stack and scroll position, which is why
/// this wraps a [StatefulNavigationShell] rather than swapping child widgets.
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  /// Held so a screen deeper in the tree can open the drawer. Every branch root
  /// builds its own `Scaffold`, so `Scaffold.of` inside one finds that inner
  /// scaffold — which has no drawer — rather than this one.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _drawerOpen = false;

  @override
  Widget build(BuildContext context) {
    // 280 (panel) + 720 (`AppBreakpoints.readable`) = 1000, so `medium` is the
    // first width at which a permanent panel does not squeeze the content
    // column. Below it the panel is a drawer instead of stealing that width.
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: AppNavigation.sidebarWidth,
              child: AppSidebar(
                shell: widget.navigationShell,
                // Nothing to close: the panel is always there.
                onNavigate: () {},
              ),
            ),
            const VerticalDivider(width: AppStroke.hairline),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    return AppShellScope(
      scaffoldKey: _scaffoldKey,
      isOpen: _drawerOpen,
      child: Scaffold(
        key: _scaffoldKey,
        // Flutter's own drawer, not a hand-rolled overlay: the scrim, the focus
        // trap and the open/close animation all come with it, and each is easy
        // to reimplement slightly wrong.
        //
        // Back-to-dismiss does *not* come with it, despite the local history
        // entry `DrawerController` registers. That entry lands on the shell's
        // route in the root navigator, and go_router's `popRoute` hands the
        // gesture to the innermost branch navigator instead — so the root route
        // is never asked. `TabBackHandler`, which sits on a branch route, is
        // what actually closes the panel; [isOpen] is how it finds out.
        drawer: Drawer(
          width: MediaQuery.sizeOf(context).width * _drawerWidthFraction,
          child: AppSidebar(
            shell: widget.navigationShell,
            onNavigate: () => _scaffoldKey.currentState?.closeDrawer(),
          ),
        ),
        onDrawerChanged: (isOpen) => setState(() => _drawerOpen = isOpen),
        body: widget.navigationShell,
      ),
    );
  }
}

/// How much of a phone screen the panel takes. Short of full width on purpose:
/// the sliver of dimmed content still showing is what says "this is a layer
/// over your work" rather than "you have navigated somewhere new".
const double _drawerWidthFraction = 0.86;
