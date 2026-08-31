import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/motion/animated_counter.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/today/application/today_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The Today screen: operational shop floor overview.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(todayOrdersSummaryProvider)
      ..invalidate(todayProductionSummaryProvider)
      ..invalidate(todayApprovalsSummaryProvider)
      ..invalidate(todayStockSummaryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(todayOrdersSummaryProvider);
    final productionAsync = ref.watch(todayProductionSummaryProvider);
    final approvalsAsync = ref.watch(todayApprovalsSummaryProvider);
    final stockAsync = ref.watch(todayStockSummaryProvider);

    final totalAlerts =
        (ordersAsync.value?.lateCount ?? 0) +
        (productionAsync.value?.lateCount ?? 0) +
        (approvalsAsync.value?.pendingCount ?? 0) +
        (stockAsync.value?.deficitCount ?? 0);

    final isAllLoaded =
        ordersAsync.hasValue &&
        productionAsync.hasValue &&
        approvalsAsync.hasValue &&
        stockAsync.hasValue;

    return AppScreen(
      title: l10n.todayTitle,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              l10n.todaySubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 4 Operational KPI Tiles ──────────────────────────────────────
            _OrdersTile(state: ordersAsync),
            const SizedBox(height: AppSpacing.md),
            _ProductionTile(state: productionAsync),
            const SizedBox(height: AppSpacing.md),
            _ApprovalsTile(state: approvalsAsync),
            const SizedBox(height: AppSpacing.md),
            _StockTile(state: stockAsync),
            const SizedBox(height: AppSpacing.xl),

            // ── Operational status / Attention section ────────────────────────
            if (isAllLoaded && totalAlerts == 0)
              _AllClearBanner(
                title: l10n.todayAllClearTitle,
                subtitle: l10n.todayAllClearSubtitle,
              )
            else if (totalAlerts > 0) ...[
              SectionLabel(l10n.todayAttentionTitle),
              const SizedBox(height: AppSpacing.sm),
              if ((ordersAsync.value?.lateCount ?? 0) > 0)
                _AttentionItemCard(
                  icon: AppIcons.quote,
                  title: l10n.ordersTitle,
                  subtitle: l10n.todayLateOrders(
                    ordersAsync.value!.lateCount,
                  ),
                  intent: StatusIntent.danger,
                  onTap: () => context.push(Routes.orders),
                ),
              if ((productionAsync.value?.lateCount ?? 0) > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _AttentionItemCard(
                  icon: AppIcons.workOrder,
                  title: l10n.todayInProduction,
                  subtitle: l10n.todayLateOrders(
                    productionAsync.value!.lateCount,
                  ),
                  intent: StatusIntent.danger,
                  onTap: () => context.push(Routes.production),
                ),
              ],
              if ((approvalsAsync.value?.pendingCount ?? 0) > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _AttentionItemCard(
                  icon: AppIcons.approval,
                  title: l10n.todayApprovals,
                  subtitle: l10n.todayApprovalsCount(
                    approvalsAsync.value!.pendingCount,
                  ),
                  intent: StatusIntent.warning,
                  onTap: () => context.push(Routes.approvals),
                ),
              ],
              if ((stockAsync.value?.deficitCount ?? 0) > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _AttentionItemCard(
                  icon: AppIcons.warehouse,
                  title: l10n.todayStockDeficit,
                  subtitle: l10n.todayDeficitCount(
                    stockAsync.value!.deficitCount,
                  ),
                  intent: StatusIntent.danger,
                  onTap: () => context.push(Routes.deliveryCentre),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.xl),
            SectionLabel(l10n.todayQuickNav),
            const SizedBox(height: AppSpacing.sm),
            _QuickNavRow(
              icon: AppIcons.quote,
              label: l10n.ordersTitle,
              onTap: () => context.push(Routes.orders),
            ),
            const SizedBox(height: AppSpacing.xs),
            _QuickNavRow(
              icon: AppIcons.workOrder,
              label: l10n.todayInProduction,
              onTap: () => context.push(Routes.production),
            ),
            const SizedBox(height: AppSpacing.xs),
            _QuickNavRow(
              icon: AppIcons.approval,
              label: l10n.todayApprovals,
              onTap: () => context.push(Routes.approvals),
            ),
            const SizedBox(height: AppSpacing.xs),
            _QuickNavRow(
              icon: AppIcons.warehouse,
              label: l10n.todayStockDeficit,
              onTap: () => context.push(Routes.deliveryCentre),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTile extends StatelessWidget {
  const _OrdersTile({required this.state});

  final AsyncValue<TodayOrdersSummary> state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return switch (state) {
      AsyncData(:final value) => _OperationalTile(
        title: l10n.todayActiveOrders,
        value: value.activeCount,
        statusText: value.lateCount > 0
            ? l10n.todayLateOrders(value.lateCount)
            : l10n.todayOrdersAllOnTrack,
        icon: AppIcons.quote,
        intent: value.lateCount > 0
            ? StatusIntent.danger
            : StatusIntent.neutral,
        onTap: () => context.push(Routes.orders),
      ),
      AsyncError() => _OperationalTile(
        title: l10n.todayActiveOrders,
        value: null,
        statusText: l10n.todayTileError,
        icon: AppIcons.quote,
        errorMessage: l10n.todayTileError,
        onTap: () => context.push(Routes.orders),
      ),
      _ => _OperationalTile(
        title: l10n.todayActiveOrders,
        value: null,
        statusText: '',
        icon: AppIcons.quote,
        isLoading: true,
      ),
    };
  }
}

class _ProductionTile extends StatelessWidget {
  const _ProductionTile({required this.state});

  final AsyncValue<TodayProductionSummary> state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return switch (state) {
      AsyncData(:final value) => _OperationalTile(
        title: l10n.todayInProduction,
        value: value.inProcessCount,
        statusText: value.lateCount > 0
            ? l10n.todayLateOrders(value.lateCount)
            : l10n.todayProductionAllOnTrack,
        icon: AppIcons.workOrder,
        intent: value.lateCount > 0
            ? StatusIntent.danger
            : StatusIntent.neutral,
        onTap: () => context.push(Routes.production),
      ),
      AsyncError() => _OperationalTile(
        title: l10n.todayInProduction,
        value: null,
        statusText: l10n.todayTileError,
        icon: AppIcons.workOrder,
        errorMessage: l10n.todayTileError,
        onTap: () => context.push(Routes.production),
      ),
      _ => _OperationalTile(
        title: l10n.todayInProduction,
        value: null,
        statusText: '',
        icon: AppIcons.workOrder,
        isLoading: true,
      ),
    };
  }
}

class _ApprovalsTile extends StatelessWidget {
  const _ApprovalsTile({required this.state});

  final AsyncValue<TodayApprovalsSummary> state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return switch (state) {
      AsyncData(:final value) => _OperationalTile(
        title: l10n.todayApprovals,
        value: value.pendingCount,
        statusText: value.pendingCount > 0
            ? l10n.todayApprovalsCount(value.pendingCount)
            : l10n.todayApprovalsNone,
        icon: AppIcons.approval,
        intent: value.pendingCount > 0
            ? StatusIntent.warning
            : StatusIntent.success,
        onTap: () => context.push(Routes.approvals),
      ),
      AsyncError() => _OperationalTile(
        title: l10n.todayApprovals,
        value: null,
        statusText: l10n.todayTileError,
        icon: AppIcons.approval,
        errorMessage: l10n.todayTileError,
        onTap: () => context.push(Routes.approvals),
      ),
      _ => _OperationalTile(
        title: l10n.todayApprovals,
        value: null,
        statusText: '',
        icon: AppIcons.approval,
        isLoading: true,
      ),
    };
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.state});

  final AsyncValue<TodayStockSummary> state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return switch (state) {
      AsyncData(:final value) => _OperationalTile(
        title: l10n.todayStockDeficit,
        value: value.deficitCount,
        statusText: value.deficitCount > 0
            ? l10n.todayDeficitCount(value.deficitCount)
            : l10n.todayDeficitNone,
        icon: AppIcons.warehouse,
        intent: value.deficitCount > 0
            ? StatusIntent.danger
            : StatusIntent.success,
        onTap: () => context.push(Routes.deliveryCentre),
      ),
      AsyncError() => _OperationalTile(
        title: l10n.todayStockDeficit,
        value: null,
        statusText: l10n.todayTileError,
        icon: AppIcons.warehouse,
        errorMessage: l10n.todayTileError,
        onTap: () => context.push(Routes.deliveryCentre),
      ),
      _ => _OperationalTile(
        title: l10n.todayStockDeficit,
        value: null,
        statusText: '',
        icon: AppIcons.warehouse,
        isLoading: true,
      ),
    };
  }
}

