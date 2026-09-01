import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/mutation_outbox_banner.dart';
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
class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell>
    with WidgetsBindingObserver {
  /// Held so a screen deeper in the tree can open the drawer. Every branch root
  /// builds its own `Scaffold`, so `Scaffold.of` inside one finds that inner
  /// scaffold — which has no drawer — rather than this one.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(
      ref
          .read(mutationOutboxProvider)
          .retryPending(ref.read(frappeClientProvider)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Both dimensions, and the height is not a formality.
    //
    // A tablet at 768 has room for a permanent panel and a conversation column
    // beside it. A phone in landscape is about 870 × 390 — wider than that
    // tablet — and giving it a permanent panel would leave a conversation two
    // hundred points tall behind a keyboard. Width alone cannot tell the two
    // apart; a window shorter than `compact` is a phone on its side.
    final size = MediaQuery.sizeOf(context);
    final isWide =
        size.width >= AppBreakpoints.sidebar &&
        size.height >= AppBreakpoints.compact;

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
            Expanded(child: _content()),
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
        body: _content(),
      ),
    );
  }

  Widget _content() => Column(
    children: [
      const MutationOutboxBanner(),
      Expanded(child: widget.navigationShell),
    ],
  );
}

/// How much of a phone screen the panel takes. Short of full width on purpose:
/// the sliver of dimmed content still showing is what says "this is a layer
/// over your work" rather than "you have navigated somewhere new".
const double _drawerWidthFraction = 0.86;
