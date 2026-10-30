import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/auth/presentation/login_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The reveal toggle has to say which way it goes.
///
/// It is the one control on the sign-in form that changes what is on screen,
/// and unlabelled it is announced as "button" — so the control a screen-reader
/// user most needs to find is the one they cannot identify. The label also has
/// to *flip*: a toggle stuck on "show password" while the password is already
/// showing is worse than no label, because it is wrong rather than missing.
void main() {
  testWidgets('the reveal toggle is labelled, and the label flips', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip != null,
    );

    expect(tester.widget<IconButton>(toggle).tooltip, 'Show password');

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(toggle).tooltip, 'Hide password');
  });
}
