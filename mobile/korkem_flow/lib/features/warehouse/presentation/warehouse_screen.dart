import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/search/recent_searches.dart';
import 'package:korkem_flow/features/warehouse/application/warehouse_controller.dart';
import 'package:korkem_flow/features/warehouse/domain/stock_item.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class WarehouseScreen extends ConsumerWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final search = ref.watch(itemSearchProvider);
    final controller = ref.read(warehouseControllerProvider.notifier);

    return CrmListSection(
      searchScope: SearchScope.warehouse,
      searchValue: search,
      onSearch: ref.read(itemSearchProvider.notifier).set,
      child: PagedListView<StockItem>(
        state: ref.watch(warehouseControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, item) => StockItemCard(item: item),
        emptyView: (context) => ListEmptyView(
          icon: AppIcons.item,
          title: l10n.warehouseEmpty,
          message: search != null
              ? l10n.searchNoResults(search)
              : l10n.warehouseEmptyBody,
          onRefresh: controller.refresh,
          onClearFilter: search == null
              ? null
              : () => ref.read(itemSearchProvider.notifier).set(null),
        ),
      ),
    );
  }
}

/// An item, expanding to its per-warehouse balances.
///
/// The balances are a second request per item, so they load on expansion
/// rather than eagerly: a fifty-row list would otherwise fire fifty extra
/// queries to show numbers nobody asked for.
class StockItemCard extends ConsumerStatefulWidget {
  const StockItemCard({required this.item, super.key});

  final StockItem item;

  @override
  ConsumerState<StockItemCard> createState() => _StockItemCardState();
}

class _StockItemCardState extends ConsumerState<StockItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = widget.item;

    return AppCard(
      // A non-stock item — a service, a fee — has no balance to show, so it is
      // not made to look expandable.
      onTap: item.isStockItem
          ? () => setState(() => _expanded = !_expanded)
          : null,
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
                      item.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isStockItem)
                Icon(
                  _expanded ? AppIcons.close : AppIcons.forward,
                  size: AppIconSize.small,
                  color: theme.colorScheme.outline,
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              if (item.itemGroup != null)
                _Meta(icon: AppIcons.item, label: item.itemGroup!),
              if (item.stockUom != null)
                _Meta(icon: AppIcons.warehouse, label: item.stockUom!),
            ],
          ),

          if (_expanded) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: AppStroke.hairline),
            const SizedBox(height: AppSpacing.md),
            _Balances(itemCode: item.id, uom: item.stockUom, l10n: l10n),
          ],
        ],
      ),
    );
  }
}

class _Balances extends ConsumerWidget {
  const _Balances({required this.itemCode, required this.l10n, this.uom});

  final String itemCode;
  final String? uom;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final quantity = NumberFormat.decimalPattern(
      Localizations.localeOf(context).languageCode,
    );

    return switch (ref.watch(stockBalancesProvider(itemCode))) {
      AsyncError(:final error) => ErrorView(error: error),
      AsyncData(:final value) when value.isEmpty => Text(
        // Distinct from "zero in stock": ERPNext creates a Bin only where
        // stock has actually moved, so no rows means never stocked anywhere.
        l10n.warehouseNoStock,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      AsyncData(:final value) => Column(
        children: [
          for (final balance in value)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      balance.warehouse,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Available, not actual: what can still be promised to a
                  // customer is physical stock minus what is already committed.
                  Text(
                    '${quantity.format(balance.availableQty)}'
                    '${uom == null ? '' : ' $uom'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: balance.availableQty <= 0
                          ? context.statusColors.danger
                          : null,
                    ),
                  ),
                  if (balance.reservedQty > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '(${l10n.fieldReserved} '
                      '${quantity.format(balance.reservedQty)})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push(Routes.stockItem(itemCode)),
              icon: const Icon(AppIcons.forward, size: AppIconSize.dense),
              label: Text(l10n.warehouseActionOpen),
            ),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(minHeight: 2),
      ),
    };
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppIconSize.dense,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
