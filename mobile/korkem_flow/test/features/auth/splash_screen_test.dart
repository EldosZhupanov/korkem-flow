import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/features/auth/presentation/splash_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The splash withholds its progress indicator on purpose.
///
/// A warm start leaves this screen in a frame or two. A spinner that appears
/// and vanishes inside 200ms reads as a glitch, so it is held back until the
/// wait is long enough to be worth explaining. That delay is a deliberate
/// design decision and nothing else in the widget signals it — without a test
/// the next person to touch this file will "fix" the missing spinner.
void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    ),
  );

  testWidgets('a fast restore never shows a progress indicator', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(_indicatorOpacity(tester), 0, reason: 'still invisible at 200ms');

    // The brand, meanwhile, is already there — the screen is not blank while
    // it waits. Both layers: the ornament, and the wordmark under it.
    expect(find.byType(AppLogo), findsNWidgets(2));
  });

  testWidgets('the splash is the brand field, whatever the system theme is', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        // Light theme, deliberately: the splash must not follow it.
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SplashScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // A logo drawn on its own ground is the point of having one. Letting this
    // screen turn cream in light mode would put a cream mark on cream.
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((box) => box.color),
      contains(AppColors.forest),
    );
  });

  testWidgets('a slow restore eventually explains itself', (tester) async {
    await pump(tester);

    // Pumped in steps rather than one long jump: the reveal is a delay
    // followed by a fade, and a single frame that skips both leaves the
    // controller mid-flight.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(_indicatorOpacity(tester), 1);
  });
}

/// How visible the progress track is right now.
double _indicatorOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(LinearProgressIndicator),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;
