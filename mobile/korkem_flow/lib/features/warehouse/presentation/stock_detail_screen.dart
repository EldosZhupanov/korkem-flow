import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/warehouse/application/stock_detail_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:korkem_flow/features/warehouse/presentation/create_purchase_order_button.dart';
import 'package:korkem_flow/features/warehouse/presentation/receive_delivery_button.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One stock item detail screen showing total summary and per-warehouse
/// balances.
class StockDetailScreen extends ConsumerWidget {
  const StockDetailScreen({required this.itemCode, super.key});

  final String itemCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(stockItemDetailProvider(itemCode));

    return AppScreen(
      title: itemCode,
      subtitle: detailAsync.value?.itemName,
      body: StockDetailView(itemCode: itemCode),
    );
  }
}

/// The body and state handling for one stock item detail view.
class StockDetailView extends ConsumerWidget {
  const StockDetailView({required this.itemCode, super.key});

  final String itemCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(stockItemDetailProvider(itemCode));

    return switch (detailAsync) {
      AsyncData(:final value) => _Body(detail: value),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(stockItemDetailProvider(itemCode)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final StockItemDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(stockItemDetailProvider(detail.itemCode));
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Header(detail: detail),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ReceiveDeliveryButton(
                  onReceived: () async {
                    ref.invalidate(stockItemDetailProvider(detail.itemCode));
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                CreatePurchaseOrderButton(
                  initialMaterialRequest: detail.hasDeficit
                      ? detail.itemCode
                      : null,
                  onOrdered: () async {
                    ref.invalidate(stockItemDetailProvider(detail.itemCode));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.stockBalancesSection),
          const SizedBox(height: AppSpacing.sm),
          if (detail.positions.isEmpty)
            EmptyView(
              icon: AppIcons.warehouse,
              title: l10n.stockNoBalancesTitle,
              message: l10n.stockNoBalancesBody,
            )
          else
            for (final pos in detail.positions) ...[
              _WarehouseBalanceCard(position: pos, uom: detail.stockUom),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final StockItemDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);
    final hasDeficit = detail.hasDeficit;

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
                      detail.itemName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      detail.itemCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (detail.stockUom != null)
                StatusChip(
                  label: detail.stockUom!,
                  intent: StatusIntent.neutral,
                ),
            ],
          ),
          if (hasDeficit) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  AppIcons.warehouse,
                  size: AppIconSize.small,
                  color: context.statusColors.danger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.stockDeficitAlert,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.statusColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: AppStroke.hairline),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.stockSummarySection,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: l10n.stockActualQty,
                  value: quantity.format(detail.totalActualQty),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: l10n.stockReservedQty,
                  value: quantity.format(detail.totalReservedQty),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: l10n.stockProjectedQty,
                  value: quantity.format(detail.totalProjectedQty),
                  intent: detail.totalProjectedQty < 0
                      ? StatusIntent.danger
                      : StatusIntent.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    this.intent,
  });

  final String label;
  final String value;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = intent == null
        ? theme.colorScheme.onSurface
        : context.statusColors.resolve(intent!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colour,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WarehouseBalanceCard extends StatelessWidget {
  const _WarehouseBalanceCard({
    required this.position,
    this.uom,
  });

  final StockPosition position;
  final String? uom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);
    final isDeficit = position.projectedQty < 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.warehouse,
                size: AppIconSize.small,
                color: isDeficit
                    ? context.statusColors.danger
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  position.warehouse,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDeficit)
                StatusChip(
                  label: l10n.stockDeficitAlert,
                  intent: StatusIntent.danger,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: l10n.stockActualQty,
                  value:
                      quantity.format(position.actualQty) +
                      (uom == null ? '' : ' $uom'),
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: l10n.stockReservedQty,
                  value:
                      quantity.format(position.reservedQty) +
                      (uom == null ? '' : ' $uom'),
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: l10n.stockProjectedQty,
                  value:
                      quantity.format(position.projectedQty) +
                      (uom == null ? '' : ' $uom'),
                  intent: isDeficit ? StatusIntent.danger : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    this.intent,
  });

  final String label;
  final String value;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = intent == StatusIntent.danger
        ? context.statusColors.danger
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colour,
            fontWeight: intent == StatusIntent.danger
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
