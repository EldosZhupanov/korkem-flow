import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/channel_settings/data/channel_settings_repository.dart';
import 'package:korkem_flow/features/channel_settings/domain/channel_config.dart';
import 'package:korkem_flow/features/channel_settings/presentation/channel_settings_screen.dart';

import '../../support/widget_harness.dart';

/// The channel settings screen, and the two things it must never get wrong.
///
/// A bot token on a phone is a bot token published to every device the app runs
/// on, so no credential may reach the widget tree. And a green light must mean
/// somebody asked the provider — a screen that says Connected because a token
/// is present is worse than one that says nothing.
void main() {
  ChannelConfig telegram({
    bool enabled = true,
    String state = ChannelConfig.ready,
    bool token = true,
    bool secret = true,
    String? hint,
    String? lastError,
  }) => ChannelConfig(
    channel: 'Telegram',
    enabled: enabled,
    state: state,
    configured: {'bot_token': token, 'webhook_secret': secret},
    webhookUrl: 'https://korkem.example/api/method/…telegram.webhook',
    hints: {'bot_token': ?hint},
    lastError: lastError,
  );

  ChannelConfig whatsapp({String state = ChannelConfig.notConfigured}) =>
      ChannelConfig(
        channel: 'WhatsApp',
        enabled: false,
        state: state,
        configured: const {
          'access_token': false,
          'phone_number_id': false,
          'webhook_verify_token': false,
        },
        // The server always sends one; Meta's is pasted by hand into their
        // dashboard rather than registered through an API.
        webhookUrl: 'https://korkem.example/api/method/…whatsapp.webhook',
      );

  Future<void> pump(
    WidgetTester tester, {
    ChannelConfig? tg,
    ChannelConfig? wa,
    List<ChannelIdentity> identities = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelStatusProvider.overrideWith(
            (ref) async => (
              telegram: tg ?? telegram(),
              whatsapp: wa ?? whatsapp(),
            ),
          ),
          channelIdentitiesProvider.overrideWith((ref) async => identities),
        ],
        child: harness(const ChannelSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The identity list sits below two channel cards, so in a phone-sized test
  /// viewport it has not been built yet — a lazy list only builds what is on
  /// screen. Scrolled to rather than asserted blind.
  Future<void> scrollToIdentities(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every credential field starts empty, stored or not', (
    tester,
  ) async {
    // The defect this guards: pre-filling a masked value and posting the form
    // back would overwrite a working token with punctuation.
    await pump(tester);

    final obscured = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.obscureText);

    expect(obscured, isNotEmpty);
    for (final field in obscured) {
      expect(field.controller!.text, isEmpty);
    }
  });

  testWidgets('a stored credential is described, never shown', (tester) async {
    await pump(tester);

    expect(find.text('Stored. Leave blank to keep it.'), findsWidgets);
  });

  testWidgets('a configured channel reads Ready, not Connected', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('a channel missing a credential says so', (tester) async {
    await pump(tester);

    expect(find.text('Not set up'), findsOneWidget);
  });

  testWidgets('a configured but switched-off channel reads Off', (
    tester,
  ) async {
    await pump(
      tester,
      tg: telegram(enabled: false, state: ChannelConfig.disabled),
    );

    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('the webhook URL is shown so it can be copied to the provider', (
    tester,
  ) async {
    await pump(tester);

    // Twice over now: the address itself, and the editable field an operator
    // types a different one into.
    expect(find.textContaining('telegram.webhook'), findsWidgets);
  });

  testWidgets('a stored credential is hinted at, never filled in', (
    tester,
  ) async {
    await pump(tester, tg: telegram(hint: '••••••••wxyz'));

    final field = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((candidate) => candidate.obscureText);

    expect(field.decoration!.hintText, '••••••••wxyz');
    expect(
      field.controller!.text,
      isEmpty,
      reason: 'a mask posted back would overwrite a working token',
    );
  });

  testWidgets('a real successful call is the only thing that reads Connected', (
    tester,
  ) async {
    await pump(tester, tg: telegram(state: ChannelConfig.connected));

    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('a rejected credential is not confused with an unreachable one', (
    tester,
  ) async {
    await pump(tester, tg: telegram(state: ChannelConfig.invalidCredentials));

    expect(find.text('Credentials rejected'), findsOneWidget);
    expect(find.text('Provider unreachable'), findsNothing);
  });

  testWidgets('a webhook problem says so rather than blaming the token', (
    tester,
  ) async {
    await pump(tester, tg: telegram(state: ChannelConfig.webhookError));

    expect(find.text('Webhook problem'), findsOneWidget);
  });

  testWidgets('an unreachable provider is not a wrong password', (
    tester,
  ) async {
    await pump(tester, tg: telegram(state: ChannelConfig.providerUnavailable));

    expect(find.text('Provider unreachable'), findsOneWidget);
  });

  testWidgets('a blocked bot does not read as ready', (tester) async {
    // The defect this guards: `forbidden` was not in the list of verdicts the
    // server surfaced, so a channel every message to which was being refused
    // displayed Ready.
    await pump(tester, tg: telegram(state: ChannelConfig.forbidden));

    expect(find.text('Blocked by the provider'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
  });

  testWidgets(
    'being rate limited is its own state, and a warning not an error',
    (
      tester,
    ) async {
      await pump(tester, tg: telegram(state: ChannelConfig.rateLimited));

      expect(find.text('Rate limited'), findsOneWidget);
    },
  );

  testWidgets("the provider's own last error is shown", (tester) async {
    await pump(
      tester,
      tg: telegram(
        state: ChannelConfig.webhookError,
        lastError: 'SSL certificate verify failed',
      ),
    );

    expect(find.text('SSL certificate verify failed'), findsOneWidget);
  });

  testWidgets('only Telegram offers to configure its own webhook', (
    tester,
  ) async {
    // Meta's is configured in their dashboard; offering a button that cannot
    // do anything is worse than the sentence that says where to paste the URL.
    await pump(tester);

    expect(find.text('Configure webhook'), findsOneWidget);
    expect(
      find.textContaining("Paste this URL into the provider's dashboard."),
      findsOneWidget,
    );
  });

  testWidgets('an unlinked sender is listed as somebody to decide about', (
    tester,
  ) async {
    await pump(
      tester,
      identities: const [
        ChannelIdentity(
          name: 'abc',
          channel: 'Telegram',
          externalId: '777001',
          enabled: true,
          displayName: 'Иван',
        ),
      ],
    );

    await scrollToIdentities(tester, find.textContaining('777001'));

    expect(find.textContaining('777001'), findsOneWidget);
    expect(find.text('Not linked'), findsOneWidget);
  });

  testWidgets('a linked sender shows who they are', (tester) async {
    await pump(
      tester,
      identities: const [
        ChannelIdentity(
          name: 'abc',
          channel: 'WhatsApp',
          externalId: '77001234567',
          enabled: true,
          user: 'korkem.ivan@example.com',
          customer: 'Мебель Астана',
        ),
      ],
    );

    await scrollToIdentities(tester, find.text('Unlink'));

    expect(find.text('Unlink'), findsOneWidget);
    expect(find.text('Мебель Астана'), findsOneWidget);
  });

  testWidgets('no sender at all is said plainly', (tester) async {
    await pump(tester);
    await scrollToIdentities(
      tester,
      find.text('Nobody has written to the bots yet.'),
    );

    expect(find.text('Nobody has written to the bots yet.'), findsOneWidget);
  });

  group('the shape the server sends', () {
    test('a channel with every credential set is complete', () {
      final config = ChannelConfig.fromJson(const {
        'channel': 'Telegram',
        'enabled': true,
        'state': 'ready',
        'configured': {'bot_token': true, 'webhook_secret': true},
      });

      expect(config.isComplete, isTrue);
      expect(config.state, ChannelConfig.ready);
    });

    test('one missing credential makes it incomplete', () {
      final config = ChannelConfig.fromJson(const {
        'channel': 'WhatsApp',
        'configured': {'access_token': true, 'phone_number_id': false},
      });

      expect(config.isComplete, isFalse);
      expect(config.state, ChannelConfig.notConfigured);
    });

    test('an identity with no user speaks for nobody', () {
      final identity = ChannelIdentity.fromJson(const {
        'name': 'x',
        'channel': 'Telegram',
        'external_id': '1',
        'enabled': 1,
      });

      expect(identity.isLinked, isFalse);
    });

    test('a disabled identity speaks for nobody either', () {
      final identity = ChannelIdentity.fromJson(const {
        'name': 'x',
        'channel': 'Telegram',
        'external_id': '1',
        'enabled': 0,
        'user': 'someone@example.com',
      });

      expect(identity.isLinked, isFalse);
    });

    test("a failed test carries the provider's own reason", () {
      final result = ChannelTestResult.fromJson(const {
        'ok': false,
        'code': 'unreachable',
        'error': 'Network is unreachable',
      });

      expect(result.ok, isFalse);
      expect(result.detail, 'Network is unreachable');
    });
  });
}
