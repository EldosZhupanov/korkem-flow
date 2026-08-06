import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/navigation/app_destinations.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/navigation/sidebar_entries.dart';

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

  test('every sidebar entry is the kind its route actually is', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final routes = container.read(Provider(createRouter)).configuration.routes;
    final shell = routes.whereType<StatefulShellRoute>().single;
    final branchPaths = {
      for (final branch in shell.branches)
        (branch.routes.single as GoRoute).path,
    };
    final topLevelPaths = {
      for (final route in routes.whereType<GoRoute>()) route.path,
    };

    for (final entry in [...sidebarEntries, ...sidebarFooterEntries]) {
      switch (entry) {
        case SidebarAction():
          break;
        case SidebarBranch(:final path):
          expect(branchPaths, contains(path));
        case SidebarLink(:final path):
          // Inside the shell: `go` reaches it and it has a parent to pop to.
          expect(
            branchPaths.any((branch) => path.startsWith('$branch/')),
            isTrue,
            reason: '$path is not under a branch, so `go` would strand it',
          );
        case SidebarPage(:final path):
          // Outside the shell, and pushed — which is the only reason it has a
          // back arrow. `go` here replaces the stack and leaves a screen with
          // no menu button, no back arrow, and an exit as the next back.
          expect(topLevelPaths, contains(path));
      }
    }
  });

  test('branchIndexOf finds every destination, and rejects a stranger', () {
    for (final (index, destination) in appDestinations.indexed) {
      expect(branchIndexOf(destination.path), index);
    }

    // Asserts in debug, which is where this mistake gets made.
    expect(() => branchIndexOf('/nowhere'), throwsA(isA<AssertionError>()));
  });
}
