import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/navigation/adaptive_shell.dart';
import 'package:korkem_flow/features/deals/presentation/deals_screen.dart';
import 'package:korkem_flow/features/profile/presentation/profile_screen.dart';
import 'package:korkem_flow/features/tasks/presentation/tasks_screen.dart';

/// Route paths, referenced by name rather than typed as literals at call sites.
abstract final class Routes {
  static const deals = '/deals';
  static const tasks = '/tasks';
  static const profile = '/profile';
}

/// The app's router.
///
/// A [StatefulShellRoute] rather than a plain shell so each tab keeps its own
/// navigation stack *and* scroll position across switches — the behaviour users
/// expect from every native app, and the thing a naive IndexedStack loses.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: Routes.deals,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.deals,
                builder: (context, state) => const DealsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
