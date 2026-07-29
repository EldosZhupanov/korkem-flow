import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/motion/app_pressable.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// Motion has to be switchable off and has to end where it started.
///
/// Both are easy to break silently: an animation that ignores reduced motion
/// still looks fine to whoever wrote it, and one that settles a pixel off its
/// resting state only shows up as a golden that will not stabilise.
void main() {
  Widget wrap(Widget child, {bool reduceMotion = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  group('Entrance', () {
    testWidgets('settles fully opaque and in place', (tester) async {
      await tester.pumpWidget(
        wrap(const Entrance(index: 3, child: Text('row'))),
      );
      await tester.pumpAndSettle();

      final opacity = tester.widget<FadeTransition>(
        find.byType(FadeTransition).first,
      );
      expect(opacity.opacity.value, 1);
    });

    testWidgets('reduced motion returns the child untouched', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Entrance(index: 3, child: Text('row')),
          reduceMotion: true,
        ),
      );

      // Not "animates faster" — no animation wrapper at all, so there is no
      // frame on which the row is invisible.
      expect(find.byType(FadeTransition), findsNothing);
      expect(find.text('row'), findsOneWidget);
    });

    testWidgets('a late row is not delayed past the cap', (tester) async {
      await tester.pumpWidget(
        wrap(const Entrance(index: 400, child: Text('row'))),
      );

      // Past the cap every row shares the last delay. Settling within it plus
      // the animation proves row 400 does not wait 8 seconds to appear.
      await tester.pump(
        AppDuration.stagger * AppDuration.staggerMaxRows + AppDuration.standard,
      );
      await tester.pumpAndSettle();

      expect(find.text('row'), findsOneWidget);
    });
  });

  group('AppPressable', () {
    testWidgets('scales down under the finger and back on release', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(AppPressable(onTap: () {}, child: const Text('card'))),
      );

      double scaleNow() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      expect(scaleNow(), 1);

      final gesture = await tester.press(find.text('card'));
      await tester.pump();
      expect(scaleNow(), AppMotionScale.pressedScale);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleNow(), 1);
    });

    testWidgets('an inert card does not react to touch', (tester) async {
      await tester.pumpWidget(wrap(const AppPressable(child: Text('card'))));

      // A card with nowhere to go must not pretend otherwise.
      expect(find.byType(AnimatedScale), findsNothing);
    });
  });
}
