/// What the server will say about a chat channel — never a credential.
///
/// The field that matters is [configured]: a map of credential name to whether
/// one exists. The app is told *that* a token is stored and never *which*, so a
/// decompiled build reveals nothing about the factory's bots.
class ChannelConfig {
  const ChannelConfig({
    required this.channel,
    required this.enabled,
    required this.state,
    required this.configured,
    this.webhookUrl,
    this.phoneNumberId,
    this.businessAccountId,
    this.apiVersion,
  });

  factory ChannelConfig.fromJson(Map<String, dynamic> json) => ChannelConfig(
    channel: json['channel'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? false,
    state: json['state'] as String? ?? notConfigured,
    configured: {
      for (final entry in (json['configured'] as Map? ?? const {}).entries)
        entry.key as String: entry.value == true,
    },
    webhookUrl: json['webhook_url'] as String?,
    phoneNumberId: json['phone_number_id'] as String?,
    businessAccountId: json['business_account_id'] as String?,
    apiVersion: json['api_version'] as String?,
  );

  /// Some credential is missing, so the bot cannot work whatever else is set.
  static const notConfigured = 'not_configured';

  /// Everything is set and the operator has switched the channel off.
  static const disabled = 'disabled';

  /// Everything is set and the channel is on.
  ///
  /// Deliberately not called "connected": nothing has been asked of the
  /// provider yet, and a green light that means "a token is present" is exactly
  /// the lie this screen must not tell.
  static const ready = 'ready';

  final String channel;
  final bool enabled;
  final String state;
  final Map<String, bool> configured;
  final String? webhookUrl;
  final String? phoneNumberId;
  final String? businessAccountId;
  final String? apiVersion;

  bool get isComplete => configured.values.every((set) => set);
}

/// The result of actually calling the provider.
class ChannelTestResult {
  const ChannelTestResult({required this.ok, this.code, this.detail});

  factory ChannelTestResult.fromJson(Map<String, dynamic> json) =>
      ChannelTestResult(
        ok: json['ok'] as bool? ?? false,
        code: json['code'] as String?,
        detail:
            json['bot_username'] as String? ??
            json['phone_number'] as String? ??
            json['error'] as String?,
      );

  final bool ok;
  final String? code;
  final String? detail;
}

/// A sender the bots have heard from, and who an administrator says they are.
class ChannelIdentity {
  const ChannelIdentity({
    required this.name,
    required this.channel,
    required this.externalId,
    required this.enabled,
    this.displayName,
    this.user,
    this.role,
    this.customer,
    this.lastSeenOn,
  });

  factory ChannelIdentity.fromJson(Map<String, dynamic> json) =>
      ChannelIdentity(
        name: json['name'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        externalId: json['external_id'] as String? ?? '',
        enabled: (json['enabled'] as num? ?? 0) != 0,
        displayName: json['display_name'] as String?,
        user: json['user'] as String?,
        role: json['role'] as String?,
        customer: json['customer'] as String?,
        lastSeenOn: json['last_seen_on'] as String?,
      );

  final String name;
  final String channel;
  final String externalId;
  final bool enabled;
  final String? displayName;
  final String? user;
  final String? role;
  final String? customer;
  final String? lastSeenOn;

  bool get isLinked => enabled && (user ?? '').isNotEmpty;
}
