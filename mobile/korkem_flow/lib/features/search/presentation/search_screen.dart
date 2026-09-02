import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/sales_order_status_label.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/presentation/work_order_status_label.dart';
import 'package:korkem_flow/features/search/application/search_controller.dart';
import 'package:korkem_flow/features/search/domain/search_results.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Universal search across sales orders, manufacturing work orders, and
/// warehouse stock.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppDebounce.search, () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).query = value;
      }
    });
  }

  void _onSubmitted(String value) {
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).query = value;
  }

  void _onClear() {
    _debounceTimer?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final activeQuery = ref.watch(searchQueryProvider);

    return AppScreen(
      title: l10n.searchTitle,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholder,
                prefixIcon: const Icon(
                  AppIcons.search,
                  size: AppIconSize.small,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: AppIconSize.small,
                        ),
                        onPressed: _onClear,
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          Expanded(
            child: activeQuery.trim().isEmpty
                ? EmptyView(
                    icon: AppIcons.search,
                    title: l10n.searchEmptyPromptTitle,
                    message: l10n.searchEmptyPromptBody,
                  )
                : _SearchResultsView(query: activeQuery.trim()),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsView extends ConsumerWidget {
  const _SearchResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncResults = ref.watch(globalSearchResultsProvider(query));

    return asyncResults.when(
      data: (results) {
        if (results.isEmpty) {
          final l10n = AppLocalizations.of(context);
          return EmptyView(
            icon: AppIcons.search,
            title: l10n.searchNoResultsTitle,
            message: l10n.searchNoResultsBody(query),
          );
        }

        return _ResultsList(results: results);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(globalSearchResultsProvider(query)),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final GlobalSearchResults results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (results.orders.hasError)
          _SectionErrorCard(
            message: l10n.searchSectionError(l10n.ordersTitle),
          )
        else if (results.orders.isNotEmpty) ...[
          SectionLabel(l10n.searchSectionOrders(results.orders.total)),
          for (final order in results.orders.items)
            _OrderResultCard(order: order),
          const SizedBox(height: AppSpacing.md),
        ],
        if (results.workOrders.hasError)
          _SectionErrorCard(
            message: l10n.searchSectionError(l10n.navOperations),
          )
        else if (results.workOrders.isNotEmpty) ...[
          SectionLabel(l10n.searchSectionWorkOrders(results.workOrders.total)),
          for (final job in results.workOrders.items)
            _WorkOrderResultCard(job: job),
          const SizedBox(height: AppSpacing.md),
        ],
        if (results.stock.hasError)
          _SectionErrorCard(
            message: l10n.searchSectionError(l10n.navWarehouse),
          )
        else if (results.stock.isNotEmpty) ...[
          SectionLabel(l10n.searchSectionStock(results.stock.total)),
          for (final position in results.stock.items)
            _StockResultCard(position: position),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SectionErrorCard extends StatelessWidget {
  const _SectionErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Row(
          children: [
            Icon(
              AppIcons.offline,
              size: AppIconSize.small,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderResultCard extends StatelessWidget {
  const _OrderResultCard({required this.order});

  final SalesOrder order;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push(Routes.order(order.name)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customer.isNotEmpty ? order.customer : order.name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusChip(
                  label: order.status.label(l10n),
                  intent: order.status.intent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  order.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (order.grandTotal > 0)
                  Text(
                    money.format(order.grandTotal),
                    style: theme.textTheme.labelMedium,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkOrderResultCard extends StatelessWidget {
  const _WorkOrderResultCard({required this.job});

  final WorkOrder job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push(Routes.workOrder(job.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.itemName ?? job.productionItem ?? job.id,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusChip(
                  label: job.status.label(l10n),
                  intent: job.status.intent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  job.id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${quantity.format(job.producedQty)} / ${quantity.format(job.qty)}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockResultCard extends StatelessWidget {
  const _StockResultCard({required this.position});

  final StockPosition position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);
    final uom = position.stockUom;
    final qtySuffix = uom != null && uom.isNotEmpty ? ' $uom' : '';
    final qtyText = '${quantity.format(position.actualQty)}$qtySuffix'.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push(Routes.stockItem(position.itemCode)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    position.itemName ?? position.itemCode,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  qtyText,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  position.itemCode,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (position.warehouse.isNotEmpty)
                  Text(
                    position.warehouse,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
