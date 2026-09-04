import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/features/ai_settings/data/assistant_check_repository.dart';
import 'package:korkem_flow/features/ai_settings/domain/assistant_check.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Section in AI Settings displaying assistant quality scenarios run results.
class AssistantCheckSection extends ConsumerWidget {
  const AssistantCheckSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reportAsync = ref.watch(assistantCheckControllerProvider);

    final report = reportAsync.value;
    // Running is what the report says, not what the future is doing: loading
    // the previous result is also waiting, and calling that «идёт проверка»
    // claims a run nobody started.
    // `AsyncError` keeps the previous value, so the report can still say
    // «running» after the run has already failed. A progress bar next to an
    // error message would spin for as long as the screen stays open.
    final isRunning = !reportAsync.hasError && (report?.isRunning ?? false);
    final isBusy = isRunning || reportAsync.isLoading;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.assistantCheckTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: isBusy
                      ? null
                      : () => ref
                            .read(assistantCheckControllerProvider.notifier)
                            .run(),
                  child: isRunning
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: AppIconSize.dense,
                              height: AppIconSize.dense,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: AppStroke.focus,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(l10n.assistantCheckRunning),
                          ],
                        )
                      : Text(l10n.assistantCheckRunButton),
                ),
              ],
            ),
            if (isRunning) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            if (reportAsync.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorBox(
                error: reportAsync.error!,
                onRetry: () =>
                    ref.read(assistantCheckControllerProvider.notifier).run(),
              ),
            ] else if (report != null && report.hasRun) ...[
              const SizedBox(height: AppSpacing.md),
              for (final scenario in report.scenarios) ...[
                _ScenarioRow(scenario: scenario),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              _FooterRow(report: report),
            ] else if (!isRunning) ...[
              const SizedBox(height: AppSpacing.md),
              _NotRunExplanation(
                title: l10n.assistantCheckNotRunTitle,
                description: l10n.assistantCheckNotRunDescription,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotRunExplanation extends StatelessWidget {
  const _NotRunExplanation({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({required this.scenario});

  final CheckScenario scenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusColors = context.statusColors;

    final durationText = scenario.durationSeconds != null
        ? l10n.assistantCheckDurationSeconds(
            scenario.durationSeconds!.toStringAsFixed(1),
          )
        : null;

    final failureReason = scenario.failureReason;
    final failureText = failureReason != null
        ? (failureReason.startsWith('—') ? failureReason : '— $failureReason')
        : null;

    return Row(
      children: [
        Icon(
          scenario.passed ? AppIcons.check : AppIcons.close,
          size: AppIconSize.normal,
          color: scenario.passed
              ? statusColors.success
              : theme.colorScheme.error,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            scenario.name,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (scenario.passed && durationText != null)
          Text(
            durationText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        else if (!scenario.passed && failureText != null)
          Flexible(
            child: Text(
              failureText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.report});

  final AssistantCheckReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final timeString = report.lastRunAt != null
        ? DateFormat('HH:mm').format(report.lastRunAt!)
        : null;

    return Row(
      children: [
        Text(
          l10n.assistantCheckPassedSummary(
            report.passedCount,
            report.totalCount,
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (timeString != null)
          Text(
            l10n.assistantCheckLastRun(timeString),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final err = error;
    final message = err is FrappeException ? err.message : err.toString();

    return Row(
      children: [
        Icon(
          AppIcons.danger,
          color: theme.colorScheme.error,
          size: AppIconSize.normal,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        TextButton.icon(
          icon: const Icon(AppIcons.refresh),
          label: Text(l10n.actionRetry),
          onPressed: onRetry,
        ),
      ],
    );
  }
}
