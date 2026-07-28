import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/navigation/adaptive_shell.dart';
import 'package:korkem_flow/features/auth/presentation/login_screen.dart';
import 'package:korkem_flow/features/auth/presentation/splash_screen.dart';
import 'package:korkem_flow/features/deals/presentation/deals_screen.dart';
import 'package:korkem_flow/features/profile/presentation/profile_screen.dart';
import 'package:korkem_flow/features/settings/presentation/settings_screen.dart';
import 'package:korkem_flow/features/tasks/presentation/tasks_screen.dart';

/// Route paths, referenced by name rather than typed as literals at call sites.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const deals = '/deals';
  static const tasks = '/tasks';
  static const profile = '/profile';
  static const settings = '/settings';
}

/// The app's router.
///
/// A [StatefulShellRoute] rather than a plain shell so each tab keeps its own
/// navigation stack *and* scroll position across switches — the behaviour users
/// expect from every native app, and the thing a naive IndexedStack loses.
GoRouter createRouter(Ref ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    // Rebuilds the redirect whenever the session settles, signs in or expires.
    // Without this the router would evaluate auth exactly once, at startup.
    refreshListenable: _SessionListenable(ref),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;

      // Still restoring the stored credential: hold on the splash rather than
      // flashing the login screen at a user who is in fact signed in.
      if (session.isLoading) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final signedIn = session.value?.isAuthenticated ?? false;
      final atEntry = location == Routes.splash || location == Routes.login;

      if (!signedIn) return atEntry ? Routes.login : Routes.login;
      return atEntry ? Routes.deals : null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
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

/// Bridges Riverpod's session state to GoRouter's [Listenable] refresh hook.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    _subscription = ref.listen(
      sessionProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
