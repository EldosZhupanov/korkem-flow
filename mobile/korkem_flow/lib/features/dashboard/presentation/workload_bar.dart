import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// How much of your own workload is late.
///
/// This is the only chart on the dashboard, and it exists because it is the
/// only place the data is genuinely a *ratio*. The endpoint returns six
/// counts and no history, so a line or a bar chart across them would be six
/// unrelated numbers drawn as if they were a trend — decoration standing in
/// for information, which is worse than no chart.
///
/// Overdue tasks are a subset of open tasks, so the proportion is real and
/// says something a pair of numbers does not: two overdue out of three is a
/// bad week, two out of forty is a Tuesday.
///
/// It renders nothing when there is nothing to say — no tasks, or a figure the
/// signed-in role may not see. An empty track under a zero is a chart of
/// nothing.
class WorkloadBar extends StatelessWidget {
  const WorkloadBar({required this.total, required this.overdue, super.key});

  final int? total;
  final int? overdue;

  @override
  Widget build(BuildContext context) {
    final open = total;
    final late = overdue;
    if (open == null || late == null || open <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final danger = context.statusColors.resolve(StatusIntent.danger);
    final fraction = (late / open).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: TweenAnimationBuilder<double>(
                // Grows from empty to its share, on the same curve a KPI
                // figure counts up on, so the two read as one arrival rather
                // than as a number and then a bar.
                tween: Tween<double>(begin: 0, end: fraction),
                duration: motionOf(context, AppDuration.count),
                curve: AppCurves.enter,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: AppStroke.focus,
                  color: danger,
                  backgroundColor: danger.withValues(alpha: AppTint.surface),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // (overdue, total), in that order — the placeholders read
              // `{overdue} of {total}` and passing them the other way round
              // produced "7 of 2 are overdue", which is nonsense that still
              // renders and still sounds like a sentence.
              l10n.dashboardWorkload(late, open),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
