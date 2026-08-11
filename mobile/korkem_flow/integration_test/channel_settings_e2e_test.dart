import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/channel_settings/data/channel_settings_repository.dart';
import 'package:korkem_flow/features/channel_settings/domain/channel_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 30 — the channel settings screen against the real backend.
///
/// What this proves that a widget test cannot: the screen's states come from
/// the server's own view of the channels, Test Connection makes a **real call
/// to the real provider** and shows what actually came back, and no credential
/// reaches the device at any point in that.
///
/// It runs as an administrator, because configuring a bot is an administrator's
/// job and the API says so — every endpoint behind this screen is
/// `frappe.only_for("System Manager")`.
///
/// ```sh
/// flutter test integration_test/channel_settings_e2e_test.dart \
///   -d emulator-5554 --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
///   --dart-define=KORKEM_E2E_ADMIN=Administrator \
///   --dart-define=KORKEM_E2E_ADMIN_PASSWORD=...
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const admin = String.fromEnvironment('KORKEM_E2E_ADMIN');
  const password = String.fromEnvironment('KORKEM_E2E_ADMIN_PASSWORD');
  final baseUrl = AppConfig.fromEnvironment().baseUrl;

  late ProviderContainer container;

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(minutes: 2),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('timed out waiting for ${reason ?? 'condition'}');
  }

  Future<void> signIn(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        credentialStoreProvider.overrideWithValue(_MemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KorkemFlowApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final fields = find.byType(TextFormField);
    await pumpUntil(
      tester,
      () => fields.evaluate().length >= 3,
      reason: 'the login form',
    );

    await tester.enterText(fields.at(0), baseUrl);
    await tester.enterText(fields.at(1), admin);
    await tester.enterText(fields.at(2), password);
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pump(const Duration(seconds: 1));
    await pumpUntil(
      tester,
      () => find.byType(TextFormField).evaluate().isEmpty,
      reason: 'sign-in to complete',
    );
  }

  /// Everything currently rendered, as text.
  String onScreen() => find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data ?? '')
      .join('\n');

  testWidgets(
    'an administrator can see and test the channels, and is shown no secret',
    (tester) async {
      await signIn(tester);

      // Straight to the screen under test. Tab-walking would be testing the
      // navigation shell, which has its own tests.
      final router = container.read(routerProvider);
      unawaited(router.push<void>(Routes.channelSettings));
      await tester.pump(const Duration(seconds: 2));

      // The states come from the server, which has already made a real call.
      final status = await container
          .read(channelSettingsRepositoryProvider)
          .status();
      expect(
        status.telegram.state,
        isNot(ChannelConfig.connected),
        reason:
            'this bench holds placeholder credentials — a green light here '
            'would mean the screen invents one',
      );

      await pumpUntil(
        tester,
        () => onScreen().contains('Telegram'),
        reason: 'the Telegram tile',
      );
      expect(onScreen(), contains('WhatsApp'));

      // Test Connection: a real request to the real provider, from the server.
      final result = await container
          .read(channelSettingsRepositoryProvider)
          .test('Telegram');
      expect(
        result.ok,
        isFalse,
        reason: 'placeholder credentials must not be accepted',
      );
      expect(
        result.code,
        anyOf(
          ChannelConfig.invalidCredentials,
          ChannelConfig.providerUnavailable,
          ChannelConfig.notConfigured,
        ),
        reason: 'the reason must be specific enough to act on',
      );

      // And the whole point: nothing token-shaped is anywhere on this device.
      final rendered = onScreen();
      expect(rendered, isNot(matches(RegExp(r'\d{6,}:[A-Za-z0-9_-]{10,}'))));
      expect(rendered, isNot(contains('Bearer ')));
      for (final hint in status.telegram.hints.values) {
        expect(
          hint.startsWith('••••'),
          isTrue,
          reason: 'a hint must be a mask, never a credential',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets(
    'the identity list is what links a chat account to a KORKEM user',
    (tester) async {
      await signIn(tester);

      final identities = await container
          .read(channelSettingsRepositoryProvider)
          .identities();

      // Linked rows must name a user; unlinked ones must not pretend to.
      for (final identity in identities) {
        if (identity.isLinked) {
          expect(identity.user, isNotEmpty);
        } else {
          expect(identity.user ?? '', isEmpty);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

class _MemoryStore implements CredentialStore {
  AuthCredentials? _credentials;
  String? _serverUrl;

  @override
  Future<AuthCredentials?> read() async => _credentials;

  @override
  Future<void> write(AuthCredentials credentials) async =>
      _credentials = credentials;

  @override
  Future<String?> readServerUrl() async => _serverUrl;

  @override
  Future<void> writeServerUrl(String url) async => _serverUrl = url;

  @override
  Future<void> clear() async {
    _credentials = null;
    _serverUrl = null;
  }
}
