import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/integration_settings/data/integration_settings_repository.dart';
import 'package:korkem_flow/features/integration_settings/domain/integration_config.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen for managing TrustMe and Kaspi Pay API keys and webhook secrets.
///
/// **No secrets are ever displayed.** The server answers only whether a key is
/// configured (`configured: true/false`), so every credential field starts
/// empty: leaving it blank keeps whatever is stored on the server.
///
/// **Clearing a key requires confirmation.** Deleting a key disables payments
/// or contract signing, which must be an intentional, confirmed action.
class IntegrationSettingsScreen extends ConsumerWidget {
  const IntegrationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(integrationStatusProvider);

    return AppScreen(
      title: l10n.integrationsTitle,
      subtitle: l10n.integrationsSubtitle,
      body: status.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(integrationStatusProvider),
        ),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ReadableWidth(
            child: Entrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SecurityNote(text: l10n.integrationsSecurityNote),
                  const SizedBox(height: AppSpacing.lg),
                  SectionLabel(l10n.trustmeTitle),
                  _TrustMeCard(config: data.trustme),
                  const SizedBox(height: AppSpacing.xl),
                  SectionLabel(l10n.kaspiTitle),
                  _KaspiCard(config: data.kaspi),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.info,
            size: AppIconSize.small,
            color: theme.colorScheme.primary,
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
      ),
    );
  }
}

class _TrustMeCard extends ConsumerStatefulWidget {
  const _TrustMeCard({required this.config});

  final TrustMeConfig config;

  @override
  ConsumerState<_TrustMeCard> createState() => _TrustMeCardState();
}

