import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/ai_settings/data/ai_settings_repository.dart';
import 'package:korkem_flow/features/ai_settings/domain/prompt_breakdown.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Formats an integer with whitespace thousand separators (e.g. 14 300).
String formatTokenCount(int number) {
  final s = number.toString();
  final buffer = StringBuffer();
  final len = s.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Displays the token footprint of the last prompt and weekly usage metrics.
class PromptBreakdownSection extends ConsumerWidget {
  const PromptBreakdownSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reportAsync = ref.watch(aiPromptBreakdownProvider);

    return reportAsync.when(
      loading: () => const AppCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      error: (error, _) {
        final message = error is FrappeException ? error.message : '$error';
        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
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
                  onPressed: () => ref.invalidate(aiPromptBreakdownProvider),
                ),
              ],
            ),
          ),
        );
      },
      data: (report) {
        if (report.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.promptBreakdownTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        AppIcons.info,
                        size: AppIconSize.dense,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.promptBreakdownEmpty,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.promptBreakdownEmptyBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final lastPrompt = report.lastPrompt;
        final weekly = report.weeklySummary;
        final heaviestId = lastPrompt?.heaviestItemId;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lastPrompt != null && lastPrompt.items.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.promptBreakdownTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      l10n.promptBreakdownTokens(
                        formatTokenCount(lastPrompt.totalTokens),
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (final item in lastPrompt.items) ...[
                  _BreakdownItemRow(
                    item: item,
                    isHeaviest: item.id == heaviestId,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
              if (weekly != null && weekly.totalTurns > 0) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: AppStroke.hairline),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.aiWeeklySummaryTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(
                  label: l10n.aiWeeklyTurns,
                  value: formatTokenCount(weekly.totalTurns),
                ),
                _SummaryRow(
                  label: l10n.aiWeeklyPrimaryModel,
                  value:
                      '${formatTokenCount(weekly.primaryModelTurns)} '
                      '(${weekly.primaryRatePercent}%)',
                ),
                _SummaryRow(
                  label: l10n.aiWeeklyReserve,
                  value:
                      '${formatTokenCount(weekly.reserveTurns)} '
                      '(${weekly.reserveRatePercent}%)',
                ),
                _SummaryRow(
                  label: l10n.aiWeeklyAvgDuration,
                  value: l10n.aiWeeklySeconds(
                    weekly.averageDurationSeconds.toStringAsFixed(1),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownItemRow extends StatelessWidget {
  const _BreakdownItemRow({
    required this.item,
    required this.isHeaviest,
  });

  final TokenBreakdownItem item;
  final bool isHeaviest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.displayLabel(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isHeaviest ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            formatTokenCount(item.tokens),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isHeaviest ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isHeaviest) ...[
            const SizedBox(width: AppSpacing.sm),
            StatusChip(
              label: l10n.promptBreakdownHeaviest,
              intent: StatusIntent.warning,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
