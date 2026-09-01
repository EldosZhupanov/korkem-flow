import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/production/application/work_order_detail_controller.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/presentation/work_order_status_label.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One work order detail screen.
class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(workOrderDetailProvider(id));

    return AppScreen(
      title: id,
      subtitle: orderAsync.value?.itemName ?? orderAsync.value?.productionItem,
      body: switch (orderAsync) {
        AsyncData(:final value) => _Body(order: value),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(workOrderDetailProvider(id)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final linkedOrder = order.salesOrder;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(workOrderDetailProvider(order.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Header(order: order),
          if (linkedOrder != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(l10n.workOrderLinkedSalesOrder),
            const SizedBox(height: AppSpacing.sm),
            _LinkedOrderCard(salesOrder: linkedOrder),
          ],
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);
    final date = DateFormat.yMMMd(locale);
    final planned = order.plannedEndDate;
    final actual = order.actualEndDate;
    final isLate = order.isLateAt(ref.watch(clockProvider)());
    final bom = order.bomNo;
    final wip = order.wipWarehouse;
    final fg = order.fgWarehouse;
    final itemCode = order.productionItem;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.itemName ?? itemCode ?? order.id,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: order.status.label(l10n),
                intent: order.status.intent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: order.progress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: isLate
                        ? context.statusColors.danger
                        : context.statusColors.success,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${quantity.format(order.producedQty)} / ${quantity.format(order.qty)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          if (itemCode != null)
            _Field(
              icon: AppIcons.item,
              label: itemCode,
            ),
          if (planned != null)
            _Field(
              icon: AppIcons.schedule,
              label: l10n.workOrderPlannedEnd(date.format(planned)),
              intent: isLate ? StatusIntent.danger : null,
            ),
          if (actual != null)
            _Field(
              icon: AppIcons.schedule,
              label: l10n.workOrderActualEnd(date.format(actual)),
            ),
          if (bom != null)
            _Field(
              icon: AppIcons.task,
              label: l10n.workOrderBomNo(bom),
            ),
          if (wip != null)
            _Field(
              icon: AppIcons.warehouse,
              label: l10n.workOrderWipWarehouse(wip),
            ),
          if (fg != null)
            _Field(
              icon: AppIcons.warehouse,
              label: l10n.workOrderFgWarehouse(fg),
            ),

          if (isLate) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.tasksOverdue,
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.statusColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkedOrderCard extends StatelessWidget {
  const _LinkedOrderCard({required this.salesOrder});

  final String salesOrder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => context.push(Routes.order(salesOrder)),
      child: Row(
        children: [
          Icon(
            AppIcons.quote,
            size: AppIconSize.small,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salesOrder,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.workOrderLinkedSalesOrder,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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

class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, this.intent});

  final IconData icon;
  final String label;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = intent == StatusIntent.danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.dense, color: colour),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}
