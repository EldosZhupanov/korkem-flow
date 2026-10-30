import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/dashboard/application/dashboard_controller.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

/// The link that has to survive: session changes → client rebuilds → every
/// screen refetches.
///
/// Regression. Controllers used to `ref.read` their repository, which snapshots
/// it once. The repository depends on the authenticated client, so after a
/// sign-out and a sign-in as somebody else the screens kept serving the first
/// user's rows — stale data, and data the second user may have no right to see.
/// Only a rebuild of the *controller* refetches, and only `watch` causes one.
void main() {
  /// A fresh client per build, as happens in the app: `dioProvider` watches the
  /// session and constructs a new `Dio` when it changes. Returning the *same*
  /// instance would prove nothing — Riverpod suppresses the notification when a
  /// provider rebuilds to an identical value, so the test would pass on a
  /// `ref.read` too.
  _MockClient clientReturning(String user, int openDeals) {
    final client = _MockClient();
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: any(named: 'post'),
      ),
    ).thenAnswer(
      (_) async => {
        'message': {
          'user': user,
          'metrics': {'open_deals': openDeals},
          'attention': <dynamic>[],
        },
      },
    );
    return client;
  }

  test('refetches when the authenticated client is replaced', () async {
    final clients = [
      clientReturning('rep@korkem.kz', 0),
      clientReturning('manager@korkem.kz', 266),
    ];
    var built = 0;

    final container = ProviderContainer(
      overrides: [
        frappeClientProvider.overrideWith((ref) => clients[built++]),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    // An active listener, because an unobserved provider has no reason to
    // rebuild when its dependency is invalidated — and the rebuild is the
    // subject here. On a real screen the widget is the listener.
    container.listen(dashboardControllerProvider, (_, _) {});

    final first = await container.read(dashboardControllerProvider.future);
    expect(first.user, 'rep@korkem.kz');
    expect(first[DashboardSummary.openDeals], 0);

    // Stands in for signing in as somebody else: the session changes, so
    // dioProvider and frappeClientProvider rebuild beneath the repository.
    container.invalidate(frappeClientProvider);

    final second = await container.read(dashboardControllerProvider.future);
    expect(second.user, 'manager@korkem.kz');
    expect(second[DashboardSummary.openDeals], 266);
    verify(
      () => clients[1].callMethod(
        any(),
        params: any(named: 'params'),
        post: any(named: 'post'),
      ),
    ).called(1);
  });
}
