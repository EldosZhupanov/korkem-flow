import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/channel_settings/data/channel_settings_repository.dart';
import 'package:korkem_flow/features/channel_settings/domain/channel_config.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Connecting the bots, and saying who is on the other end of them.
///
/// **No token is ever displayed.** The server answers "a token is stored" and
/// never what it is, so every credential field here is write-only: leaving it
/// blank keeps whatever the server holds. That is what lets an operator toggle
/// a channel off without having their bot token in hand — and what stops this
/// screen from becoming a way to read secrets off a phone.
///
/// **"Ready" is not "connected".** A channel with every credential set shows
/// Ready, which says only that nothing is missing. Connected appears after
/// [ChannelSettingsRepository.test] has made one real call to the provider and
/// it answered — and the four failures are told apart, because "wrong token"
/// and "the provider cannot reach our webhook" are fixed in different places.
///
/// **A stored credential is described, never shown.** The server sends the tail
/// of it (`••••••••ABCD`), which is enough to tell two accounts apart and
/// useless to anybody reading over a shoulder. The field below it stays empty:
/// leaving it blank keeps whatever is stored.
class ChannelSettingsScreen extends ConsumerWidget {
  const ChannelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(channelStatusProvider);

    return AppScreen(
      title: l10n.channelsTitle,
      subtitle: l10n.channelsSubtitle,
      body: status.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(channelStatusProvider),
        ),
        data: (({ChannelConfig telegram, ChannelConfig whatsapp}) data) =>
            ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _SecurityNote(text: l10n.channelsSecretsNote),
                const SizedBox(height: AppSpacing.lg),
                _ChannelTile(
                  config: data.telegram,
                  fields: const [
                    _Field(key: 'bot_token', label: _FieldLabel.botToken),
                    _Field(
                      key: 'webhook_secret',
                      label: _FieldLabel.webhookSecret,
                    ),
                    _Field(
                      key: 'webhook_url',
                      label: _FieldLabel.webhookUrl,
                      secret: false,
                    ),
                  ],
                  // Telegram registers its own webhook through the API. Meta
                  // does not: theirs is configured in their dashboard, so the
                  // honest offer there is the URL to paste.
                  canConfigureWebhook: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _ChannelTile(
                  config: data.whatsapp,
                  fields: const [
                    _Field(key: 'access_token', label: _FieldLabel.accessToken),
                    _Field(
                      key: 'phone_number_id',
                      label: _FieldLabel.phoneNumberId,
                      secret: false,
                    ),
                    _Field(
                      key: 'webhook_verify_token',
                      label: _FieldLabel.verifyToken,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionLabel(l10n.channelsIdentities),
                const _IdentityList(),
              ],
            ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AppIcons.info,
          size: AppIconSize.dense,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

enum _FieldLabel {
  botToken,
  webhookSecret,
  webhookUrl,
  accessToken,
  phoneNumberId,
  verifyToken,
}

class _Field {
  const _Field({required this.key, required this.label, this.secret = true});

  final String key;
  final _FieldLabel label;
  final bool secret;

  String labelOf(AppLocalizations l10n) => switch (label) {
    _FieldLabel.botToken => l10n.channelsBotToken,
    _FieldLabel.webhookSecret => l10n.channelsWebhookSecret,
    _FieldLabel.webhookUrl => l10n.channelsWebhookUrl,
    _FieldLabel.accessToken => l10n.channelsAccessToken,
    _FieldLabel.phoneNumberId => l10n.channelsPhoneNumberId,
    _FieldLabel.verifyToken => l10n.channelsVerifyToken,
  };
}

class _ChannelTile extends ConsumerStatefulWidget {
  const _ChannelTile({
    required this.config,
    required this.fields,
    this.canConfigureWebhook = false,
  });

  final ChannelConfig config;
  final List<_Field> fields;
  final bool canConfigureWebhook;

  @override
  ConsumerState<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends ConsumerState<_ChannelTile> {
  final _controllers = <String, TextEditingController>{};
  bool _busy = false;
  ChannelTestResult? _lastTest;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field.key] = TextEditingController(
        // Only a non-secret can be shown back, and only the one the server
        // actually returns.
        text: switch (field.key) {
          'phone_number_id' => widget.config.phoneNumberId ?? '',
          'webhook_url' => widget.config.webhookUrl ?? '',
          _ => '',
        },
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _typed(String key) {
    final value = _controllers[key]?.text.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _isTelegram => widget.config.channel == 'Telegram';

  Future<void> _save({bool? enabled}) => _run(() async {
    final repository = ref.read(channelSettingsRepositoryProvider);
    if (_isTelegram) {
      await repository.saveTelegram(
        botToken: _typed('bot_token'),
        webhookSecret: _typed('webhook_secret'),
        webhookUrl: _typed('webhook_url'),
        enabled: enabled,
      );
    } else {
      await repository.saveWhatsapp(
        accessToken: _typed('access_token'),
        phoneNumberId: _typed('phone_number_id'),
        webhookVerifyToken: _typed('webhook_verify_token'),
        enabled: enabled,
      );
    }
    // Cleared so a token cannot linger in a text field behind a lock screen.
    for (final field in widget.fields) {
      if (field.secret) _controllers[field.key]?.clear();
    }
    ref.invalidate(channelStatusProvider);
  });

  Future<void> _test() => _run(() async {
    final result = await ref
        .read(channelSettingsRepositoryProvider)
        .test(widget.config.channel);
    if (mounted) setState(() => _lastTest = result);
    ref.invalidate(channelStatusProvider);
  });

  Future<void> _configureWebhook() => _run(() async {
    final result = await ref
        .read(channelSettingsRepositoryProvider)
        .configureTelegramWebhook(url: _typed('webhook_url'));
    if (mounted) setState(() => _lastTest = result);
    ref.invalidate(channelStatusProvider);
  });

  Future<void> _removeWebhook() => _run(() async {
    final result = await ref
        .read(channelSettingsRepositoryProvider)
        .removeTelegramWebhook();
    if (mounted) setState(() => _lastTest = result);
    ref.invalidate(channelStatusProvider);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final config = widget.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    config.channel,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                _StateChip(state: config.state, test: _lastTest),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final field in widget.fields) ...[
              TextField(
                key: ValueKey('${config.channel}:${field.key}'),
                controller: _controllers[field.key],
                obscureText: field.secret,
                decoration: InputDecoration(
                  labelText: field.labelOf(l10n),
                  // The mask is a *hint*, never a value: pre-filling it and
                  // posting the form back would overwrite a working credential
                  // with punctuation.
                  hintText: config.hints[field.key],
                  helperText: (config.configured[field.key] ?? false)
                      ? l10n.channelsStored
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.channelsEnabled),
              value: config.enabled,
              onChanged: _busy ? null : (value) => _save(enabled: value),
            ),
            if (config.webhookUrl != null) ...[
              Text(
                l10n.channelsWebhookUrl,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SelectableText(
                config.webhookUrl!,
                style: theme.textTheme.bodySmall,
              ),
              if (!widget.canConfigureWebhook)
                Text(
                  l10n.channelsWebhookManual,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (config.lastCheckedOn != null)
              Text(
                '${l10n.channelsLastChecked}: ${config.lastCheckedOn}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (config.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  config.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.statusColors.danger,
                  ),
                ),
              ),
            if (_lastTest != null &&
                !_lastTest!.ok &&
                _lastTest!.detail != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  _lastTest!.detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.statusColors.danger,
                  ),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                if (widget.canConfigureWebhook) ...[
                  TextButton(
                    key: ValueKey('${config.channel}:removeWebhook'),
                    onPressed: _busy ? null : _removeWebhook,
                    child: Text(l10n.channelsRemoveWebhook),
                  ),
                  TextButton(
                    key: ValueKey('${config.channel}:configureWebhook'),
                    onPressed: _busy ? null : _configureWebhook,
                    child: Text(l10n.channelsConfigureWebhook),
                  ),
                ],
                TextButton(
                  key: ValueKey('${config.channel}:test'),
                  onPressed: _busy ? null : _test,
                  child: Text(l10n.channelsTest),
                ),
                FilledButton(
                  key: ValueKey('${config.channel}:save'),
                  onPressed: _busy ? null : _save,
                  child: Text(l10n.channelsSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the channel's setup amounts to, in one word.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.state, this.test});

  final String state;
  final ChannelTestResult? test;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = context.statusColors;

    // The state the server computed already accounts for the last *real* call,
    // so it is what is shown; a test just run in this session outranks it,
    // because it is newer. Four failures are told apart rather than collapsed
    // into "error": a wrong token and an unreachable webhook are fixed in
    // different places by different people.
    final effective = test == null
        ? state
        : (test!.ok ? ChannelConfig.connected : (test!.code ?? state));

    final (String label, Color color) = switch (effective) {
      ChannelConfig.connected => (l10n.channelsStateConnected, colors.success),
      ChannelConfig.invalidCredentials => (
        l10n.channelsStateInvalid,
        colors.danger,
      ),
      ChannelConfig.webhookError => (
        l10n.channelsStateWebhookError,
        colors.danger,
      ),
      ChannelConfig.providerUnavailable => (
        l10n.channelsStateUnavailable,
        colors.warning,
      ),
      ChannelConfig.forbidden => (l10n.channelsStateForbidden, colors.danger),
      ChannelConfig.rateLimited => (
        l10n.channelsStateRateLimited,
        colors.warning,
      ),
      ChannelConfig.ready => (
        l10n.channelsStateReady,
        theme.colorScheme.onSurfaceVariant,
      ),
      ChannelConfig.disabled => (
        l10n.channelsStateDisabled,
        theme.colorScheme.onSurfaceVariant,
      ),
      _ => (l10n.channelsStateNotConfigured, colors.warning),
    };

    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(color: color),
    );
  }
}

/// Everyone the bots have heard from, and who an administrator says they are.
class _IdentityList extends ConsumerWidget {
  const _IdentityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final identities = ref.watch(channelIdentitiesProvider);

    return identities.when(
      loading: () => const ListSkeleton(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(channelIdentitiesProvider),
      ),
      data: (rows) => rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(l10n.channelsIdentitiesEmpty),
            )
          : Column(
              children: [for (final row in rows) _IdentityTile(identity: row)],
            ),
    );
  }
}

class _IdentityTile extends ConsumerStatefulWidget {
  const _IdentityTile({required this.identity});

  final ChannelIdentity identity;

  @override
  ConsumerState<_IdentityTile> createState() => _IdentityTileState();
}

class _IdentityTileState extends ConsumerState<_IdentityTile> {
  late final _user = TextEditingController(text: widget.identity.user ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(channelIdentitiesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final identity = widget.identity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${identity.channel} · ${identity.externalId}',
              style: theme.textTheme.titleSmall,
            ),
            if (identity.displayName != null)
              Text(
                identity.displayName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: ValueKey('identity:${identity.name}'),
              controller: _user,
              decoration: InputDecoration(
                labelText: l10n.channelsUser,
                helperText: identity.isLinked
                    ? identity.customer
                    : l10n.channelsIdentityUnlinked,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (identity.isLinked)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => ref
                                .read(channelSettingsRepositoryProvider)
                                .unlink(identity.name),
                          ),
                    child: Text(l10n.channelsUnlink),
                  ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref
                              .read(channelSettingsRepositoryProvider)
                              .link(
                                channel: identity.channel,
                                externalId: identity.externalId,
                                user: _user.text.trim(),
                              ),
                        ),
                  child: Text(l10n.channelsLink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
