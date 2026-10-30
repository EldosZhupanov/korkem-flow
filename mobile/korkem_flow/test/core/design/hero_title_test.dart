import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/motion/hero_title.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';

/// The shared-element flight from a list row to its detail screen.
///
/// Pinned because every way this breaks is silent. A tag spelled differently at
/// the two ends does not throw — the title simply stops flying, and the only
/// symptom is an animation nobody notices the absence of. Interpolating the
/// wrong way round on a pop looks identical on a push. And a *duplicate* tag
/// does the opposite: it throws, at the moment a user taps a row.
void main() {
  const listStyle = TextStyle(fontSize: 16);
  const detailStyle = TextStyle(fontSize: 28);
  const midpoint = 22.0;

  /// Early enough in the transition that the shuttle is still clearly nearer
  /// the end it started from. Sampling at the halfway mark would put it on the
  /// midpoint, where a forwards and a backwards interpolation agree.
  const earlyInFlight = Duration(milliseconds: 60);

  Widget app(GlobalKey<NavigatorState> navigator) => MaterialApp(
    theme: AppTheme.light(),
    navigatorKey: navigator,
    home: const Scaffold(
      body: Center(
        child: HeroTitle(
          tag: 'title:/sales/deal/D1',
          text: 'Chi Systems',
          style: listStyle,
          maxLines: 2,
        ),
      ),
    ),
  );

  Route<void> detailRoute() => MaterialPageRoute<void>(
    builder: (_) => const Scaffold(
      body: HeroTitle(
        tag: 'title:/sales/deal/D1',
        text: 'Chi Systems',
        style: detailStyle,
      ),
    ),
  );

  /// The text being painted in the flight overlay, if a flight is in progress.
  ///
  /// Mid-flight there are three matching widgets — the two route copies are
  /// hidden and a shuttle is added to the overlay — so counting is how the
  /// flight is detected at all.
  Iterable<double> fontSizes(WidgetTester tester) => tester
      .widgetList<Text>(find.text('Chi Systems'))
      .map((text) => text.style?.fontSize ?? 0);

  /// The one size that is neither end — the shuttle in the overlay.
  double shuttleSize(WidgetTester tester) {
    final flying =
        fontSizes(
          tester,
        ).where(
          (size) => size != listStyle.fontSize && size != detailStyle.fontSize,
        );
    expect(
      flying,
      hasLength(1),
      reason:
          'expected exactly one shuttle in the '
          'overlay; sizes were ${fontSizes(tester).toList()}',
    );
    return flying.single;
  }

  testWidgets('the title flies, growing into the header size', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigator));
    await tester.pumpAndSettle();

    expect(fontSizes(tester), [listStyle.fontSize]);

    unawaited(navigator.currentState!.push(detailRoute()));
    await tester.pump();
    await tester.pump(earlyInFlight);

    // Sampled *early*, and asserted to still be near the list size. Merely
    // checking that the shuttle sits somewhere between the two ends passes
    // just as happily when the interpolation runs backwards, because a
    // mirrored value is also "between".
    expect(shuttleSize(tester), lessThan(midpoint));

    await tester.pumpAndSettle();
    expect(fontSizes(tester), [detailStyle.fontSize]);
  });

  testWidgets('and shrinks back on the way out', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigator));
    await tester.pumpAndSettle();

    unawaited(navigator.currentState!.push(detailRoute()));
    await tester.pumpAndSettle();

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(earlyInFlight);

    // A pop starts at the detail size, so early in the flight the shuttle must
    // still be large. This is the assertion the whole file exists for: on a
    // pop the route animation counts *down* while `from` and `to` swap, and
    // getting that wrong produces a title that starts small and grows while
    // the screen it belongs to is leaving — backwards, and both ends still
    // land correctly, so nothing else catches it.
    expect(shuttleSize(tester), greaterThan(midpoint));

    await tester.pumpAndSettle();
    expect(fontSizes(tester), [listStyle.fontSize]);
  });
}