class _TrustMeCardState extends ConsumerState<_TrustMeCard> {
  late bool _enabled;
  late final TextEditingController _binController;
  late final TextEditingController _apiTokenController;
  late final TextEditingController _webhookSecretController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.config.enabled;
    _binController = TextEditingController(
      text: widget.config.organizationBin ?? '',
    );
    _apiTokenController = TextEditingController();
    _webhookSecretController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _TrustMeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _enabled = widget.config.enabled;
      if (_binController.text != (widget.config.organizationBin ?? '')) {
        _binController.text = widget.config.organizationBin ?? '';
      }
    }
  }

  @override
  void dispose() {
    _binController.dispose();
    _apiTokenController.dispose();
    _webhookSecretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(integrationSettingsRepositoryProvider);
      await repo.saveTrustMe(
        enabled: _enabled,
        organizationBin: _binController.text,
        apiToken: _apiTokenController.text,
        webhookSecret: _webhookSecretController.text,
      );
      _apiTokenController.clear();
      _webhookSecretController.clear();
      ref.invalidate(integrationStatusProvider);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showDone(
          l10n.integrationSavedSuccess,
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFailure(
          e,
          AppLocalizations.of(context),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmClearSecret({
    required String field,
    required String secretName,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.integrationClearDialogTitle),
        content: Text(
          l10n.integrationClearDialogMessage(secretName, l10n.trustmeTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.integrationClearSecretAction),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(integrationSettingsRepositoryProvider);
        await repo.clearSecret(provider: 'trustme', field: field);
        ref.invalidate(integrationStatusProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showDone(
            l10n.integrationClearSuccess,
          );
        }
      } on Object catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showFailure(
            e,
            AppLocalizations.of(context),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final config = widget.config;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.trustmeSubtitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              l10n.integrationEnableToggle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: _enabled,
            onChanged: (val) => setState(() => _enabled = val),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _binController,
            decoration: InputDecoration(
              labelText: l10n.trustmeBinLabel,
              hintText: l10n.trustmeBinHint,
              prefixIcon: const Icon(AppIcons.customer),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SecretInputField(
            label: l10n.trustmeApiTokenLabel,
            hint: l10n.trustmeApiTokenHint,
            controller: _apiTokenController,
            isConfigured: config.isApiTokenConfigured,
            onClearSecret: () => _confirmClearSecret(
              field: 'api_token',
              secretName: l10n.trustmeApiTokenLabel,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SecretInputField(
            label: l10n.trustmeWebhookSecretLabel,
            hint: l10n.trustmeWebhookSecretHint,
            controller: _webhookSecretController,
            isConfigured: config.isWebhookSecretConfigured,
            onClearSecret: () => _confirmClearSecret(
              field: 'webhook_secret',
              secretName: l10n.trustmeWebhookSecretLabel,
            ),
          ),
          if (config.lastStatus != null || config.lastError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _StatusBox(
              lastStatus: config.lastStatus,
              lastError: config.lastError,
              lastCheckedOn: config.lastCheckedOn,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: AppIconSize.small,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.focus,
                    ),
                  )
                : const Icon(AppIcons.check),
            label: Text(l10n.integrationSaveAction),
          ),
        ],
      ),
    );
  }
}

class _KaspiCard extends ConsumerStatefulWidget {
  const _KaspiCard({required this.config});

  final KaspiConfig config;

  @override
  ConsumerState<_KaspiCard> createState() => _KaspiCardState();
}

class _KaspiCardState extends ConsumerState<_KaspiCard> {
  late bool _enabled;
  late final TextEditingController _merchantIdController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _webhookSecretController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.config.enabled;
    _merchantIdController = TextEditingController(
      text: widget.config.merchantId ?? '',
    );
    _apiKeyController = TextEditingController();
    _webhookSecretController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _KaspiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _enabled = widget.config.enabled;
      if (_merchantIdController.text != (widget.config.merchantId ?? '')) {
        _merchantIdController.text = widget.config.merchantId ?? '';
      }
    }
  }

  @override
  void dispose() {
    _merchantIdController.dispose();
    _apiKeyController.dispose();
    _webhookSecretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(integrationSettingsRepositoryProvider);
      await repo.saveKaspi(
        enabled: _enabled,
        merchantId: _merchantIdController.text,
        apiKey: _apiKeyController.text,
        webhookSecret: _webhookSecretController.text,
      );
      _apiKeyController.clear();
      _webhookSecretController.clear();
      ref.invalidate(integrationStatusProvider);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showDone(
          l10n.integrationSavedSuccess,
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFailure(
          e,
          AppLocalizations.of(context),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmClearSecret({
    required String field,
    required String secretName,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.integrationClearDialogTitle),
        content: Text(
          l10n.integrationClearDialogMessage(secretName, l10n.kaspiTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.integrationClearSecretAction),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(integrationSettingsRepositoryProvider);
        await repo.clearSecret(provider: 'kaspi', field: field);
        ref.invalidate(integrationStatusProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showDone(
            l10n.integrationClearSuccess,
          );
        }
      } on Object catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showFailure(
            e,
            AppLocalizations.of(context),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final config = widget.config;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.kaspiSubtitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              l10n.integrationEnableToggle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: _enabled,
            onChanged: (val) => setState(() => _enabled = val),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _merchantIdController,
            decoration: InputDecoration(
              labelText: l10n.kaspiMerchantIdLabel,
              hintText: l10n.kaspiMerchantIdHint,
              prefixIcon: const Icon(AppIcons.quote),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SecretInputField(
            label: l10n.kaspiApiKeyLabel,
            hint: l10n.kaspiApiKeyHint,
            controller: _apiKeyController,
            isConfigured: config.isApiKeyConfigured,
            onClearSecret: () => _confirmClearSecret(
              field: 'api_key',
              secretName: l10n.kaspiApiKeyLabel,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SecretInputField(
            label: l10n.kaspiWebhookSecretLabel,
            hint: l10n.kaspiWebhookSecretHint,
            controller: _webhookSecretController,
            isConfigured: config.isWebhookSecretConfigured,
            onClearSecret: () => _confirmClearSecret(
              field: 'webhook_secret',
              secretName: l10n.kaspiWebhookSecretLabel,
            ),
          ),
          if (config.lastStatus != null || config.lastError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _StatusBox(
              lastStatus: config.lastStatus,
              lastError: config.lastError,
              lastCheckedOn: config.lastCheckedOn,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: AppIconSize.small,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.focus,
                    ),
                  )
                : const Icon(AppIcons.check),
            label: Text(l10n.integrationSaveAction),
          ),
        ],
      ),
    );
  }
}

class _SecretInputField extends StatefulWidget {
  const _SecretInputField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.isConfigured,
    required this.onClearSecret,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isConfigured;
  final VoidCallback onClearSecret;

  @override
  State<_SecretInputField> createState() => _SecretInputFieldState();
}

class _SecretInputFieldState extends State<_SecretInputField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusChip(
              label: widget.isConfigured
                  ? l10n.integrationSecretConfigured
                  : l10n.integrationSecretNotConfigured,
              intent: widget.isConfigured
                  ? StatusIntent.success
                  : StatusIntent.neutral,
            ),
            if (widget.isConfigured) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(
                  AppIcons.delete,
                  size: AppIconSize.dense,
                ),
                color: theme.colorScheme.error,
                tooltip: l10n.integrationClearSecretAction,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onClearSecret,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(AppIcons.noAccess),
            suffixIcon: IconButton(
              icon: Icon(
                _obscured ? AppIcons.hidden : AppIcons.visible,
                size: AppIconSize.small,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    this.lastStatus,
    this.lastError,
    this.lastCheckedOn,
  });

  final String? lastStatus;
  final String? lastError;
  final String? lastCheckedOn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasError = lastError != null && lastError!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: hasError
            ? theme.colorScheme.errorContainer.withValues(
                alpha: AppTint.surface,
              )
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: hasError
              ? theme.colorScheme.error.withValues(
                  alpha: AppTint.ornamentOnDark,
                )
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lastStatus != null) ...[
            Text(
              l10n.integrationLastStatusLabel(lastStatus!),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          if (hasError) ...[
            Text(
              l10n.integrationLastErrorLabel(lastError!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          if (lastCheckedOn != null) ...[
            Text(
              l10n.integrationLastCheckedLabel(lastCheckedOn!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
