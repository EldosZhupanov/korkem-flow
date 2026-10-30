import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/motion/animated_counter.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/kpi_tile.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_illustration.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/admin_stats/application/admin_stats_controller.dart';
import 'package:korkem_flow/features/admin_stats/domain/admin_stats.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen proving whether the factory owner can avoid hiring an
/// administrator.
///
/// Displays verifiable outcome counts rather than vanity metrics:
/// - Stale unhandled requests (>24h unassigned) — the primary metric.
/// - Handed-over, converted, and dismissed requests.
/// - Clear hiring decision summary.
class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(adminStatsProvider);
    final selectedDays = ref.watch(adminStatsDaysProvider);

    return AppScreen(
      title: l10n.adminStatsTitle,
      subtitle: l10n.adminStatsSubtitle,
      actions: [
        IconButton(
          tooltip: l10n.adminStatsRetry,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(adminStatsProvider),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          await ref.read(adminStatsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period Switcher
                _PeriodSelector(
                  selectedDays: selectedDays,
                  onChanged: (days) {
                    ref.read(adminStatsDaysProvider.notifier).selectDays(days);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Content
                statsAsync.when(
                  data: (stats) => _AdminStatsContent(stats: stats),
                  loading: () => const _AdminStatsLoading(),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(adminStatsProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedDays,
    required this.onChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SegmentedButton<int>(
      segments: [
        ButtonSegment<int>(
          value: 7,
          label: Text(l10n.adminStatsPeriodWeek),
        ),
        ButtonSegment<int>(
          value: 30,
          label: Text(l10n.adminStatsPeriodMonth),
        ),
        ButtonSegment<int>(
          value: 90,
          label: Text(l10n.adminStatsPeriodQuarter),
        ),
      ],
      selected: {selectedDays},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }
}

class _AdminStatsContent extends StatelessWidget {
  const _AdminStatsContent({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (stats.isEmpty) {
      return Entrance(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StateIllustration(
                  icon: AppIcons.empty,
                  dense: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.adminStatsEmptyTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.adminStatsEmptyMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Hero Metric: Stale (>24h unassigned)
          _StaleHeroBanner(stats: stats),
          const SizedBox(height: AppSpacing.xl),

          // Funnel & Outcome Ledger
          SectionLabel(l10n.dashboardMyWork),
          const SizedBox(height: AppSpacing.sm),
          _FunnelGrid(stats: stats),
          const SizedBox(height: AppSpacing.xl),

          // Decision Summary Box
          _DecisionSummaryCard(stats: stats),
        ],
      ),
    );
  }
}

class _StaleHeroBanner extends StatelessWidget {
  const _StaleHeroBanner({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasStale = stats.stale > 0;

    final containerColor = hasStale
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final borderColor = hasStale
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final onContainerColor = hasStale
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: borderColor,
          width: AppStroke.focus,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasStale ? AppIcons.danger : AppIcons.success,
                color: onContainerColor,
                size: AppIconSize.normal,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasStale
                      ? l10n.adminStatsStaleHeroLabel
                      : l10n.adminStatsZeroStaleHeroLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: onContainerColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasStale) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedCounter(
                  value: stats.stale,
                  placeholder: '—',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.adminStatsStaleHeroText(stats.stale),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onContainerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              l10n.adminStatsZeroStaleHeroText(stats.days),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: onContainerColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.adminStatsZeroStaleHeroSub,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onContainerColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FunnelGrid extends StatelessWidget {
  const _FunnelGrid({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tileHeight = KpiTile.heightFor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.compact;

        if (isWide) {
          return SizedBox(
            height: tileHeight,
            child: Row(
              children: [
                Expanded(
                  child: KpiTile(
                    label: l10n.adminStatsCaught,
                    value: stats.caught,
                    icon: AppIcons.conversation,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: KpiTile(
                    label: l10n.adminStatsHandedOver,
                    value: stats.handedOver,
                    icon: AppIcons.task,
                    intent: StatusIntent.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: KpiTile(
                    label: l10n.adminStatsConverted,
                    value: stats.converted,
                    icon: AppIcons.deal,
                    intent: StatusIntent.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: KpiTile(
                    label: l10n.adminStatsDismissed,
                    value: stats.dismissed,
                    icon: AppIcons.neutral,
                    intent: StatusIntent.neutral,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: tileHeight,
              child: Row(
                children: [
                  Expanded(
                    child: KpiTile(
                      label: l10n.adminStatsCaught,
                      value: stats.caught,
                      icon: AppIcons.conversation,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: KpiTile(
                      label: l10n.adminStatsHandedOver,
                      value: stats.handedOver,
                      icon: AppIcons.task,
                      intent: StatusIntent.info,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: tileHeight,
              child: Row(
                children: [
                  Expanded(
                    child: KpiTile(
                      label: l10n.adminStatsConverted,
                      value: stats.converted,
                      icon: AppIcons.deal,
                      intent: StatusIntent.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: KpiTile(
                      label: l10n.adminStatsDismissed,
                      value: stats.dismissed,
                      icon: AppIcons.neutral,
                      intent: StatusIntent.neutral,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DecisionSummaryCard extends StatelessWidget {
  const _DecisionSummaryCard({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.info,
                size: AppIconSize.small,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.adminStatsSummaryTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.adminStatsSummaryText(
              stats.caught,
              stats.converted,
              stats.stale,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatsLoading extends StatelessWidget {
  const _AdminStatsLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: AppPlaceholder.metricHeight),
        ListSkeleton(rows: 3),
      ],
    );
  }
}
