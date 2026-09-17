import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/auth/auth_repository.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/features/auth/presentation/join_invite_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Future<Map<String, dynamic>> getInvitationInfo({
    required String baseUrl,
    required String token,
  }) async {
    return {
      'valid': true,
      'company_name': 'Престиж Мебель',
      'role_title_ru': 'Оператор раскроя',
      'desc_ru': 'Раскрой плитных материалов на форматно-раскроечном станке',
      'invited_by': 'Аслан Ахметов',
      'phone': '+77011112233',
    };
  }
}

void main() {
  testWidgets('JoinInviteScreen loads and displays workshop context', (tester) async {
    final fakeRepo = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: JoinInviteScreen(token: 'valid_test_token_123'),
        ),
      ),
    );

    // Initial loading
    await tester.pump();
    // After future completes
    await tester.pumpAndSettle();

    // Verify context card rendered
    expect(find.text('Престиж Мебель'), findsOneWidget);
    expect(find.text('Оператор раскроя'), findsOneWidget);
    expect(find.text('Вас пригласил Аслан Ахметов'), findsOneWidget);
    expect(find.text('ПМ'), findsOneWidget); // Cyrillic Initials avatar for Престиж Мебель
    expect(find.text('Получить код по SMS'), findsOneWidget);
  });
}
