import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/kpi_tile.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_destinations.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/dashboard/application/dashboard_controller.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:korkem_flow/features/dashboard/presentation/attention_hero.dart';
import 'package:korkem_flow/features/dashboard/presentation/workload_bar.dart';
import 'package:korkem_flow/features/notifications/application/notifications_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The home screen: six numbers and a short list of what to do first.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(dashboardControllerProvider);

    return AppScreen(
      title: l10n.navDashboard,
      actions: [
        IconButton(
          icon: Badge.count(
            // Hidden at zero rather than showing a "0" badge, which reads as
            // a notification in itself.
            count: ref.watch(unreadNotificationsProvider).value ?? 0,
            isLabelVisible:
                (ref.watch(unreadNotificationsProvider).value ?? 0) > 0,
            child: const Icon(AppIcons.notification),
          ),
          tooltip: l10n.navNotifications,
          onPressed: () => context.push(Routes.notifications),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
        child: switch (state) {
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
          ),
          // Loading renders the real layout with placeholder tiles rather
          // than a spinner, so nothing jumps when the numbers land.
          AsyncValue(:final value) => _Body(
            summary: value,
            isLoading: state.isLoading,
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.isLoading});

  final DashboardSummary? summary;
  final bool isLoading;

  int? _metric(String key) => summary?[key];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final attention = summary?.attention ?? const <AttentionItem>[];
    final overdue = _metric(DashboardSummary.overdueTasks);
    final pending = _metric(DashboardSummary.pendingActions);
    final needsYou = (overdue ?? 0) + (pending ?? 0) > 0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // What needs you comes first. The screen used to open with six equal
        // tiles and put the actionable list below them, so the two facts that
        // actually stop work — an overdue task, a decision an agent is blocked
        // on — were the same size as a lead count nobody acts on before lunch,
        // and sat further down the page than it.
        if (isLoading)
          const ListSkeleton(rows: 1)
        else if (needsYou)
          AttentionHero(
            overdue: overdue,
            pending: pending,
            onOpen: () => _openQueue(context, pending: pending),
          )
        else
          SuccessView(
            // Dense: this shares the screen with the metrics below rather than
            // owning it, and at full size the mark pushes its own headline
            // past the bottom of the viewport.
            dense: true,
            title: l10n.dashboardAllClear,
            message: l10n.dashboardAllClearBody,
          ),

        if (!isLoading && attention.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final item in attention)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _AttentionCard(item: item),
            ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // Grouped rather than gridded. Six metrics in one undifferentiated
        // block make the reader do the sorting; three named pairs answer three
        // separate questions — how am I doing, how is the pipeline, what is on
        // the floor.
        _MetricGroup(
          label: l10n.dashboardMyWork,
          isLoading: isLoading,
          summary: summary,
          metrics: [
            _Metric(
              DashboardSummary.myOpenTasks,
              l10n.metricMyOpenTasks,
              AppIcons.task,
            ),
            _Metric(
              DashboardSummary.overdueTasks,
              l10n.metricOverdueTasks,
              AppIcons.schedule,
              intent: StatusIntent.danger,
            ),
          ],
          footer: WorkloadBar(
            total: _metric(DashboardSummary.myOpenTasks),
            overdue: overdue,
          ),
        ),

        _MetricGroup(
          label: l10n.navSales,
          isLoading: isLoading,
          summary: summary,
          metrics: [
            _Metric(
              DashboardSummary.openDeals,
              l10n.metricOpenDeals,
              AppIcons.deal,
            ),
            _Metric(
              DashboardSummary.openLeads,
              l10n.metricOpenLeads,
              AppIcons.lead,
            ),
          ],
        ),

        _MetricGroup(
          label: l10n.navProduction,
          isLoading: isLoading,
          summary: summary,
          metrics: [
            _Metric(
              DashboardSummary.workOrdersInProgress,
              l10n.metricWorkOrders,
              AppIcons.workOrder,
              route: Routes.production,
            ),
            _Metric(
              DashboardSummary.pendingActions,
              l10n.metricPendingActions,
              AppIcons.approval,
              intent: StatusIntent.warning,
              route: Routes.approvals,
            ),
          ],
        ),
      ],
    );
  }

  /// Opens whichever queue the headline is mostly about. Someone tapping "5
  /// need you" wants the five, and approvals is the half with a decision
  /// waiting rather than a deadline already missed.
  void _openQueue(BuildContext context, {required int? pending}) {
    if ((pending ?? 0) > 0) {
      unawaited(context.push<void>(Routes.approvals));
    } else {
      StatefulNavigationShell.of(context).goBranch(branchIndexOf(Routes.tasks));
    }
  }
}

/// One named pair of metrics, with an optional line of context beneath.
class _MetricGroup extends StatelessWidget {
  const _MetricGroup({
    required this.label,
    required this.metrics,
    required this.summary,
    required this.isLoading,
    this.footer,
  });

  final String label;
  final List<_Metric> metrics;
  final DashboardSummary? summary;
  final bool isLoading;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          SizedBox(
            height: KpiTile.heightFor(context),
            child: Row(
              children: [
                for (final (index, metric) in metrics.indexed) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: KpiTile(
                      label: metric.label,
                      icon: metric.icon,
                      intent: metric.intent,
                      isLoading: isLoading,
                      value: summary?[metric.key],
                      onTap: metric.route == null
                          ? null
                          : () => unawaited(context.push<void>(metric.route!)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (footer != null && !isLoading) footer!,
        ],
      ),
    );
  }
}

@immutable
class _Metric {
  const _Metric(this.key, this.label, this.icon, {this.intent, this.route});

  final String key;
  final String label;
  final IconData icon;
  final StatusIntent? intent;

  /// Where the tile leads. A metric with no screen behind it is not
  /// tappable — a tile that looks interactive and does nothing is worse.
  final String? route;
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item});

  final AttentionItem item;

  /// Where the row leads.
  ///
  /// The screen that lists this kind of work, not the record itself: neither a
  /// pending action nor a task has a detail screen in this app, and inventing
  /// a route to nowhere is worse than landing one level out. The queue is
  /// where the work gets done anyway.
  void _open(BuildContext context) {
    switch (item.kind) {
      case AttentionKind.pendingAction:
        // A push, because Approvals lives under this tab and back should
        // return here. The future completes when that screen is popped, and
        // nothing here needs its result.
        unawaited(context.push<void>(Routes.approvals));
      case AttentionKind.overdueTask:
        // A branch switch, not a push: Tasks is its own tab with its own
        // stack and scroll position, and pushing a second copy of it inside
        // Dashboard would strand the user in a duplicate.
        StatefulNavigationShell.of(
          context,
        ).goBranch(branchIndexOf(Routes.tasks));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final due = item.due;

    return EntityCard(
      onTap: () => _open(context),
      title: item.title,
      subtitle: item.subtitle,
      statusLabel: switch (item.kind) {
        AttentionKind.pendingAction => l10n.attentionPendingAction,
        AttentionKind.overdueTask => l10n.attentionOverdueTask,
      },
      statusIntent: switch (item.kind) {
        AttentionKind.pendingAction => StatusIntent.warning,
        AttentionKind.overdueTask => StatusIntent.danger,
      },
      statusPlacement: StatusPlacement.metadata,
      metadata: [
        if (due != null)
          EntityMeta(
            icon: AppIcons.schedule,
            label: DateFormat.MMMd(
              Localizations.localeOf(context).languageCode,
            ).add_Hm().format(due),
          ),
      ],
    );
  }
}
