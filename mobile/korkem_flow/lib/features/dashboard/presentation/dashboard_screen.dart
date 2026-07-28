import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/kpi_tile.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/dashboard/application/dashboard_controller.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The home screen: six numbers and a short list of what to do first.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(dashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDashboard)),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SectionLabel(l10n.dashboardGreeting),
        _MetricGrid(summary: summary, isLoading: isLoading),
        const SizedBox(height: AppSpacing.xxl),

        SectionLabel(l10n.dashboardAttention),
        if (isLoading)
          const ListSkeleton(rows: 2)
        else if (summary == null || summary!.attention.isEmpty)
          EmptyView(
            icon: AppIcons.success,
            title: l10n.dashboardAllClear,
            message: l10n.dashboardAllClearBody,
          )
        else
          for (final item in summary!.attention)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _AttentionCard(item: item),
            ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary, required this.isLoading});

  final DashboardSummary? summary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final metrics = <_Metric>[
      _Metric(DashboardSummary.openDeals, l10n.metricOpenDeals, AppIcons.deal),
      _Metric(DashboardSummary.openLeads, l10n.metricOpenLeads, AppIcons.lead),
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
      _Metric(
        DashboardSummary.pendingActions,
        l10n.metricPendingActions,
        AppIcons.approval,
        intent: StatusIntent.warning,
      ),
      _Metric(
        DashboardSummary.workOrdersInProgress,
        l10n.metricWorkOrders,
        AppIcons.workOrder,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two tiles on a phone, more as width allows. Driven by measured width
        // rather than a device class, so a foldable and a split-screen tablet
        // both get a sane count.
        final columns = (constraints.maxWidth / 180).floor().clamp(2, 4);

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final metric in metrics)
              KpiTile(
                label: metric.label,
                icon: metric.icon,
                intent: metric.intent,
                isLoading: isLoading,
                // A dash, never a zero: the backend returns null when the
                // caller's role may not see the number, and stating "0" would
                // assert something the user has no standing to know.
                value: switch (summary?[metric.key]) {
                  final int value => '$value',
                  _ => '—',
                },
              ),
          ],
        );
      },
    );
  }
}

@immutable
class _Metric {
  const _Metric(this.key, this.label, this.icon, {this.intent});

  final String key;
  final String label;
  final IconData icon;
  final StatusIntent? intent;
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final due = item.due;

    return EntityCard(
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
