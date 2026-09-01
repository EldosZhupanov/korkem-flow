import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/orders/application/orders_controller.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/sales_order_status_label.dart';
import 'package:korkem_flow/features/orders/presentation/start_production_button.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Future<void> _openFilter(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final choice = await showFilterSheet<SalesOrderStatus>(
      context: context,
      title: l10n.actionFilter,
      current: ref.read(ordersFilterProvider).status,
      options: [
        for (final status in SalesOrderStatus.values)
          FilterOption(value: status, label: status.label(l10n)),
      ],
    );

    if (choice == null) return;
    ref.read(ordersFilterProvider.notifier).setStatus(choice.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(ordersFilterProvider);
    final controller = ref.read(ordersControllerProvider.notifier);

    return AppScreen(
      title: l10n.ordersTitle,
      body: CrmListSection(
        searchValue: filter.search,
        onSearch: (value) => ref
            .read(ordersFilterProvider.notifier)
            .setSearch(value.isEmpty ? null : value),
        isFiltered: filter.status != null,
        onFilter: () => _openFilter(context, ref),
        child: PagedListView<SalesOrder>(
          state: ref.watch(ordersControllerProvider),
          onRefresh: controller.refresh,
          onLoadMore: controller.loadMore,
          itemBuilder: (context, order) => SalesOrderCard(order: order),
          emptyView: (context) => ListEmptyView(
            icon: AppIcons.quote,
            title: l10n.ordersEmpty,
            message: switch (filter) {
              _ when filter.search != null => l10n.searchNoResults(
                filter.search!,
              ),
              _ when filter.status != null => l10n.filterNoResults,
              _ => l10n.ordersEmptyBody,
            },
            onRefresh: controller.refresh,
            onClearFilter: filter.status == null && filter.search == null
                ? null
                : ref.read(ordersFilterProvider.notifier).clear,
          ),
        ),
      ),
    );
  }
}

/// A card for an ERPNext Sales Order with production trigger button.
class SalesOrderCard extends ConsumerWidget {
  const SalesOrderCard({required this.order, super.key});

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final currencyFormat = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );
    final isLate = order.isLateAt(ref.watch(clockProvider)());
    final transaction = order.transactionDate;
    final delivery = order.deliveryDate;

    return AppCard(
      // The whole card opens the order. A row you can see and cannot open is
      // what this screen was before there was somewhere to go.
      onTap: () => context.push(Routes.order(order.name)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customer.isNotEmpty ? order.customer : order.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.customer.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        order.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
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

          // Total and Delivery Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyFormat.format(order.grandTotal),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (order.perDelivered > 0)
                Text(
                  l10n.ordersDeliveredProgress(
                    order.perDelivered.toStringAsFixed(0),
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: order.isDelivered
                        ? context.statusColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Metadata row: Dates
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              if (transaction != null)
                _OrderMeta(
                  icon: AppIcons.schedule,
                  label: l10n.ordersTransactionDate(
                    DateFormat.MMMd(locale).format(transaction),
                  ),
                ),
              if (delivery != null)
                _OrderMeta(
                  icon: AppIcons.schedule,
                  label: l10n.ordersDeliveryDate(
                    DateFormat.MMMd(locale).format(delivery),
                  ),
                  intent: isLate ? StatusIntent.danger : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Align(
            alignment: Alignment.centerRight,
            child: StartProductionButton(
              salesOrder: order.name,
              onStarted: () =>
                  ref.read(ordersControllerProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.icon, required this.label, this.intent});

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
        Icon(icon, size: AppIconSize.dense, color: color),
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
