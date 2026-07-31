import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/motion/animated_counter.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';

/// The counter's rules are all about what it must *not* claim.
///
/// A number rolling up is decoration until it starts lying. Counting a refresh
/// from zero says the figure was zero a moment ago; counting a withheld figure
/// says it was zero at all. On an overdue-task tile either one is alarming, and
/// neither is visible in a screenshot — only in the half-second nobody is
/// looking at when they change the code.
void main() {
  Future<void> pump(
    WidgetTester tester,
    int? value, {
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: AnimatedCounter(value: value, placeholder: '—'),
        ),
      ),
    ),
  );

  String shown(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).data!;

  testWidgets('counts up from zero the first time, and lands on the value', (
    tester,
  ) async {
    await pump(tester, 40);

    await tester.pump(const Duration(milliseconds: 16));
    final early = int.parse(shown(tester));
    expect(early, lessThan(40), reason: 'should still be climbing');

    await tester.pumpAndSettle();
    expect(shown(tester), '40');
  });

  testWidgets('a changed value resumes from the old one, not from zero', (
    tester,
  ) async {
    await pump(tester, 40);
    await tester.pumpAndSettle();

    await pump(tester, 42);
    await tester.pump(const Duration(milliseconds: 16));

    // The whole point. Restarting at zero would flash "1, 7, 19…" past a user
    // whose overdue count went from 40 to 42, and read as the number having
    // collapsed and recovered.
    expect(int.parse(shown(tester)), greaterThanOrEqualTo(40));

    await tester.pumpAndSettle();
    expect(shown(tester), '42');
  });

  testWidgets('a withheld number is a dash and never animates', (tester) async {
    await pump(tester, null);
    await tester.pump(const Duration(milliseconds: 16));

    // Null means the signed-in role may not see this figure. Counting to zero
    // would assert something the user has no standing to know.
    expect(shown(tester), '—');
    await tester.pumpAndSettle();
    expect(shown(tester), '—');
  });

  testWidgets('reduced motion shows the number outright', (tester) async {
    await pump(tester, 40, reduceMotion: true);

    // One frame, no tween: an animation that cannot be switched off is an
    // accessibility defect, and a rolling number is exactly the kind of motion
    // the setting exists for.
    await tester.pump();
    expect(shown(tester), '40');
  });
}
