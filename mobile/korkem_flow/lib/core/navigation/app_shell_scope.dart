import 'package:flutter/material.dart';

/// Lets a screen open the sidebar that is holding it.
///
/// The shell owns one `Scaffold` with the drawer on it, but every branch root
/// builds its *own* `Scaffold` through `AppScreen`. So `Scaffold.of` inside a
/// screen finds the inner one, which has no drawer, and the menu button would
/// have nothing to open. This carries the outer scaffold's key down past that.
///
/// Absent on wide layouts, where the sidebar is permanent and there is nothing
/// to open — which is exactly how `AppScreen` decides whether to draw a menu
/// button at all.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    required this.scaffoldKey,
    required super.child,
    super.key,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;

  /// Null when there is no drawer to open: on a wide layout, or in a test that
  /// pumps a screen on its own.
  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  void open() => scaffoldKey.currentState?.openDrawer();

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}
