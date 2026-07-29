import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/production/application/production_controller.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/presentation/work_order_status_label.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});

  Future<void> _openFilter(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final choice = await showFilterSheet<WorkOrderStatus>(
      context: context,
      title: l10n.actionFilter,
      current: ref.read(productionFilterProvider).status,
      options: [
        for (final status in WorkOrderStatus.values)
          FilterOption(value: status, label: status.label(l10n)),
      ],
    );

    if (choice == null) return;
    ref.read(productionFilterProvider.notifier).setStatus(choice.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(productionFilterProvider);
    final controller = ref.read(productionControllerProvider.notifier);

    return CrmListSection(
      searchValue: filter.search,
      onSearch: (value) => ref
          .read(productionFilterProvider.notifier)
          .setSearch(value.isEmpty ? null : value),
      isFiltered: filter.status != null,
      onFilter: () => _openFilter(context, ref),
      child: PagedListView<WorkOrder>(
        state: ref.watch(productionControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, order) => WorkOrderCard(order: order),
        emptyView: (context) => ListEmptyView(
          icon: AppIcons.workOrder,
          title: l10n.productionEmpty,
          // A status filter and a search fail differently, and saying "new
          // ones will appear here" to someone who just filtered to a status
          // with no records blames the data for the user's own choice.
          message: switch (filter) {
            _ when filter.search != null => l10n.searchNoResults(
              filter.search!,
            ),
            _ when filter.status != null => l10n.filterNoResults,
            _ => l10n.productionEmptyBody,
          },
          onRefresh: controller.refresh,
          onClearFilter: filter.status == null && filter.search == null
              ? null
              : ref.read(productionFilterProvider.notifier).clear,
        ),
      ),
    );
  }
}

/// A work order, led by the one number that matters: how much is made.
class WorkOrderCard extends StatelessWidget {
  const WorkOrderCard({required this.order, this.onTap, super.key});

  final WorkOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);
    final planned = order.plannedEndDate;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.itemName ?? order.productionItem ?? order.id,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: order.status.label(l10n),
                intent: order.status.intent,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress before anything else: "18 of 40 made" is the answer to
          // the only question anyone opens this screen to ask.
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: order.progress,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: order.isLate
                        ? context.statusColors.danger
                        : context.statusColors.success,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${quantity.format(order.producedQty)} / '
                '${quantity.format(order.qty)}',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              if (planned != null)
                _Meta(
                  icon: AppIcons.schedule,
                  label: DateFormat.MMMd(locale).format(planned),
                  intent: order.isLate ? StatusIntent.danger : null,
                ),
              if (order.originatingDeal != null)
                _Meta(icon: AppIcons.deal, label: order.originatingDeal!),
              _Meta(icon: AppIcons.workOrder, label: order.id),
            ],
          ),

          if (order.isLate) ...[
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

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.intent});

  final IconData icon;
  final String label;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = intent == null
        ? theme.colorScheme.outline
        : context.statusColors.resolve(intent!);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.inline - 2, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: intent == null ? null : color,
          ),
        ),
      ],
    );
  }
}
