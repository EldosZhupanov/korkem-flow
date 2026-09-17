import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/auth/presentation/register_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

void main() {
  testWidgets('register screen renders required fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify company, owner name, email, password fields are present
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
