import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The button that opens a dialog to select a material request and create a
/// purchase order with a supplier.
///
/// Refusals arrive as results rather than exceptions; offline mutations
/// are queued in the outbox; idempotency is handled by the repository.
class CreatePurchaseOrderButton extends ConsumerWidget {
  const CreatePurchaseOrderButton({
    required this.onOrdered,
    this.initialMaterialRequest,
    super.key,
  });

  final String? initialMaterialRequest;
  final Future<void> Function() onOrdered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return OutlinedButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => _CreatePurchaseOrderDialog(
          initialMaterialRequest: initialMaterialRequest,
          onOrdered: onOrdered,
        ),
      ),
      icon: const Icon(AppIcons.quote, size: AppIconSize.small),
      label: Text(l10n.warehouseActionPurchaseOrder),
    );
  }
}

class _CreatePurchaseOrderDialog extends ConsumerStatefulWidget {
  const _CreatePurchaseOrderDialog({
    required this.onOrdered,
    this.initialMaterialRequest,
  });

  final String? initialMaterialRequest;
  final Future<void> Function() onOrdered;

  @override
  ConsumerState<_CreatePurchaseOrderDialog> createState() =>
      _CreatePurchaseOrderDialogState();
}

class _CreatePurchaseOrderDialogState
    extends ConsumerState<_CreatePurchaseOrderDialog> {
  String? _selectedMr;
  late final TextEditingController _supplierController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMr = widget.initialMaterialRequest;
    _supplierController = TextEditingController();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(String materialRequest) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final supplier = _supplierController.text.trim().isEmpty
        ? null
        : _supplierController.text.trim();

    try {
      final result = await ref
          .read(receivingRepositoryProvider)
          .order(materialRequest, supplier: supplier);

      if (!mounted) return;

      if (result.placed) {
        Navigator.of(context).pop();
        messenger.showDone(
          l10n.purchaseOrderSuccess(result.purchaseOrder!),
        );
        await widget.onOrdered();
      } else {
        Navigator.of(context).pop();
        messenger.showFailureMessage(
          result.message ?? l10n.purchaseOrderBlockedTitle,
        );
      }
    } on MutationQueued {
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showFailureMessage(l10n.outboxQueued);
      await widget.onOrdered();
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

    final requestsAsync = ref.watch(orderableMaterialRequestsProvider);
    final effectiveMr =
        _selectedMr ??
        (requestsAsync.value?.isNotEmpty == true
            ? requestsAsync.value!.first.name
            : null);

    return AlertDialog(
      title: Text(l10n.createPurchaseOrderDialogTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: switch (requestsAsync) {
          AsyncLoading() => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          AsyncError(:final error) => SizedBox(
            height: 160,
            child: ErrorView(
              error: error,
              onRetry: () => ref.invalidate(orderableMaterialRequestsProvider),
            ),
          ),
          AsyncData(:final value) when value.isEmpty => EmptyView(
            icon: AppIcons.quote,
            title: l10n.orderableNoRequestsTitle,
            message: l10n.orderableNoRequestsBody,
          ),
          AsyncData(:final value) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RequestsList(
                requests: value,
                selectedMr: effectiveMr,
                onSelected: (mr) => setState(() => _selectedMr = mr),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _supplierController,
                decoration: InputDecoration(
                  labelText: l10n.supplierFieldLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        },
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: effectiveMr == null || _isSubmitting
              ? null
              : () => _handleSubmit(effectiveMr),
          child: _isSubmitting
              ? SizedBox(
                  width: AppIconSize.dense,
                  height: AppIconSize.dense,
                  child: CircularProgressIndicator(
                    strokeWidth: AppStroke.hairline + 1,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(l10n.warehouseActionPurchaseOrder),
        ),
      ],
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.selectedMr,
    required this.onSelected,
  });

  final List<OrderableMaterialRequest> requests;
  final String? selectedMr;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: RadioGroup<String?>(
        groupValue: selectedMr,
        onChanged: (val) {
          if (val != null) onSelected(val);
        },
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: requests.length,
          separatorBuilder: (_, _) => const Divider(height: AppStroke.hairline),
          itemBuilder: (context, index) {
            final request = requests[index];
            final title = request.neededOn != null
                ? l10n.materialRequestNeededDate(request.neededOn!)
                : request.name;

            final subtitleParts = <String>[request.name];
            if (request.requestedOn != null) {
              subtitleParts.add(request.requestedOn!);
            }
            if (request.orderedPercent > 0) {
              subtitleParts.add(
                '${request.orderedPercent.toStringAsFixed(0)}%',
              );
            }

            return RadioListTile<String?>(
              value: request.name,
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
              contentPadding: EdgeInsets.zero,
            );
          },
        ),
      ),
    );
  }
}