class _OperationalTile extends StatelessWidget {
  const _OperationalTile({
    required this.title,
    required this.value,
    required this.statusText,
    required this.icon,
    this.intent,
    this.isLoading = false,
    this.errorMessage,
    this.onTap,
  });

  final String title;
  final int? value;
  final String statusText;
  final IconData icon;
  final StatusIntent? intent;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = intent == null
        ? theme.colorScheme.primary
        : context.statusColors.resolve(intent!);

    return MergeSemantics(
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: AppIconSize.small, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  AppIcons.forward,
                  size: AppIconSize.dense,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isLoading)
              Container(
                height: AppPlaceholder.metricHeight,
                width: AppPlaceholder.metricWidth,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              )
            else if (errorMessage != null)
              Text(
                errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.statusColors.danger,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedCounter(
                    value: value,
                    placeholder: '—',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: intent == null
                            ? theme.colorScheme.onSurfaceVariant
                            : accent,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AllClearBanner extends StatelessWidget {
  const _AllClearBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = context.statusColors.success;

    return AppCard(
      child: Row(
        children: [
          Icon(AppIcons.check, size: AppIconSize.normal, color: successColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionItemCard extends StatelessWidget {
  const _AttentionItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.intent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final StatusIntent intent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.statusColors.resolve(intent);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.small, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: accent),
                ),
              ],
            ),
          ),
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

class _QuickNavRow extends StatelessWidget {
  const _QuickNavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppIconSize.small,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
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
