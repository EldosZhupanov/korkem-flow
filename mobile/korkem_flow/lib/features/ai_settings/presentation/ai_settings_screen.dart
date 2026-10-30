import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/ai_settings/data/ai_settings_repository.dart';
import 'package:korkem_flow/features/ai_settings/domain/ai_provider_config.dart';
import 'package:korkem_flow/features/ai_settings/presentation/widgets/assistant_check_section.dart';
import 'package:korkem_flow/features/ai_settings/presentation/widgets/prompt_breakdown_section.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Which AI answers, and how to connect it.
///
/// The screen exists because "configure AI" is otherwise a Frappe Desk task,
/// and the person who runs a furniture factory should not need one.
///
/// **No key is ever displayed.** The server sends back a mask like
/// `AQ.A••••••••iO5A` — enough to tell two accounts apart, useless to anyone
/// reading over a shoulder — and the field below it is write-only: leaving it
/// blank keeps whatever is stored. That is why changing a model does not
/// require the operator to fetch their key again.
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final providers = ref.watch(aiProvidersProvider);

    return AppScreen(
      title: l10n.aiSettingsTitle,
      subtitle: l10n.aiSettingsSubtitle,
      body: providers.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(aiProvidersProvider),
        ),
        data:
            (
              ({List<AiProviderConfig> providers, String defaultProvider}) data,
            ) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _SecurityNote(text: l10n.aiSettingsKeyNeverLeaves),
                const SizedBox(height: AppSpacing.lg),
                const _Cascade(),
                const SizedBox(height: AppSpacing.lg),
                const PromptBreakdownSection(),
                const SizedBox(height: AppSpacing.lg),
                const AssistantCheckSection(),
                const SizedBox(height: AppSpacing.lg),
                for (final provider in data.providers) ...[
                  _ProviderTile(config: provider),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
      ),
    );
  }
}

/// States plainly where the credential lives.
///
/// Worth a permanent line rather than a one-off toast: an operator about to
/// type a production API key into a phone deserves to know it is not being
/// kept there.
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

class _ProviderTile extends ConsumerStatefulWidget {
  const _ProviderTile({required this.config});

  final AiProviderConfig config;

  @override
  ConsumerState<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends ConsumerState<_ProviderTile> {
  late final _model = TextEditingController(text: widget.config.model ?? '');
  late final _baseUrl = TextEditingController(
    text: widget.config.baseUrl ?? '',
  );
  final _apiKey = TextEditingController();

  bool _busy = false;
  bool _expanded = false;
  ({bool ok, String? code})? _lastTest;

  @override
  void dispose() {
    _model.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    await ref
        .read(aiSettingsRepositoryProvider)
        .save(
          provider: widget.config.provider,
          model: _model.text.trim(),
          baseUrl: _baseUrl.text.trim(),
          // Write-only: an empty field means "keep what is stored", which is
          // what lets this form be submitted without the key in hand.
          apiKey: _apiKey.text,
        );
    _apiKey.clear();
    ref.invalidate(aiProvidersProvider);
  });

  Future<void> _test() => _run(() async {
    final result = await ref
        .read(aiSettingsRepositoryProvider)
        .test(widget.config.provider);
    if (mounted) setState(() => _lastTest = result);
    ref.invalidate(aiProvidersProvider);
  });

