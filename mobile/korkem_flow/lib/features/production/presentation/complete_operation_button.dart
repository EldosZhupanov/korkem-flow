import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/features/production/domain/work_order_operation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The button and dialog asking the server to complete a work order operation.
///
/// Refusals arrive as results rather than exceptions; offline mutations
/// are queued in the outbox; idempotency is handled by the repository.
class CompleteOperationButton extends ConsumerWidget {
  const CompleteOperationButton({
    required this.workOrder,
    required this.operation,
    required this.orderQty,
    required this.onCompleted,
    super.key,
  });

  final String workOrder;
  final WorkOrderOperation operation;
  final double orderQty;
  final Future<void> Function() onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return FilledButton.tonalIcon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => _CompleteOperationDialog(
          workOrder: workOrder,
          operation: operation,
          orderQty: orderQty,
          onCompleted: onCompleted,
        ),
      ),
      icon: const Icon(AppIcons.check, size: AppIconSize.dense),
      label: Text(l10n.completeOperationAction),
    );
  }
}

class _CompleteOperationDialog extends ConsumerStatefulWidget {
  const _CompleteOperationDialog({
    required this.workOrder,
    required this.operation,
    required this.orderQty,
    required this.onCompleted,
  });

  final String workOrder;
  final WorkOrderOperation operation;
  final double orderQty;
  final Future<void> Function() onCompleted;

  @override
  ConsumerState<_CompleteOperationDialog> createState() =>
      _CompleteOperationDialogState();
}

class _CompleteOperationDialogState
    extends ConsumerState<_CompleteOperationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyController;
  late final TextEditingController _scrapController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final remaining = (widget.orderQty - widget.operation.completedQty).clamp(
      0.0,
      double.infinity,
    );
    final initialQty = remaining > 0 ? remaining : widget.orderQty;
    final qtyFormatted = initialQty.truncateToDouble() == initialQty
        ? initialQty.toInt().toString()
        : initialQty.toString();

    _qtyController = TextEditingController(text: qtyFormatted);
    _scrapController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _scrapController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opTitle = widget.operation.operation ?? widget.operation.name;

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final scrapQty = double.tryParse(_scrapController.text.trim()) ?? 0.0;

    try {
      final result = await ref
          .read(productionCommandRepositoryProvider)
          .completeOperation(
            workOrder: widget.workOrder,
            operation: widget.operation.operation ?? widget.operation.name,
            qty: qty,
            scrapQty: scrapQty,
          );

      if (!mounted) return;

      if (result.status == 'completed' || result.status == 'ok') {
        Navigator.of(context).pop();
        messenger.showDone(l10n.completeOperationSuccess(opTitle));
        await widget.onCompleted();
      } else if (result.alreadyComplete) {
        Navigator.of(context).pop();
        messenger.showDone(l10n.completeOperationAlreadyComplete);
        await widget.onCompleted();
      } else {
        // Refusal or blocked response from server
        Navigator.of(context).pop();
        messenger.showFailureMessage(
          result.message ?? l10n.completeOperationBlockedTitle,
        );
      }
    } on MutationQueued {
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showFailureMessage(l10n.outboxQueued);
      await widget.onCompleted();
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
    final opTitle = widget.operation.operation ?? widget.operation.name;

    return AlertDialog(
      title: Text(l10n.completeOperationTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                opTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.completeOperationQtyLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.completeOperationInvalidQty;
                  }
                  final num = double.tryParse(value.trim());
                  if (num == null || num < 0) {
                    return l10n.completeOperationInvalidQty;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _scrapController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.completeOperationScrapQtyLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.completeOperationInvalidQty;
                  }
                  final num = double.tryParse(value.trim());
                  if (num == null || num < 0) {
                    return l10n.completeOperationInvalidQty;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? SizedBox(
                  width: AppIconSize.dense,
                  height: AppIconSize.dense,
                  child: CircularProgressIndicator(
                    strokeWidth: AppStroke.hairline + 1,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(l10n.completeOperationAction),
        ),
      ],
    );
  }
}
