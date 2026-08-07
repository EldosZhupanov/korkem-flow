import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/gallery/design_gallery.dart';
import 'package:korkem_flow/core/navigation/adaptive_shell.dart';
import 'package:korkem_flow/core/navigation/tab_back_handler.dart';
import 'package:korkem_flow/features/ai_settings/presentation/ai_settings_screen.dart';
import 'package:korkem_flow/features/approvals/presentation/approvals_screen.dart';
import 'package:korkem_flow/features/assistant/presentation/chat_screen.dart';
import 'package:korkem_flow/features/auth/presentation/login_screen.dart';
import 'package:korkem_flow/features/auth/presentation/splash_screen.dart';
import 'package:korkem_flow/features/customers/presentation/customer_detail_screen.dart';
import 'package:korkem_flow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:korkem_flow/features/deals/presentation/deal_detail_screen.dart';
import 'package:korkem_flow/features/leads/presentation/lead_detail_screen.dart';
import 'package:korkem_flow/features/notifications/presentation/notifications_screen.dart';
import 'package:korkem_flow/features/operations/presentation/operations_screen.dart';
import 'package:korkem_flow/features/profile/presentation/profile_screen.dart';
import 'package:korkem_flow/features/sales/presentation/sales_screen.dart';
import 'package:korkem_flow/features/settings/presentation/settings_screen.dart';
import 'package:korkem_flow/features/tasks/presentation/tasks_screen.dart';

/// Route paths, referenced by name rather than typed as literals at call sites.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';

  /// The assistant, and where signing in lands.
  static const chat = '/chat';

  static const dashboard = '/dashboard';
  static const approvals = '$dashboard/approvals';
  static const production = '$dashboard/production';
  static const notifications = '$dashboard/notifications';
  static const sales = '/sales';

  /// Detail routes are children of the sales branch, so opening one keeps the
  /// bottom bar and the back stack of the tab it was opened from.
  static String deal(String id) => '$sales/deal/$id';
  static String lead(String id) => '$sales/lead/$id';
  static String customer(String id) => '$sales/customer/$id';

  /// The shared-element tag linking a list row to the screen it opens.
  ///
  /// The route path itself, because a hero tag has to be unique among
  /// everything mounted at once and a route already is: two rows that would
  /// collide would also be the same record. Deriving it here rather than
  /// formatting a string at each call site is what keeps the two ends of a
  /// flight spelled identically — a mismatch does not fail, it just silently
  /// stops animating.
  static String heroTag(String route) => 'title:$route';
  static const tasks = '/tasks';
  static const profile = '/profile';
  static const settings = '/settings';
  static const aiSettings = '/settings/ai';

  /// Sales, opened on its Customers tab. A URL rather than a branch of its own:
  /// Customers *is* a view of the pipeline, and giving it a second branch would
  /// mean two live copies of the same screen in the shell's `IndexedStack`.
  static const clients = '$sales?${SalesTab.queryParameter}=customers';

  /// The component catalogue. Registered only in debug builds — see
  /// [createRouter] — so this path 404s in a release one.
  static const gallery = '/gallery';
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
      //
      // This is why `signIn` must never publish a loading state: redirecting
      // here tears down whichever screen is mounted, and a login screen torn
      // down mid-request loses the error it was about to show.
      if (session.isLoading) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final signedIn = session.value?.isAuthenticated ?? false;
      final atEntry = location == Routes.splash || location == Routes.login;

      if (!signedIn) return atEntry ? Routes.login : Routes.login;
      return atEntry ? Routes.chat : null;
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
        path: Routes.aiSettings,
        builder: (context, state) => const AiSettingsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      // Debug only. `kDebugMode` is a compile-time constant, so the release
      // build drops both this route and everything DesignGallery pulls in.
      if (kDebugMode)
        GoRoute(
          path: Routes.gallery,
          builder: (context, state) => const DesignGallery(),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
        branches: [
          // The assistant is branch 0: it is the home, and `TabBackHandler`'s
          // "back returns to the first branch" now means "back returns to the
          // assistant", which is the behaviour an AI-first app wants anyway.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.chat,
                builder: (context, state) =>
                    const TabBackHandler(child: ChatScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (context, state) =>
                    const TabBackHandler(child: DashboardScreen()),
                // Children, so the bottom bar and the tab's back stack survive
                // — these are reached by tapping the metric they summarise.
                routes: [
                  GoRoute(
                    path: 'approvals',
                    builder: (context, state) => const ApprovalsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: 'production',
                    builder: (context, state) => const OperationsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.sales,
                builder: (context, state) {
                  // Keyed by the requested tab so that asking for Clients while
                  // already on Sales rebuilds the screen — and therefore its
                  // `DefaultTabController` — instead of quietly reusing one
                  // that is already parked on Deals.
                  final tab = SalesTab.fromName(
                    state.uri.queryParameters[SalesTab.queryParameter],
                  );
                  return TabBackHandler(
                    key: ValueKey(tab),
                    child: SalesScreen(tab: tab),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'deal/:id',
                    builder: (context, state) =>
                        DealDetailScreen(id: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'lead/:id',
                    builder: (context, state) =>
                        LeadDetailScreen(id: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'customer/:id',
                    builder: (context, state) =>
                        CustomerDetailScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                builder: (context, state) =>
                    const TabBackHandler(child: TasksScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) =>
                    const TabBackHandler(child: ProfileScreen()),
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
