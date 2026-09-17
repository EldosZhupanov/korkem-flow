import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/auth/presentation/join_invite_screen.dart';
import 'package:korkem_flow/features/auth/presentation/register_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

void main() {
  testWidgets('register screen renders two onboarding paths', (tester) async {
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

    // Verify SegmentedButton has both paths
    expect(find.text('Создать компанию'), findsOneWidget);
    expect(find.text('По приглашению'), findsOneWidget);

    // Verify Phone field in Step 1
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Получить код по SMS'), findsOneWidget);

    // Switch to Join by Invite
    await tester.tap(find.text('По приглашению'));
    await tester.pumpAndSettle();

    expect(find.text('Присоединиться к цеху'), findsOneWidget);
    expect(find.text('Перейти к приглашению'), findsOneWidget);
  });
}