  Future<void> _makeDefault() => _run(() async {
    await ref
        .read(aiSettingsRepositoryProvider)
        .setDefault(widget.config.provider, model: _model.text.trim());
    ref.invalidate(aiProvidersProvider);
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
                    config.provider,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (config.isDefault)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Text(
                      l10n.aiSettingsDefault,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.statusColors.success,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: AnimatedRotation(
                    // The chevron the design system already has, turned rather
                    // than swapped for a second glyph nobody has defined.
                    turns: _expanded ? 0.25 : 0,
                    duration: motionOf(context, AppDuration.quick),
                    child: const Icon(AppIcons.forward),
                  ),
                ),
              ],
            ),
            _Status(config: config, lastTest: _lastTest),
            if (_expanded) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _model,
                decoration: InputDecoration(labelText: l10n.aiSettingsModel),
              ),
              if (config.needsBaseUrl) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _baseUrl,
                  decoration: InputDecoration(
                    labelText: l10n.aiSettingsBaseUrl,
                  ),
                ),
              ],
              if (config.needsKey) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _apiKey,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.aiSettingsApiKey,
                    // The mask, never the key. It is a hint rather than a
                    // value so the field stays genuinely empty — a form that
                    // pre-filled bullets and posted them back would overwrite
                    // a working credential with punctuation.
                    hintText: config.maskedKey,
                    helperText: config.hasKey
                        ? l10n.aiSettingsApiKeyStored
                        : null,
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.aiSettingsLocalNoKey,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SectionLabel(l10n.aiSettingsCapabilities),
              _Capabilities(capabilities: config.capabilities),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  if (!config.isDefault && config.configured)
                    TextButton(
                      onPressed: _busy ? null : _makeDefault,
                      child: Text(l10n.aiSettingsMakeDefault),
                    ),
                  TextButton(
                    onPressed: _busy || !config.configured ? null : _test,
                    child: Text(l10n.aiSettingsTest),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(l10n.aiSettingsSave),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.config, required this.lastTest});

  final AiProviderConfig config;
  final ({bool ok, String? code})? lastTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = context.statusColors;

    // A test just run in this session outranks whatever the server last
    // recorded — the operator is watching, and the fresher fact is the one
    // they are trying to establish.
    final ok = lastTest?.ok ?? config.lastTestOk;
    final tested = lastTest != null || config.lastTestOk;

    final (text, tint) = switch ((config.configured, tested, ok)) {
      (false, _, _) => (
        l10n.aiSettingsNotConfigured,
        theme.colorScheme.onSurfaceVariant,
      ),
      (true, true, true) => (l10n.aiSettingsConnected, colors.success),
      (true, true, false) => (l10n.aiSettingsTestFailed, colors.danger),
      _ => (config.model ?? '', theme.colorScheme.onSurfaceVariant),
    };

    return Row(
      children: [
        if (config.model != null && config.model!.isNotEmpty) ...[
          Text(
            config.model!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(text, style: theme.textTheme.labelSmall?.copyWith(color: tint)),
      ],
    );
  }
}

/// Capabilities as three states, never two.
///
/// `unknown` is rendered as itself rather than collapsed into "no". Ollama's
/// tool support is genuinely unknown — it depends on the model loaded — and an
/// operator choosing a provider deserves to see that distinction rather than a
/// confident wrong answer.
class _Capabilities extends StatelessWidget {
  const _Capabilities({required this.capabilities});

  final Map<String, String> capabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.statusColors;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final entry in capabilities.entries)
          Text(
            '${entry.key.replaceFirst('supports_', '')}: ${entry.value}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: switch (entry.value) {
                'yes' => colors.success,
                'no' => theme.colorScheme.onSurfaceVariant,
                _ => colors.warning,
              },
            ),
          ),
      ],
    );
  }
}

/// Порядок, в котором спрашиваются модели.
///
/// Список настроенных провайдеров не отвечает на вопрос, который на самом деле
/// у владельца: «кто ответит, когда первая кончится». Включённый провайдер и
/// работающий выглядят в списке одинаково, а разницу человек узнаёт в тот
/// момент, когда ассистент замолчал.
class _Cascade extends ConsumerWidget {
  const _Cascade();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cascade = ref.watch(aiCascadeProvider);
    final steps = cascade.value ?? const <AiCascadeStep>[];
    if (steps.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.aiCascadeTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.aiCascadeSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    '${step.position}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.provider, style: theme.textTheme.bodyMedium),
                        Text(
                          step.model,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // Причина отказа — словами провайдера. Наш пересказ
                        // «что-то пошло не так» здесь не помогает никому.
                        if (!step.lastOk && step.lastError.isNotEmpty)
                          Text(
                            step.lastError,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.statusColors.danger,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (step.free)
                    StatusChip(
                      label: l10n.aiCascadeFree,
                      intent: StatusIntent.success,
                      compact: true,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
