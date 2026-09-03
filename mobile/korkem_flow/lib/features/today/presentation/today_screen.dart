import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/motion/animated_counter.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/today/application/today_controller.dart';
import 'package:korkem_flow/features/today/domain/today_attention.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The owner's daily attention dashboard:
/// what requires action across the whole pipeline.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(todayOrdersSummaryProvider)
      ..invalidate(todayProductionSummaryProvider)
      ..invalidate(todayApprovalsSummaryProvider)
      ..invalidate(todayStockSummaryProvider)
      ..invalidate(todayAttentionProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(todayOrdersSummaryProvider);
    final productionAsync = ref.watch(todayProductionSummaryProvider);
    final approvalsAsync = ref.watch(todayApprovalsSummaryProvider);
    final stockAsync = ref.watch(todayStockSummaryProvider);
    final attentionAsync = ref.watch(todayAttentionProvider);

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

            // Сколько — состояние цеха одним взглядом.
            _OrdersTile(state: ordersAsync),
            const SizedBox(height: AppSpacing.md),
            _ProductionTile(state: productionAsync),
            const SizedBox(height: AppSpacing.md),
            _ApprovalsTile(state: approvalsAsync),
            const SizedBox(height: AppSpacing.md),
            _StockTile(state: stockAsync),
            const SizedBox(height: AppSpacing.xl),

            // Что делать — то, что застряло в цепочке. Считается на сервере,
            // по другому маршруту: сводка отвечает «сколько», этот список —
            // «чем заняться сейчас».
            switch (attentionAsync) {
              AsyncData(:final value) => _Body(attention: value),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(todayAttentionProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.attention});

  final TodayAttention attention;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final money = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );

    if (attention.isAllClear) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AllClearHero(
            title: l10n.todayAllClearHeadline,
            description: l10n.todayAllClearDescription,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Group 1: Unassigned captures
        _AttentionGroupHeader(
          title: l10n.todayUnassignedCapturesTitle,
          count: attention.unassignedCaptures.length,
          icon: AppIcons.conversation,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (attention.unassignedCaptures.isEmpty)
          _GoodNewsCard(message: l10n.todayUnassignedCapturesEmpty)
        else
          for (final item in attention.unassignedCaptures) ...[
            _CaptureAttentionCard(item: item),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xl),

        // Group 2: Overdue tasks
        _AttentionGroupHeader(
          title: l10n.todayOverdueTasksTitle,
          count: attention.overdueTasks.length,
          icon: AppIcons.schedule,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (attention.overdueTasks.isEmpty)
          _GoodNewsCard(message: l10n.todayOverdueTasksEmpty)
        else
          for (final item in attention.overdueTasks) ...[
            _TaskAttentionCard(item: item),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xl),

        // Group 3: Orders without design
        _AttentionGroupHeader(
          title: l10n.todayOrdersWithoutDesignTitle,
          count: attention.ordersWithoutDesign.length,
          icon: AppIcons.item,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (attention.ordersWithoutDesign.isEmpty)
          _GoodNewsCard(message: l10n.todayOrdersWithoutDesignEmpty)
        else
          for (final item in attention.ordersWithoutDesign) ...[
            _OrderNoDesignCard(item: item),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xl),

        // Group 4: Delivered not invoiced
        _AttentionGroupHeader(
          title: l10n.todayDeliveredNotInvoicedTitle,
          count: attention.deliveredNotInvoiced.length,
          icon: AppIcons.quote,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (attention.deliveredNotInvoiced.isEmpty)
          _GoodNewsCard(message: l10n.todayDeliveredNotInvoicedEmpty)
        else
          for (final item in attention.deliveredNotInvoiced) ...[
            _DeliveredNotInvoicedCard(item: item, money: money),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _AllClearHero extends StatelessWidget {
  const _AllClearHero({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: AppTint.ornamentOnDark,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.success,
            color: theme.colorScheme.primary,
            size: AppIconSize.illustration,
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
    );
  }
}

class _AttentionGroupHeader extends StatelessWidget {
  const _AttentionGroupHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: AppIconSize.dense,
          color: count > 0
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        StatusChip(
          label: '$count',
          intent: count > 0 ? StatusIntent.danger : StatusIntent.success,
        ),
      ],
    );
  }
}

class _GoodNewsCard extends StatelessWidget {
  const _GoodNewsCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: AppTint.surface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.success,
            color: theme.colorScheme.primary,
            size: AppIconSize.small,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureAttentionCard extends StatelessWidget {
  const _CaptureAttentionCard({required this.item});

  final UnassignedCaptureItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () {
        unawaited(
          context.push('${Routes.enquiryFlow}?capture=${item.capture}'),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '«${item.said}»',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.customer != null && item.customer!.isNotEmpty
                      ? '${item.customer!} • ${item.since}'
                      : item.since,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            AppIcons.forward,
            size: AppIconSize.dense,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _TaskAttentionCard extends StatelessWidget {
  const _TaskAttentionCard({required this.item});

  final OverdueTaskItem item;

  void _navigate(BuildContext context) {
    final onDoc = item.on;
    if (onDoc != null && onDoc.startsWith('SAL-ORD-')) {
      unawaited(context.push(Routes.order(onDoc)));
    } else if (onDoc != null && onDoc.isNotEmpty) {
      unawaited(context.push('${Routes.enquiryFlow}?capture=$onDoc'));
    } else {
      unawaited(context.push(Routes.tasks));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final displayTitle = item.title != null && item.title!.isNotEmpty
        ? item.title!
        : item.task;

    return AppCard(
      onTap: () => _navigate(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.who != null && item.who!.isNotEmpty
                      ? '${item.who!} • ${l10n.todayOverdueWasDue(item.wasDue)}'
                      : l10n.todayOverdueWasDue(item.wasDue),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                if (item.on != null && item.on!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.on!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            AppIcons.forward,
            size: AppIconSize.dense,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _OrderNoDesignCard extends StatelessWidget {
  const _OrderNoDesignCard({required this.item});

  final OrderWithoutDesignItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final customer = item.customer;
    final due = item.due;
    final subtitle = customer != null && customer.isNotEmpty
        ? '$customer${due != null ? ' • ${l10n.todayDeliveryDue(due)}' : ''}'
        : (due != null ? l10n.todayDeliveryDue(due) : '');

    return AppCard(
      onTap: () {
        unawaited(context.push(Routes.order(item.salesOrder)));
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.salesOrder,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            AppIcons.forward,
            size: AppIconSize.dense,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _DeliveredNotInvoicedCard extends StatelessWidget {
  const _DeliveredNotInvoicedCard({
    required this.item,
    required this.money,
  });

  final DeliveredNotInvoicedItem item;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final customer = item.customer;
    final progress = l10n.todayBilledProgress(
      '${item.deliveredPercent.toInt()}',
      '${item.billedPercent.toInt()}',
    );
    final subtitle = customer != null && customer.isNotEmpty
        ? '$customer • $progress'
        : progress;

    return AppCard(
      onTap: () {
        unawaited(context.push(Routes.order(item.salesOrder)));
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.salesOrder} — ${money.format(item.total)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            AppIcons.forward,
            size: AppIconSize.dense,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
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
