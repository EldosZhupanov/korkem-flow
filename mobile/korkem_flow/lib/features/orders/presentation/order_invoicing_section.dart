import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/orders/application/order_invoice_controller.dart';
import 'package:korkem_flow/features/orders/domain/order_invoice.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The Stage 12 Invoicing section displayed on the Sales Order screen.
class OrderInvoicingSection extends ConsumerWidget {
  const OrderInvoicingSection({required this.order, super.key});

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(orderInvoiceProvider(order.name));

    return switch (invoiceAsync) {
      AsyncData(:final value) => _InvoicingCard(
        order: order,
        invoice: value,
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(orderInvoiceProvider(order.name)),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _InvoicingCard extends ConsumerStatefulWidget {
  const _InvoicingCard({
    required this.order,
    required this.invoice,
  });

  final SalesOrder order;
  final OrderInvoice invoice;

  @override
  ConsumerState<_InvoicingCard> createState() => _InvoicingCardState();
}

class _InvoicingCardState extends ConsumerState<_InvoicingCard> {
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _createInvoice() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await ref
          .read(orderInvoiceActionsProvider)
          .draft(widget.order.name);
      if (mounted) {
        final invoiceNum = '${response['invoice'] ?? ''}';
        setState(() {
          _isSubmitting = false;
          _successMessage = invoiceNum.isNotEmpty
              ? l10n.orderInvoicingSuccessNotice(invoiceNum)
              : null;
        });
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final money = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );
    final date = DateFormat.yMMMd(locale);
    final invoice = widget.invoice;
    final isDraftOrder = widget.order.status == SalesOrderStatus.draft;
    final hasDeliveredItems = widget.order.perDelivered > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.orderInvoicingSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              StatusChip(
                label: invoice.status.localized(l10n),
                intent: invoice.status.intent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_errorMessage != null) ...[
            _ErrorNotice(message: _errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_successMessage != null) ...[
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
                      _successMessage!,
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
          if (invoice.hasInvoice) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldRow(
                    icon: AppIcons.quote,
                    label: '${l10n.orderInvoicingNumberLabel}: ${invoice.name}',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _FieldRow(
                    icon: AppIcons.deal,
                    label:
                        '${l10n.orderInvoicingTotalLabel}: '
                        '${money.format(invoice.grandTotal)}',
                  ),
                  if (invoice.postingDate != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _FieldRow(
                      icon: AppIcons.schedule,
                      label: date.format(invoice.postingDate!),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (isDraftOrder) ...[
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
                      l10n.orderInvoicingOrderNotSubmittedNotice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!hasDeliveredItems) ...[
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
                      l10n.orderInvoicingNoDeliveryNotice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _createInvoice,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: AppIconSize.small,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStroke.focus,
                      ),
                    )
                  : const Icon(AppIcons.quote),
              label: Text(l10n.orderInvoicingCreateAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: AppIconSize.dense,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
