import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/auth_repository.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/provisioning/data/provisioning_repository.dart';
import 'package:korkem_flow/features/provisioning/domain/provisioning_models.dart';
import 'package:korkem_flow/features/provisioning/presentation/claim_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeProvisioningRepository extends ProvisioningRepository {
  _FakeProvisioningRepository({
    this.claimException,
  }) : super(Dio());

  final Exception? claimException;

  ClaimPayload? lastClaimPayload;

  @override
  Future<ProvisioningStatus> checkStatus(String baseUrl) async =>
      const ProvisioningStatus(
        claimed: false,
        languages: ['ru', 'kk', 'en'],
      );

  @override
  Future<ClaimResult> claim({
    required String baseUrl,
    required String code,
    required String company,
    required String ownerEmail,
    required String ownerName,
    required String ownerPassword,
    String country = 'Kazakhstan',
    String currency = 'KZT',
    String timezone = 'Asia/Almaty',
    String language = 'ru',
  }) async {
    lastClaimPayload = ClaimPayload(
      baseUrl: baseUrl,
      code: code,
      company: company,
      ownerEmail: ownerEmail,
      ownerName: ownerName,
      ownerPassword: ownerPassword,
      language: language,
    );

    if (claimException != null) {
      throw claimException!;
    }

    return ClaimResult(
      status: 'claimed',
      company: company,
      owner: ownerEmail,
      roles: const ['System Manager', 'Korkem Owner'],
    );
  }
}

class ClaimPayload {
  ClaimPayload({
    required this.baseUrl,
    required this.code,
    required this.company,
    required this.ownerEmail,
    required this.ownerName,
    required this.ownerPassword,
    required this.language,
  });

  final String baseUrl;
  final String code;
  final String company;
  final String ownerEmail;
  final String ownerName;
  final String ownerPassword;
  final String language;
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio());

  String? signedInUser;
  String? signedInPassword;

  @override
  Future<AuthCredentials> signIn({
    required String baseUrl,
    required String user,
    required String password,
  }) async {
    signedInUser = user;
    signedInPassword = password;
    return SessionCredentials(user: user, sid: 'mock-sid');
  }

  @override
  Future<String> verify({
    required String baseUrl,
    required AuthCredentials credentials,
  }) async => credentials.user;
}

class _MemoryStore implements CredentialStore {
  String? _server;
  AuthCredentials? _credentials;

  @override
  Future<void> clear() async {
    _credentials = null;
  }

  @override
  Future<AuthCredentials?> read() async => _credentials;

  @override
  Future<String?> readServerUrl() async => _server;

  @override
  Future<void> write(AuthCredentials credentials) async {
    _credentials = credentials;
  }

