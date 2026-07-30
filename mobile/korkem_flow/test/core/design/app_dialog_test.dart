import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The confirm dialog guards the irreversible actions, so the interesting
/// cases are all the ways a user does *not* say yes.
void main() {
  /// Holds the dialog's answer so a test can assert on it after the fact.
  /// Starts as null precisely so "the dialog never returned" cannot be
  /// mistaken for "the user declined".
  late List<bool> answers;

  Future<void> open(WidgetTester tester, {bool isDestructive = false}) async {
    answers = [];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => answers.add(
                  await showConfirmDialog(
                    context: context,
                    title: 'Sign out of this device?',
                    message: 'You will need your password to sign back in.',
                    confirmLabel: 'Sign out',
                    isDestructive: isDestructive,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets('confirming returns true', (tester) async {
    await open(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(answers, [true]);
  });

  testWidgets('cancelling returns false', (tester) async {
    await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('dismissing by tapping outside returns false, not null', (
    tester,
  ) async {
    await open(tester);

    // showDialog returns null here. Handing that to a caller invites
    // `if (result ?? true)` and `if (result != false)` — two ways to read
    // "tapped outside the dialog" as consent to destroy something. The helper
    // collapses it to false before anyone can get that wrong.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('a destructive confirm does not look like an ordinary one', (
    tester,
  ) async {
    await open(tester, isDestructive: true);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign out'),
    );

    // Colour is not the only signal — the label says "Sign out" — but a
    // destructive action styled identically to a routine one is the difference
    // between a considered tap and a reflexive one.
    expect(
      button.style?.backgroundColor?.resolve({}),
      AppTheme.light().colorScheme.error,
    );
  });

  testWidgets('an ordinary confirm keeps the default styling', (tester) async {
    await open(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign out'),
    );

    // Otherwise the destructive test above would pass against an
    // implementation that simply painted every confirm red.
    expect(button.style?.backgroundColor, isNull);
  });

  testWidgets('cancel sits left of confirm', (tester) async {
    await open(tester);

    // Fixed here so it cannot drift per screen. A user who has learned where
    // "the safe one" is should not have to re-read a dialog to find it.
    expect(
      tester.getCenter(find.text('Cancel')).dx,
      lessThan(tester.getCenter(find.text('Sign out')).dx),
    );
  });
}
