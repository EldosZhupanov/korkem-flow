import 'package:flutter/widgets.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One row in the sidebar.
///
/// Deliberately a different list from `appDestinations`. That list is the
/// router's *branches* — the places that keep their own navigation stack and
/// scroll position — and it has to stay exactly parallel to the router, which
/// `branch_index_test.dart` enforces. The sidebar is a superset: it also
/// reaches Production, which lives inside the dashboard branch, and Settings,
/// which sits outside the shell entirely.
///
/// Conflating the two would either force every sidebar row to become a branch
/// (five extra `IndexedStack` children kept alive for screens visited once a
/// week) or force the branch list to grow rows the router has no route for.
sealed class SidebarEntry {
  const SidebarEntry({required this.icon, required this.labelOf});

  final IconData icon;

  /// Resolved against the active locale at build time, so switching language
  /// does not require rebuilding this list.
  final String Function(AppLocalizations l10n) labelOf;
}

/// A router branch. Selecting it restores that section exactly as it was left,
/// which is the whole reason the shell is an `IndexedStack`.
class SidebarBranch extends SidebarEntry {
  const SidebarBranch({
    required this.path,
    required super.icon,
    required super.labelOf,
  });

  final String path;
}

/// A route *inside* the shell that is not a branch root — a child of a branch,
/// like Production under the dashboard. `context.go` sets the owning branch and
/// that branch's stack in a single move, so this needs no branch of its own,
/// and the screen arrives with a working back arrow because it has a parent to
/// pop to.
class SidebarLink extends SidebarEntry {
  const SidebarLink({
    required this.path,
    required super.icon,
    required super.labelOf,
  });

  final String path;
}

/// A route *outside* the shell — Settings is the only one.
///
/// This is pushed, not `go`-ne to, and the distinction is not academic:
/// `context.go` to a top-level route replaces the whole stack, so the screen
/// arrives with no shell around it (hence no menu button) and nothing beneath
/// it (hence no back arrow), and the next system back leaves the app. Settings
/// became exactly that dead end before this existed.
class SidebarPage extends SidebarEntry {
  const SidebarPage({
    required this.path,
    required super.icon,
    required super.labelOf,
  });

  final String path;
}

/// Does something rather than going somewhere. Starting a new conversation is
/// the only one today.
class SidebarAction extends SidebarEntry {
  const SidebarAction({required super.icon, required super.labelOf});
}

/// The sidebar, top to bottom.
///
/// Order is meaning: the assistant first because it is the product, the ERP
/// sections under it as the tools it reaches, and the account at the bottom
/// where every application has taught people to look for it.
const sidebarEntries = <SidebarEntry>[
  SidebarAction(icon: AppIcons.add, labelOf: _newChat),
  SidebarBranch(
    path: Routes.chat,
    icon: AppIcons.conversation,
    labelOf: _assistant,
  ),
  SidebarBranch(
    path: Routes.dashboard,
    icon: AppIcons.dashboard,
    labelOf: _home,
  ),
  SidebarBranch(path: Routes.sales, icon: AppIcons.deal, labelOf: _sales),
  SidebarBranch(path: Routes.tasks, icon: AppIcons.task, labelOf: _tasks),
  SidebarLink(
    path: Routes.production,
    icon: AppIcons.workOrder,
    labelOf: _production,
  ),
];

/// Shown apart from the sections above, after the recent conversations.
const sidebarFooterEntries = <SidebarEntry>[
  SidebarBranch(
    path: Routes.profile,
    icon: AppIcons.profile,
    labelOf: _profile,
  ),
  SidebarPage(
    path: Routes.settings,
    icon: AppIcons.settings,
    labelOf: _settings,
  ),
];

String _newChat(AppLocalizations l10n) => l10n.chatNew;
String _assistant(AppLocalizations l10n) => l10n.navAssistant;
String _home(AppLocalizations l10n) => l10n.navDashboard;
String _sales(AppLocalizations l10n) => l10n.navSales;
String _tasks(AppLocalizations l10n) => l10n.navTasks;
String _production(AppLocalizations l10n) => l10n.navOperations;
String _profile(AppLocalizations l10n) => l10n.navProfile;
String _settings(AppLocalizations l10n) => l10n.settingsTitle;
