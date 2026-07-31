import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';

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
    this.actions = const [],
    super.key,
  }) : tabs = const [];

  /// Peer views of one subject, under a single title.
  ///
  /// Tabs are for *views of the same thing* — Deals and Leads are both the
  /// pipeline — never for unrelated destinations, which belong in the
  /// navigation bar.
  const AppScreen.tabbed({
    required this.title,
    required this.tabs,
    this.actions = const [],
    super.key,
  }) : body = null;

  final String title;
  final Widget? body;
  final List<Widget> actions;
  final List<AppTab> tabs;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: ReadableWidth(child: body ?? const SizedBox.shrink()),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
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
            for (final tab in tabs) ReadableWidth(child: tab.view),
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
