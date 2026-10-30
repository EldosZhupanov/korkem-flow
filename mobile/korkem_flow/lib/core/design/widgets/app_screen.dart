import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/navigation/app_shell_scope.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The chrome every non-detail screen wears: a bar, a title, and a body.
///
/// Nine screens each built this themselves, and they had drifted — most
/// visibly in their tab bars, where Sales scrolled and start-aligned its four
/// tabs while Operations centred and squeezed its two. Both were locally
/// reasonable and together they were two different products.
///
/// ## Why the title is small
///
/// `docs/design_system.md` once specified a large title collapsing on scroll,
/// the Linear/Notion shape, and the app never had one. Keeping the small bar
/// is a decision rather than an omission: a large title spends around 52dp of
/// permanent vertical space, and every screen here exists to show as many rows
/// as possible to someone holding a phone on a factory floor. That trade is
/// right for an app opened twice a week and wrong for one opened forty times a
/// shift.
///
/// It is written here, once, so the next person changing it changes it
/// everywhere and has to read this first.
///
/// Detail screens use `DetailScaffold` instead — same bar, but it also owns the
/// loading, error and empty states a single record needs.
class AppScreen extends StatelessWidget {
  const AppScreen({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.fullWidth = false,
    super.key,
  }) : tabs = const [],
       initialTab = 0;

  /// Peer views of one subject, under a single title.
  ///
  /// Tabs are for *views of the same thing* — Deals and Leads are both the
  /// pipeline — never for unrelated destinations, which belong in the
  /// navigation bar.
  const AppScreen.tabbed({
    required this.title,
    required this.tabs,
    this.actions = const [],
    this.initialTab = 0,
    this.fullWidth = false,
    super.key,
  }) : body = null,
       subtitle = null;

  final String title;

  /// A quiet second line under the title, for a screen that has to say what
  /// state it is in — the assistant declaring that it is running locally, with
  /// no language model behind it.
  final String? subtitle;

  final Widget? body;
  final List<Widget> actions;
  final List<AppTab> tabs;
  final bool fullWidth;

  /// Which tab opens first. Only meaningful for [AppScreen.tabbed], and only
  /// honoured when the screen is *built*: sending someone to a different tab of
  /// a screen they are already on means giving that screen a new key, not
  /// changing this value under a live `TabController`.
  final int initialTab;

  /// The title block, with the subtitle folded in when there is one.
  Widget _title(BuildContext context) {
    final line = subtitle;
    if (line == null) return Text(title);

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          line,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      final content = body ?? const SizedBox.shrink();
      return Scaffold(
        appBar: AppBar(
          leading: _SidebarButton.maybe(context),
          title: _title(context),
          actions: actions,
        ),
        body: fullWidth ? content : ReadableWidth(child: content),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTab.clamp(0, tabs.length - 1),
      child: Scaffold(
        appBar: AppBar(
          leading: _SidebarButton.maybe(context),
          title: _title(context),
          actions: actions,
          bottom: TabBar(
            // Scrollable and start-aligned always, not only where someone
            // noticed it was needed. Four Russian labels do not fit a phone
            // width evenly and squeezing them truncates every one; two labels
            // fit comfortably and look no worse left-aligned. Deciding per
            // screen is how one tab bar ends up centred and another does not.
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in tabs) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs)
              fullWidth ? tab.view : ReadableWidth(child: tab.view),
          ],
        ),
      ),
    );
  }
}

/// One tab: what it is called, and what it shows.
@immutable
class AppTab {
  const AppTab({required this.label, required this.view});

  final String label;
  final Widget view;
}

/// Opens the navigation panel, on the screens that should offer to.
///
/// Returns null — leaving `AppBar` to its default — in the two cases where a
/// menu button would be wrong: on a pushed screen, where the back arrow is what
/// the user needs, and on a wide layout, where the panel is already visible and
/// there is nothing to open.
class _SidebarButton extends StatelessWidget {
  const _SidebarButton();

  static Widget? maybe(BuildContext context) {
    final scope = AppShellScope.maybeOf(context);
    if (scope == null) return null;
    if (ModalRoute.of(context)?.canPop ?? false) return null;
    return const _SidebarButton();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(AppIcons.menu),
      tooltip: AppLocalizations.of(context).navMenu,
      onPressed: () => AppShellScope.maybeOf(context)?.open(),
    );
  }
}
