import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The button that opens a dialog to select and receive an open purchase order
/// into the warehouse.
///
/// Refusals arrive as results rather than exceptions; offline mutations
/// are queued in the outbox; idempotency is handled by the repository.
class ReceiveDeliveryButton extends ConsumerWidget {
  const ReceiveDeliveryButton({
    required this.onReceived,
    this.initialPurchaseOrder,
    super.key,
  });

  final String? initialPurchaseOrder;
  final Future<void> Function() onReceived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return FilledButton.tonalIcon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => _ReceiveDeliveryDialog(
          initialPurchaseOrder: initialPurchaseOrder,
          onReceived: onReceived,
        ),
      ),
      icon: const Icon(AppIcons.warehouse, size: AppIconSize.small),
      label: Text(l10n.warehouseActionReceive),
    );
  }
}

class _ReceiveDeliveryDialog extends ConsumerStatefulWidget {
  const _ReceiveDeliveryDialog({
    required this.onReceived,
    this.initialPurchaseOrder,
  });

  final String? initialPurchaseOrder;
  final Future<void> Function() onReceived;

  @override
  ConsumerState<_ReceiveDeliveryDialog> createState() =>
      _ReceiveDeliveryDialogState();
}

class _ReceiveDeliveryDialogState
    extends ConsumerState<_ReceiveDeliveryDialog> {
  String? _selectedPo;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPo = widget.initialPurchaseOrder;
  }

  Future<void> _handleSubmit(String purchaseOrder) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      final result = await ref
          .read(receivingRepositoryProvider)
          .receive(purchaseOrder);

      if (!mounted) return;

      if (result.booked) {
        Navigator.of(context).pop();
        messenger.showDone(l10n.receiveSuccess(result.purchaseReceipt!));
        await widget.onReceived();
      } else if (result.status == 'nothing_outstanding') {
        Navigator.of(context).pop();
        messenger.showDone(
          result.message ?? l10n.receiveNothingOutstanding,
        );
        await widget.onReceived();
      } else {
        Navigator.of(context).pop();
        messenger.showFailureMessage(
          result.message ?? l10n.receiveBlockedTitle,
        );
      }
    } on MutationQueued {
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showFailureMessage(l10n.outboxQueued);
      await widget.onReceived();
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final currencyFormat = NumberFormat.decimalPattern(locale);

    final ordersAsync = ref.watch(receivablePurchaseOrdersProvider);
    final effectivePo =
        _selectedPo ??
        (ordersAsync.value?.isNotEmpty == true
            ? ordersAsync.value!.first.name
            : null);

    return AlertDialog(
      title: Text(l10n.receiveDeliveryDialogTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: switch (ordersAsync) {
          AsyncLoading() => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          AsyncError(:final error) => SizedBox(
            height: 160,
            child: ErrorView(
              error: error,
              onRetry: () => ref.invalidate(receivablePurchaseOrdersProvider),
            ),
          ),
          AsyncData(:final value) when value.isEmpty => EmptyView(
            icon: AppIcons.warehouse,
            title: l10n.receiveNoOrdersTitle,
            message: l10n.receiveNoOrdersBody,
          ),
          AsyncData(:final value) => _OrdersList(
            orders: value,
            selectedPo: effectivePo,
            currencyFormat: currencyFormat,
            onSelected: (po) => setState(() => _selectedPo = po),
          ),
        },
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: effectivePo == null || _isSubmitting
              ? null
              : () => _handleSubmit(effectivePo),
          child: _isSubmitting
              ? SizedBox(
                  width: AppIconSize.dense,
                  height: AppIconSize.dense,
                  child: CircularProgressIndicator(
                    strokeWidth: AppStroke.hairline + 1,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(l10n.warehouseActionReceive),
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.selectedPo,
    required this.currencyFormat,
    required this.onSelected,
  });

  final List<ReceivablePurchaseOrder> orders;
  final String? selectedPo;
  final NumberFormat currencyFormat;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: RadioGroup<String?>(
        groupValue: selectedPo,
        onChanged: (val) {
          if (val != null) onSelected(val);
        },
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: orders.length,
          separatorBuilder: (_, _) => const Divider(height: AppStroke.hairline),
          itemBuilder: (context, index) {
            final order = orders[index];
            final title = order.supplier?.isNotEmpty == true
                ? order.supplier!
                : order.name;

            final subtitleParts = <String>[order.name];
            if (order.expectedOn != null) {
              subtitleParts.add(
                l10n.purchaseOrderExpectedDate(order.expectedOn!),
              );
            }
            if (order.receivedPercent > 0) {
              subtitleParts.add('${order.receivedPercent.toStringAsFixed(0)}%');
            }

            return RadioListTile<String?>(
              value: order.name,
              title: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                subtitleParts.join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              secondary: order.total > 0
                  ? Text(
                      '${currencyFormat.format(order.total)} ₸',
                      style: theme.textTheme.labelMedium,
                    )
                  : null,
              contentPadding: EdgeInsets.zero,
            );
          },
        ),
      ),
    );
  }
}