  @override
  Future<void> writeServerUrl(String url) async {
    _server = url;
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required ProvisioningRepository provisioningRepo,
    AuthRepository? authRepo,
    String serverUrl = 'https://korkem.example.kz',
    Locale locale = const Locale('ru'),
  }) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        provisioningRepositoryProvider.overrideWithValue(provisioningRepo),
        credentialStoreProvider.overrideWithValue(_MemoryStore()),
        if (authRepo != null)
          authRepositoryProvider.overrideWithValue(authRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClaimScreen(serverUrl: serverUrl),
      ),
    );
  }

  testWidgets('renders all fields and language selectors', (tester) async {
    final repo = _FakeProvisioningRepository();
    await tester.pumpWidget(buildHarness(tester, provisioningRepo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Первый запуск'), findsOneWidget);
    expect(find.text('Код первого запуска'), findsOneWidget);
    expect(find.text('Название компании'), findsOneWidget);
    expect(find.text('Имя владельца'), findsOneWidget);
    expect(find.text('Электронная почта владельца'), findsOneWidget);
    expect(find.text('Пароль владельца'), findsOneWidget);
    expect(find.text('Подтверждение пароля'), findsOneWidget);
    expect(find.text('Создать компанию'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Қазақша'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('validates required fields', (tester) async {
    final repo = _FakeProvisioningRepository();
    await tester.pumpWidget(buildHarness(tester, provisioningRepo: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Создать компанию'));
    await tester.tap(find.text('Создать компанию'));
    await tester.pumpAndSettle();

    expect(find.text('Обязательное поле'), findsWidgets);
    expect(repo.lastClaimPayload, isNull);
  });

  testWidgets('validates password confirmation match', (tester) async {
    final repo = _FakeProvisioningRepository();
    await tester.pumpWidget(buildHarness(tester, provisioningRepo: repo));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);

    // Code
    await tester.enterText(textFields.at(1), 'ABCD1234EFGH5678');
    // Company
    await tester.enterText(textFields.at(2), 'Korkem Mebel');
    // Owner name
    await tester.enterText(textFields.at(3), 'Aidos');
    // Owner email
    await tester.enterText(textFields.at(4), 'aidos@korkem.kz');
    // Password
    await tester.enterText(textFields.at(5), 'SecretPassword123');
    // Confirm password (mismatched)
    await tester.enterText(textFields.at(6), 'DifferentPassword456');

    await tester.ensureVisible(find.text('Создать компанию'));
    await tester.tap(find.text('Создать компанию'));
    await tester.pumpAndSettle();

    expect(find.text('Пароли не совпадают'), findsOneWidget);
    expect(repo.lastClaimPayload, isNull);
  });

  testWidgets('submits claim and immediately signs in owner on success', (
    tester,
  ) async {
    final provisioningRepo = _FakeProvisioningRepository();
    final authRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      buildHarness(
        tester,
        provisioningRepo: provisioningRepo,
        authRepo: authRepo,
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);

    await tester.enterText(textFields.at(1), 'ABCD 1234 EFGH 5678');
    await tester.enterText(textFields.at(2), 'Korkem Mebel');
    await tester.enterText(textFields.at(3), 'Aidos Owner');
    await tester.enterText(textFields.at(4), 'aidos@korkem.kz');
    await tester.enterText(textFields.at(5), 'MySecret123!');
    await tester.enterText(textFields.at(6), 'MySecret123!');

    // Switch language to Kazakh
    await tester.ensureVisible(find.text('Қазақша'));
    await tester.tap(find.text('Қазақша'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Создать компанию'));
    await tester.tap(find.text('Создать компанию'));
    await tester.pumpAndSettle();

    expect(provisioningRepo.lastClaimPayload, isNotNull);
    expect(provisioningRepo.lastClaimPayload!.code, 'ABCD 1234 EFGH 5678');
    expect(provisioningRepo.lastClaimPayload!.company, 'Korkem Mebel');
    expect(provisioningRepo.lastClaimPayload!.ownerEmail, 'aidos@korkem.kz');
    expect(provisioningRepo.lastClaimPayload!.language, 'kk');

    // Signed in automatically
    expect(authRepo.signedInUser, 'aidos@korkem.kz');
    expect(authRepo.signedInPassword, 'MySecret123!');
  });

  testWidgets('shows already_claimed error message on 409', (tester) async {
    final provisioningRepo = _FakeProvisioningRepository(
      claimException: const ClaimAlreadyClaimedException(),
    );

    await tester.pumpWidget(
      buildHarness(tester, provisioningRepo: provisioningRepo),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(1), 'ABCD1234EFGH5678');
    await tester.enterText(textFields.at(2), 'Korkem');
    await tester.enterText(textFields.at(3), 'Aidos');
    await tester.enterText(textFields.at(4), 'aidos@korkem.kz');
    await tester.enterText(textFields.at(5), 'Pass123!');
    await tester.enterText(textFields.at(6), 'Pass123!');

    await tester.ensureVisible(find.text('Создать компанию'));
    await tester.tap(find.text('Создать компанию'));
    await tester.pumpAndSettle();

    expect(
      find.text('Этот узел уже занят. Попросите у владельца приглашение'),
      findsOneWidget,
    );
  });

  testWidgets('shows code_refused error message on 403', (tester) async {
    final provisioningRepo = _FakeProvisioningRepository(
      claimException: const ClaimCodeRefusedException(),
    );

    await tester.pumpWidget(
      buildHarness(tester, provisioningRepo: provisioningRepo),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(1), 'WRONGCODE1234567');
    await tester.enterText(textFields.at(2), 'Korkem');
    await tester.enterText(textFields.at(3), 'Aidos');
    await tester.enterText(textFields.at(4), 'aidos@korkem.kz');
    await tester.enterText(textFields.at(5), 'Pass123!');
    await tester.enterText(textFields.at(6), 'Pass123!');

    await tester.ensureVisible(find.text('Создать компанию'));
    await tester.tap(find.text('Создать компанию'));
    await tester.pumpAndSettle();

    expect(
      find.text('Неверный код. Он показан в журнале узла при запуске'),
      findsOneWidget,
    );
  });

  testWidgets('password reveal toggles work and flip tooltips', (tester) async {
    final provisioningRepo = _FakeProvisioningRepository();
    await tester.pumpWidget(
      buildHarness(tester, provisioningRepo: provisioningRepo),
    );
    await tester.pumpAndSettle();

    final showButtons = find.byTooltip('Показать пароль');
    expect(showButtons, findsNWidgets(2));

    await tester.tap(showButtons.first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Скрыть пароль'), findsOneWidget);
  });
}
