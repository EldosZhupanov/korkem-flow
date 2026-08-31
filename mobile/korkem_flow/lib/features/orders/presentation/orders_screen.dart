import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/orders/application/orders_controller.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/sales_order_status_label.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
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
class SalesOrderCard extends ConsumerStatefulWidget {
  const SalesOrderCard({required this.order, super.key});

  final SalesOrder order;

  @override
  ConsumerState<SalesOrderCard> createState() => _SalesOrderCardState();
}

class _SalesOrderCardState extends ConsumerState<SalesOrderCard> {
  bool _isStarting = false;

  Future<void> _handleStartProduction() async {
    if (_isStarting) return;

    setState(() => _isStarting = true);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);

    try {
      final result = await ref
          .read(productionCommandRepositoryProvider)
          .start(widget.order.name);

      if (!mounted) return;

      if (result.started) {
        if (result.toppedUp) {
          messenger.showDone(l10n.ordersTopUpSuccess(widget.order.name));
        } else {
          messenger.showDone(l10n.ordersStartSuccess(widget.order.name));
        }
        await ref.read(ordersControllerProvider.notifier).refresh();
      } else if (result.blocked) {
        messenger.showFailureMessage(
          l10n.ordersBlockedSummary(widget.order.name),
        );

        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.ordersBlockedTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message ?? l10n.ordersBlockedBody),
                if (result.blockingMaterials.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (final m in result.blockingMaterials)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        '• ${m.itemCode}: '
                        '${quantity.format(m.shortageQty)}'
                        '${m.uom != null ? ' ${m.uom}' : ''}',
                        style: Theme.of(dialogContext).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.actionClose),
              ),
            ],
          ),
        );
      } else if (result.status == 'already_started') {
        messenger.showDone(l10n.ordersAlreadyStarted(widget.order.name));
      } else if (result.status == 'nothing_to_start') {
        messenger.showDone(l10n.ordersNothingToStart(widget.order.name));
      } else {
        messenger.showDone(result.message ?? result.status);
      }
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final currencyFormat = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );
    final order = widget.order;
    final isLate = order.isLateAt(ref.watch(clockProvider)());
    final transaction = order.transactionDate;
    final delivery = order.deliveryDate;

    return AppCard(
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

          // Action button: Start production
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isStarting ? null : _handleStartProduction,
              icon: _isStarting
                  ? SizedBox(
                      width: AppIconSize.dense,
                      height: AppIconSize.dense,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStroke.hairline + 1,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(AppIcons.workOrder, size: AppIconSize.small),
              label: Text(l10n.ordersActionStartProduction),
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
