import 'package:flutter/widgets.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A top-level destination in the shell.
///
/// Kept as data rather than hard-coded widgets so the destination list can be
/// filtered per role without rebuilding the navigation UI. Roles map to the
/// real backend roles (`Sales User`, `Manufacturing User`, …) — see
/// `docs/backend_api_audit.md` §5.
@immutable
class AppDestination {
  const AppDestination({
    required this.path,
    required this.icon,
    required this.labelOf,
  });

  final String path;
  final IconData icon;

  /// Resolved against the active locale at build time, so switching language
  /// does not require rebuilding this list.
  final String Function(AppLocalizations l10n) labelOf;
}

/// The destinations available to the Sales-facing v1.
///
/// Deliberately few: a bottom bar stops being scannable past five, and every
/// remaining screen is reached from one of these.
const appDestinations = <AppDestination>[
  AppDestination(
    path: '/dashboard',
    icon: AppIcons.dashboard,
    labelOf: _dashboardLabel,
  ),
  AppDestination(
    path: '/sales',
    icon: AppIcons.deal,
    labelOf: _dealsLabel,
  ),
  AppDestination(
    path: '/tasks',
    icon: AppIcons.task,
    labelOf: _tasksLabel,
  ),
  AppDestination(
    path: '/profile',
    icon: AppIcons.profile,
    labelOf: _profileLabel,
  ),
];

/// The shell branch index serving [path].
///
/// `StatefulNavigationShell.goBranch` addresses branches by position, and the
/// only place that position exists is the router's `branches` list. That list
/// and this one are parallel by construction — the shell builds its bar from
/// here and its stacks from there, in the same order — so deriving the index
/// keeps a reorder from quietly sending a tap to the wrong tab, which is the
/// failure mode of writing the number out by hand.
int branchIndexOf(String path) {
  final index = appDestinations.indexWhere(
    (destination) => destination.path == path,
  );
  assert(index >= 0, 'No shell branch serves $path');
  return index;
}

String _dashboardLabel(AppLocalizations l10n) => l10n.navDashboard;
String _dealsLabel(AppLocalizations l10n) => l10n.navSales;
String _tasksLabel(AppLocalizations l10n) => l10n.navTasks;
String _profileLabel(AppLocalizations l10n) => l10n.navProfile;
