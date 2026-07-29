import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/navigation/app_destinations.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';

/// `goBranch` takes a position, and the only place that position exists is the
/// router's `branches` list. Nothing in the type system ties that list to
/// `appDestinations`, which is what the bottom bar and `branchIndexOf` are
/// built from — the two are parallel purely by convention.
///
/// Break the convention and nothing fails to compile, no test that exercises a
/// screen notices, and the app simply opens the wrong tab. This is the test
/// that notices.
void main() {
  test('router branches are in the same order as appDestinations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final shell = container
        .read(Provider(createRouter))
        .configuration
        .routes
        .whereType<StatefulShellRoute>()
        .single;

    final branchPaths = [
      for (final branch in shell.branches)
        (branch.routes.single as GoRoute).path,
    ];

    expect(branchPaths, appDestinations.map((d) => d.path).toList());
  });

  test('branchIndexOf finds every destination, and rejects a stranger', () {
    for (final (index, destination) in appDestinations.indexed) {
      expect(branchIndexOf(destination.path), index);
    }

    // Asserts in debug, which is where this mistake gets made.
    expect(() => branchIndexOf('/nowhere'), throwsA(isA<AssertionError>()));
  });
}
