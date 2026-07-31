import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/motion/app_busy_indicator.dart';

import '../../support/widget_harness.dart';

/// The busy indicator replaced the app's last two spinners.
///
/// What matters is not that it spins differently — it is that it stays legible
/// on whatever it is drawn on, and that it can be switched off.
void main() {
  Iterable<double> opacities(WidgetTester tester) =>
      tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);

  testWidgets('three dots, and they do not all pulse together', (tester) async {
    await tester.pumpWidget(harness(const AppBusyIndicator()));
    await tester.pump(const Duration(milliseconds: 350));

    expect(opacities(tester), hasLength(3));

    // Staggered. Three dots pulsing in unison is a blinking blob, not motion.
    expect(opacities(tester).toSet(), hasLength(greaterThan(1)));
  });

  testWidgets('no dot ever goes out entirely', (tester) async {
    await tester.pumpWidget(harness(const AppBusyIndicator()));

    // Sampled across a full cycle. A dot that reaches zero reads as a fault —
    // something missing — rather than as progress.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 175));
      expect(opacities(tester), everyElement(greaterThan(0.0)));
    }
  });

  testWidgets('reduced motion holds the dots still and fully lit', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const AppBusyIndicator(), disableAnimations: true),
    );
    await tester.pump(const Duration(milliseconds: 350));

    // Still visible, still says "working" — an animation that cannot be turned
    // off is an accessibility defect, but turning it off must not turn the
    // control into nothing.
    expect(opacities(tester), everyElement(1.0));
  });

  testWidgets('it takes the colour of the text it replaced', (tester) async {
    await tester.pumpWidget(
      harness(
        const DefaultTextStyle(
          style: TextStyle(color: Color(0xFF123456)),
          child: AppBusyIndicator(),
        ),
      ),
    );

    // Material's own indicator paints itself from the theme's primary, which
    // inside a filled button is the *page's* accent on the button's fill —
    // cream on cream in the dark theme. Inheriting the label's colour is the
    // whole reason this is legible in a button at all.
    final box = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .first;
    expect(
      (box.decoration as BoxDecoration).color,
      const Color(0xFF123456),
    );
  });
}
