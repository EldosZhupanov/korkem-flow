import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/integration_settings/data/integration_settings_repository.dart';
import 'package:korkem_flow/features/integration_settings/domain/integration_config.dart';
import 'package:korkem_flow/features/integration_settings/presentation/integration_settings_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeIntegrationRepository extends IntegrationSettingsRepository {
  _FakeIntegrationRepository({
    this.statusResult,
    this.saveTrustMeHandler,
    this.clearSecretHandler,
  }) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());

  IntegrationStatus? statusResult;

  final Future<TrustMeConfig> Function({
    bool? enabled,
    String? organizationBin,
    String? apiToken,
    String? webhookSecret,
  })?
  saveTrustMeHandler;

  final Future<Map<String, dynamic>> Function({
    required String provider,
    required String field,
  })?
  clearSecretHandler;

  @override
  Future<IntegrationStatus> fetchStatus() async {
    return statusResult ??
        const IntegrationStatus(
          trustme: TrustMeConfig(
            enabled: false,
            isApiTokenConfigured: false,
            isWebhookSecretConfigured: false,
          ),
          kaspi: KaspiConfig(
            enabled: false,
            isApiKeyConfigured: false,
            isWebhookSecretConfigured: false,
          ),
        );
  }

  @override
  Future<TrustMeConfig> saveTrustMe({
    bool? enabled,
    String? organizationBin,
    String? apiToken,
    String? webhookSecret,
  }) async {
    if (saveTrustMeHandler != null) {
      return saveTrustMeHandler!(
        enabled: enabled,
        organizationBin: organizationBin,
        apiToken: apiToken,
        webhookSecret: webhookSecret,
      );
    }
    return TrustMeConfig(
      enabled: enabled ?? false,
      organizationBin: organizationBin,
      isApiTokenConfigured: apiToken != null && apiToken.isNotEmpty,
      isWebhookSecretConfigured:
          webhookSecret != null && webhookSecret.isNotEmpty,
    );
  }

  @override
  Future<KaspiConfig> saveKaspi({
    bool? enabled,
    String? merchantId,
    String? apiKey,
    String? webhookSecret,
  }) async {
    return KaspiConfig(
      enabled: enabled ?? false,
      merchantId: merchantId,
      isApiKeyConfigured: apiKey != null && apiKey.isNotEmpty,
      isWebhookSecretConfigured:
          webhookSecret != null && webhookSecret.isNotEmpty,
    );
  }

  @override
  Future<Map<String, dynamic>> clearSecret({
    required String provider,
    required String field,
  }) async {
    if (clearSecretHandler != null) {
      return clearSecretHandler!(provider: provider, field: field);
    }
    return {
      'configured': {field: false},
    };
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required IntegrationSettingsRepository repository,
  }) {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        integrationSettingsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const IntegrationSettingsScreen(),
      ),
    );
  }

  testWidgets(
    'Secret input fields are completely empty when configured: true '
    'and show status badge',
    (tester) async {
      final repo = _FakeIntegrationRepository(
        statusResult: const IntegrationStatus(
          trustme: TrustMeConfig(
            enabled: true,
            organizationBin: '123456789012',
            isApiTokenConfigured: true,
            isWebhookSecretConfigured: true,
          ),
          kaspi: KaspiConfig(
            enabled: true,
            merchantId: 'M-555',
            isApiKeyConfigured: true,
            isWebhookSecretConfigured: false,
          ),
        ),
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Permanent security note is visible
      expect(
        find.text(
          'Это ключи вашей компании. Они хранятся в зашифрованном виде на '
          'вашем сервере и наружу не передаются.',
        ),
        findsOneWidget,
      );

      // Public values are rendered in their controllers
      expect(find.text('123456789012'), findsOneWidget);
      expect(find.text('M-555'), findsOneWidget);

      // Status badges: "Ключ задан" vs "Ключа нет"
      expect(find.text('Ключ задан'), findsNWidgets(3));
      expect(find.text('Ключа нет'), findsOneWidget);

      // Check all secret text inputs are completely empty — NO fake dots!
      final textFormFieldFinders = find.byType(TextFormField);
      // There are 6 TextFormFields total:
      // 1. TrustMe BIN
      // 2. TrustMe API token (empty)
      // 3. TrustMe Webhook secret (empty)
      // 4. Kaspi Merchant ID
      // 5. Kaspi API key (empty)
      // 6. Kaspi Webhook secret (empty)
      expect(textFormFieldFinders, findsNWidgets(6));

      // Check that none of the inputs have fake asterisks or dots
      expect(find.text('••••••••'), findsNothing);
      expect(find.text('********'), findsNothing);
    },
  );

  testWidgets(
    'Empty secret input field is not sent to save when updating public values',
    (tester) async {
      String? savedBin;
      String? savedApiToken;
      String? savedWebhookSecret;

      final repo = _FakeIntegrationRepository(
        statusResult: const IntegrationStatus(
          trustme: TrustMeConfig(
            enabled: true,
            organizationBin: '111122223333',
            isApiTokenConfigured: true,
            isWebhookSecretConfigured: true,
          ),
          kaspi: KaspiConfig(
            enabled: false,
            isApiKeyConfigured: false,
            isWebhookSecretConfigured: false,
          ),
        ),
        saveTrustMeHandler:
            ({
              enabled,
              organizationBin,
              apiToken,
              webhookSecret,
            }) async {
              savedBin = organizationBin;
              savedApiToken = apiToken;
              savedWebhookSecret = webhookSecret;
              return TrustMeConfig(
                enabled: enabled ?? true,
                organizationBin: organizationBin,
                isApiTokenConfigured: true,
                isWebhookSecretConfigured: true,
              );
            },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Edit only the BIN field
      final binFinder = find.widgetWithText(TextFormField, '111122223333');
      await tester.enterText(binFinder, '999988887777');
      await tester.pumpAndSettle();

      // Tap TrustMe Save button (the first Save button on the screen)
      final saveButtons = find.widgetWithText(FilledButton, 'Сохранить');
      await tester.tap(saveButtons.first);
      await tester.pumpAndSettle();

      // Verify that BIN was updated, but empty secret inputs were NOT passed
      expect(savedBin, '999988887777');
      expect(savedApiToken, isEmpty);
      expect(savedWebhookSecret, isEmpty);
    },
  );

  testWidgets(
    'Deleting a key requires confirmation and calls clearSecret '
    'upon confirmation',
    (tester) async {
      var clearSecretCalled = false;
      String? clearedProvider;
      String? clearedField;

      final repo = _FakeIntegrationRepository(
        statusResult: const IntegrationStatus(
          trustme: TrustMeConfig(
            enabled: true,
            organizationBin: '123456789012',
            isApiTokenConfigured: true,
            isWebhookSecretConfigured: false,
          ),
          kaspi: KaspiConfig(
            enabled: false,
            isApiKeyConfigured: false,
            isWebhookSecretConfigured: false,
          ),
        ),
        clearSecretHandler:
            ({
              required provider,
              required field,
            }) async {
              clearSecretCalled = true;
              clearedProvider = provider;
              clearedField = field;
              return {
                'configured': {field: false},
              };
            },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Find the delete button next to the configured API token
      final deleteIcon = find.byTooltip('Удалить');
      expect(deleteIcon, findsOneWidget);

      // Tap delete icon
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('Удалить ключ?'), findsOneWidget);
      expect(
        find.text(
          'Удалить API-токен? Интеграция TrustMe перестанет работать '
          'до ввода нового ключа.',
        ),
        findsOneWidget,
      );

      // Cancel button dismisses without calling clearSecret
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(clearSecretCalled, isFalse);
      expect(find.text('Удалить ключ?'), findsNothing);

      // Tap delete icon again and confirm
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Tap the confirm "Удалить" button in the dialog
      final dialogDeleteButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Удалить'),
      );
      await tester.tap(dialogDeleteButton);
      await tester.pumpAndSettle();

      expect(clearSecretCalled, isTrue);
      expect(clearedProvider, 'trustme');
      expect(clearedField, 'api_token');
    },
  );

  testWidgets(
    'Displays last_status, last_error, and last_checked_on when present',
    (tester) async {
      final repo = _FakeIntegrationRepository(
        statusResult: const IntegrationStatus(
          trustme: TrustMeConfig(
            enabled: true,
            isApiTokenConfigured: true,
            isWebhookSecretConfigured: false,
            lastStatus: 'connected',
            lastError: 'TLS certificate expired',
            lastCheckedOn: '2026-09-03 14:00',
          ),
          kaspi: KaspiConfig(
            enabled: false,
            isApiKeyConfigured: false,
            isWebhookSecretConfigured: false,
          ),
        ),
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Статус: connected'), findsOneWidget);
      expect(find.text('Ошибка: TLS certificate expired'), findsOneWidget);
      expect(find.text('Проверено: 2026-09-03 14:00'), findsOneWidget);
    },
  );
}
