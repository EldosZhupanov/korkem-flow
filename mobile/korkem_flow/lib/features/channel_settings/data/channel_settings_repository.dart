import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/channel_settings/domain/channel_config.dart';

/// The client half of the channel settings API.
///
/// Tokens travel one way. Every save sends only the fields the operator typed —
/// an empty box is omitted, not sent as an empty string, because the server
/// treats a blank value as "keep what is stored" and sending one anyway is how
/// a settings screen takes a factory's bots offline.
class ChannelSettingsRepository {
  const ChannelSettingsRepository(this._client);

  static const _base = 'korkem_ai.korkem_ai.channels_api';

  final FrappeClient _client;

  Future<({ChannelConfig telegram, ChannelConfig whatsapp})> status() async {
    final response = await _client.callMethod('$_base.channel_status');
    final message = response['message'] as Map? ?? const {};
    return (
      telegram: ChannelConfig.fromJson(
        Map<String, dynamic>.from(message['telegram'] as Map? ?? const {}),
      ),
      whatsapp: ChannelConfig.fromJson(
        Map<String, dynamic>.from(message['whatsapp'] as Map? ?? const {}),
      ),
    );
  }

  Future<void> saveTelegram({
    String? botToken,
    String? webhookSecret,
    String? webhookUrl,
    bool? enabled,
  }) => _client.callMethod(
    '$_base.save_telegram',
    post: true,
    params: {
      if (botToken != null && botToken.isNotEmpty) 'bot_token': botToken,
      if (webhookSecret != null && webhookSecret.isNotEmpty)
        'webhook_secret': webhookSecret,
      if (webhookUrl != null && webhookUrl.isNotEmpty)
        'webhook_url': webhookUrl,
      if (enabled != null) 'enabled': enabled ? 1 : 0,
    },
  );

  /// Registers the webhook with Telegram and reads back what it has since
  /// found there — the second half matters, because `setWebhook` succeeding
  /// only means the URL was accepted, not that anything arrives.
  Future<ChannelTestResult> configureTelegramWebhook({String? url}) async {
    final response = await _client.callMethod(
      '$_base.configure_telegram_webhook',
      post: true,
      params: {if (url != null && url.isNotEmpty) 'url': url},
    );
    return ChannelTestResult.fromJson(
      Map<String, dynamic>.from(response['message'] as Map? ?? const {}),
    );
  }

  /// Stops Telegram delivering here. What is already queued at Telegram is
  /// left alone — those are messages people sent.
  Future<ChannelTestResult> removeTelegramWebhook() async {
    final response = await _client.callMethod(
      '$_base.remove_telegram_webhook',
      post: true,
    );
    return ChannelTestResult.fromJson(
      Map<String, dynamic>.from(response['message'] as Map? ?? const {}),
    );
  }

  Future<void> saveWhatsapp({
    String? accessToken,
    String? phoneNumberId,
    String? businessAccountId,
    String? webhookVerifyToken,
    String? apiVersion,
    bool? enabled,
  }) => _client.callMethod(
    '$_base.save_whatsapp',
    post: true,
    params: {
      if (accessToken != null && accessToken.isNotEmpty)
        'access_token': accessToken,
      if (phoneNumberId != null && phoneNumberId.isNotEmpty)
        'phone_number_id': phoneNumberId,
      if (businessAccountId != null && businessAccountId.isNotEmpty)
        'business_account_id': businessAccountId,
      if (webhookVerifyToken != null && webhookVerifyToken.isNotEmpty)
        'webhook_verify_token': webhookVerifyToken,
      if (apiVersion != null && apiVersion.isNotEmpty)
        'api_version': apiVersion,
      if (enabled != null) 'enabled': enabled ? 1 : 0,
    },
  );

  /// Asks the backend to make one real call to the provider.
  Future<ChannelTestResult> test(String channel) async {
    final response = await _client.callMethod(
      '$_base.test_${channel.toLowerCase()}',
      post: true,
    );
    return ChannelTestResult.fromJson(
      Map<String, dynamic>.from(response['message'] as Map? ?? const {}),
    );
  }

  Future<List<ChannelIdentity>> identities() async {
    final response = await _client.callMethod('$_base.list_identities');
    final message = response['message'] as Map? ?? const {};
    return [
      for (final raw in (message['identities'] as List? ?? const []))
        ChannelIdentity.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  Future<void> link({
    required String channel,
    required String externalId,
    required String user,
    String? role,
  }) => _client.callMethod(
    '$_base.link_identity',
    post: true,
    params: {
      'channel': channel,
      'external_id': externalId,
      'user': user,
      if (role != null && role.isNotEmpty) 'role': role,
    },
  );

  Future<void> unlink(String name) => _client.callMethod(
    '$_base.unlink_identity',
    post: true,
    params: {'name': name},
  );
}

final channelSettingsRepositoryProvider = Provider<ChannelSettingsRepository>(
  (ref) => ChannelSettingsRepository(ref.watch(frappeClientProvider)),
);

final channelStatusProvider =
    FutureProvider<({ChannelConfig telegram, ChannelConfig whatsapp})>(
      (ref) => ref.watch(channelSettingsRepositoryProvider).status(),
    );

final channelIdentitiesProvider = FutureProvider<List<ChannelIdentity>>(
  (ref) => ref.watch(channelSettingsRepositoryProvider).identities(),
);
