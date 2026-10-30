import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/orders/application/order_warranty_controller.dart';
import 'package:korkem_flow/features/orders/domain/order_warranty.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The Warranty & Claims section displayed at the bottom of the Order screen.
class OrderWarrantySection extends ConsumerWidget {
  const OrderWarrantySection({required this.order, super.key});

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warrantyAsync = ref.watch(orderWarrantyProvider(order.name));

    return switch (warrantyAsync) {
      AsyncData(:final value) => _WarrantyCard(
        order: order,
        warranty: value,
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(orderWarrantyProvider(order.name)),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _WarrantyCard extends ConsumerStatefulWidget {
  const _WarrantyCard({
    required this.order,
    required this.warranty,
  });

  final SalesOrder order;
  final OrderWarranty warranty;

  @override
  ConsumerState<_WarrantyCard> createState() => _WarrantyCardState();
}

class _WarrantyCardState extends ConsumerState<_WarrantyCard> {
  String? _successClaim;
  String? _errorMessage;

  Future<void> _showClaimDialog() async {
    final l10n = AppLocalizations.of(context);
    final warranty = widget.warranty;
    if (warranty.items.isEmpty) return;

    var selectedItem = warranty.items.first.itemCode;
    final complaintController = TextEditingController();
    String? dialogError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.orderWarrantyClaimDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dialogError != null) ...[
                    _ErrorNotice(message: dialogError!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: selectedItem,
                    decoration: InputDecoration(
                      labelText: l10n.orderWarrantyItemLabel,
                      prefixIcon: const Icon(AppIcons.item),
                    ),
                    items: [
                      for (final it in warranty.items)
                        DropdownMenuItem(
                          value: it.itemCode,
                          child: Text(
                            it.itemName != null && it.itemName!.isNotEmpty
                                ? '${it.itemName} (${it.itemCode})'
                                : it.itemCode,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedItem = val);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: complaintController,
                    decoration: InputDecoration(
                      labelText: l10n.orderWarrantyComplaintLabel,
                      hintText: l10n.orderWarrantyComplaintHint,
                      prefixIcon: const Icon(AppIcons.edit),
                    ),
                    maxLines: 3,
                    autofocus: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final complaint = complaintController.text.trim();
                  if (complaint.isEmpty) {
                    setDialogState(() {
                      dialogError = l10n.orderWarrantyComplaintRequired;
                    });
                    return;
                  }

                  try {
                    final response = await ref
                        .read(orderWarrantyActionsProvider)
                        .claim(
                          salesOrder: widget.order.name,
                          itemCode: selectedItem,
                          complaint: complaint,
                        );
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop(true);
                    }
                    if (mounted) {
                      final claimId = '${response['claim'] ?? ''}';
                      setState(() {
                        _successClaim = claimId.isNotEmpty
                            ? claimId
                            : selectedItem;
                        _errorMessage = null;
                      });
                    }
                  } on FrappeException catch (e) {
                    setDialogState(() => dialogError = e.message);
                  } on Object catch (e) {
                    setDialogState(() => dialogError = '$e');
                  }
                },
                icon: const Icon(AppIcons.check),
                label: Text(l10n.orderWarrantyClaimAction),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ref.invalidate(orderWarrantyProvider(widget.order.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateFormat.yMMMd(locale);
    final warranty = widget.warranty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.orderWarrantySection,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (warranty.isShipped && warranty.hasActiveWarranty)
                StatusChip(
                  label: l10n.orderWarrantyStatusActive,
                  intent: StatusIntent.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_errorMessage != null) ...[
            _ErrorNotice(message: _errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_successClaim != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
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
                      l10n.orderWarrantyClaimSuccessNotice(_successClaim!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!warranty.isShipped) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: AppTint.ornamentOnDark,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIcons.info,
                    color: theme.colorScheme.primary,
                    size: AppIconSize.normal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.orderWarrantyNotStartedNotice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (warranty.shippedOn != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.warehouse,
                      size: AppIconSize.dense,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.orderWarrantyShippedOn(
                        date.format(warranty.shippedOn!),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            for (final it in warranty.items)
              _WarrantyItemTile(item: it, date: date),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _showClaimDialog,
              icon: const Icon(AppIcons.edit),
              label: Text(l10n.orderWarrantyClaimAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _WarrantyItemTile extends StatelessWidget {
  const _WarrantyItemTile({
    required this.item,
    required this.date,
  });

  final OrderWarrantyItem item;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final title = item.itemName != null && item.itemName!.isNotEmpty
        ? item.itemName!
        : item.itemCode;

    final subtitle = item.until != null
        ? '${l10n.orderWarrantyPeriodDays(item.days)} '
              '(${l10n.orderWarrantyUntil(date.format(item.until!))})'
        : l10n.orderWarrantyStatusNoWarranty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.item,
            size: AppIconSize.dense,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
          StatusChip(
            label: item.localizedStatus(l10n),
            intent: item.statusIntent,
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(
          alpha: AppTint.surface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: theme.colorScheme.error.withValues(
            alpha: AppTint.ornamentOnDark,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.danger,
            color: theme.colorScheme.error,
            size: AppIconSize.small,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
