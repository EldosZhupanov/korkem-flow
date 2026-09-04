import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/events/application/events_controller.dart';
import 'package:korkem_flow/features/events/presentation/widgets/events_feed.dart';
import 'package:korkem_flow/features/today/data/today_repository.dart';
import 'package:korkem_flow/features/today/domain/today_summary.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen answering the owner's morning question: "What is important today?"
///
/// Displays discrete key metrics with large numbers. Zero-value rows are
/// omitted. All calculations belong strictly to the server.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).languageCode;
    final formattedDate = DateFormat('d MMMM', locale).format(now);
    final headerTitle = l10n.todayHeaderDate(formattedDate);

    final summaryAsync = ref.watch(todaySummaryProvider);

    return AppScreen(
      title: headerTitle,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<dynamic>([
            ref.refresh(todaySummaryProvider.future),
            ref.read(eventsControllerProvider.notifier).refresh(),
          ]);
        },
        // Лента идёт своим состоянием, а не внутри состояния сводки. Держать
        // её там значило бы прятать «срок послезавтра, работа не начата» на
        // то время, пока считается число просрочек, — а если сводка упала, то
        // и вовсе. Тревога не должна зависеть от соседнего запроса.
        child: ReadableWidth(
          child: summaryAsync.when(
            loading: () => const _TodayLoading(),
            error: (error, _) {
              final errorMessage = error is FrappeException
                  ? error.message
                  : error is Exception
                  ? error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')
                  : error.toString();
              return _TodaySummaryFailed(
                error: ServerFailure(errorMessage),
                onRetry: () => ref.refresh(todaySummaryProvider.future),
              );
            },
            data: (summary) {
              final eventsState = ref.watch(eventsControllerProvider);
              final hasEvents =
                  eventsState.hasValue && eventsState.value!.isNotEmpty;

              if (summary.isAllClear && !hasEvents) {
                return _AllClearState(
                  title: l10n.todayEmptyStateTitle,
                  description: l10n.todayEmptyStateDescription,
                );
              }
              return _ImportantMetricsList(
                summary: summary,
                headerTitle: headerTitle,
                hasEvents: hasEvents,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Пока сводка считается, лента событий уже может что-то показать.
class _TodayLoading extends StatelessWidget {
  const _TodayLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        EventsFeed(),
        SizedBox(height: AppSpacing.md),
        ListSkeleton(),
      ],
    );
  }
}

/// Сводка не сосчиталась — это не повод скрывать то, что уже известно.
class _TodaySummaryFailed extends StatelessWidget {
  const _TodaySummaryFailed({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const EventsFeed(),
        const SizedBox(height: AppSpacing.md),
        ErrorView(error: error, onRetry: onRetry),
      ],
    );
  }
}

class _ImportantMetricsList extends StatelessWidget {
  const _ImportantMetricsList({
    required this.summary,
    required this.headerTitle,
    this.hasEvents = false,
  });

  final TodaySummary summary;
  final String headerTitle;
  final bool hasEvents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final money = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );

    final operationalRows = <Widget>[
      if (summary.overdueOrders > 0)
        _MetricRow(
          label: l10n.todayImportantOverdue,
          valueText: '${summary.overdueOrders}',
          unit: l10n.todayOrdersCountUnit(summary.overdueOrders),
          intent: StatusIntent.danger,
          onTap: () =>
              unawaited(context.push('${Routes.orders}?filter=overdue')),
        ),
      if (summary.dueTodayOrders > 0)
        _MetricRow(
          label: l10n.todayImportantDueToday,
          valueText: '${summary.dueTodayOrders}',
          unit: l10n.todayOrdersCountUnit(summary.dueTodayOrders),
          intent: StatusIntent.warning,
          onTap: () =>
              unawaited(context.push('${Routes.orders}?filter=due_today')),
        ),
      if (summary.dueThisWeekOrders > 0)
        _MetricRow(
          label: l10n.todayImportantDueThisWeek,
          valueText: '${summary.dueThisWeekOrders}',
          unit: l10n.todayOrdersCountUnit(summary.dueThisWeekOrders),
          intent: StatusIntent.neutral,
          onTap: () =>
              unawaited(context.push('${Routes.orders}?filter=due_this_week')),
        ),
      if (summary.unpaidAmount > 0)
        _MetricRow(
          label: l10n.todayImportantUnpaid,
          valueText: money.format(summary.unpaidAmount),
          intent: StatusIntent.danger,
          onTap: () =>
              unawaited(context.push('${Routes.orders}?filter=unpaid')),
        ),
      if (summary.materialDeficitCount > 0)
        _MetricRow(
          label: l10n.todayImportantMaterialDeficit,
          valueText: '${summary.materialDeficitCount}',
          unit: l10n.todayPositionsCountUnit(summary.materialDeficitCount),
          intent: StatusIntent.danger,
          onTap: () =>
              unawaited(context.push('${Routes.items}?filter=deficit')),
        ),
      if (summary.installationsToday > 0)
        _MetricRow(
          label: l10n.todayImportantInstallationToday,
          valueText: '${summary.installationsToday}',
          intent: StatusIntent.warning,
          onTap: () => unawaited(context.push('${Routes.tasks}?filter=today')),
        ),
    ];

    final approvalRows = <Widget>[
      if (summary.pendingApprovals > 0)
        _MetricRow(
          label: l10n.todayImportantRequiresDecision,
          valueText: '${summary.pendingApprovals}',
          unit: l10n.todayApprovalsCountUnit(summary.pendingApprovals),
          intent: StatusIntent.warning,
          onTap: () => unawaited(context.push(Routes.approvals)),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          headerTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (hasEvents) ...[
          const EventsFeed(),
          const SizedBox(height: AppSpacing.md),
        ],

        for (final row in operationalRows) ...[
          row,
          const SizedBox(height: AppSpacing.sm),
        ],

        if (operationalRows.isNotEmpty && approvalRows.isNotEmpty)
          const SizedBox(height: AppSpacing.md),

        for (final row in approvalRows) ...[
          row,
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.valueText,
    required this.onTap,
    this.unit,
    this.intent,
  });

  final String label;
  final String valueText;
  final String? unit;
  final StatusIntent? intent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueText,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (unit != null && unit!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  unit!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            AppIcons.forward,
            size: AppIconSize.dense,
            color: theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}

class _AllClearState extends StatelessWidget {
  const _AllClearState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.success,
              size: AppIconSize.illustration,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
