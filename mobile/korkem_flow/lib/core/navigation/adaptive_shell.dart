import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/navigation/app_destinations.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Top-level chrome: a bottom bar on phones, a rail on wider screens.
///
/// The switch is driven by available width, never by `Platform.isX` — a
/// folded foldable and a tablet in split view are both "narrow" regardless of
/// the platform they run on.
///
/// Each branch keeps its own navigation stack and scroll position, which is why
/// this wraps a [StatefulNavigationShell] rather than swapping child widgets.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // initialLocation: tapping the active tab pops it back to its root, which
    // is the behaviour every user already expects from iOS and Android.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;

    return _shell(context, l10n: l10n, isWide: isWide);
  }

  Widget _shell(
    BuildContext context, {
    required AppLocalizations l10n,
    required bool isWide,
  }) {
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in appDestinations)
                  NavigationRailDestination(
                    icon: AppIcon(destination.icon),
                    selectedIcon: AppIcon(destination.icon, filled: true),
                    label: Text(destination.labelOf(l10n)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (final destination in appDestinations)
            NavigationDestination(
              // Selection is expressed through the variable `fill` axis of one
              // icon family rather than by swapping glyphs, so it can animate.
              icon: AppIcon(destination.icon),
              selectedIcon: AppIcon(destination.icon, filled: true),
              label: destination.labelOf(l10n),
            ),
        ],
      ),
    );
  }
}
