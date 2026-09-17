import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';

/// Stock reservations and offcuts allocated to an order.
class OrderStockReservationSection extends ConsumerWidget {
  const OrderStockReservationSection({
    required this.order,
    super.key,
  });

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inProduction =
        order.status == SalesOrderStatus.toDeliverAndBill ||
        order.status == SalesOrderStatus.toDeliver;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('Резервы материалов и остатков'),
            StatusChip(
              label: inProduction ? 'Списано в цех' : 'Зарезервировано',
              intent:
                  inProduction ? StatusIntent.success : StatusIntent.info,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.board,
                    size: AppIconSize.dense,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Листовой раскрой & деловые остатки',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Под заказ ${order.name} выделены складские позиции'
                ' и проверена карта раскроя (Best-fit).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.check,
                        size: AppIconSize.dense,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Деловой остаток (Offcut) учтен',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Text(
                    'QR / Штрихкод готов',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
