import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/warehouse/data/receiving_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The button that asks the server to ship what is in stock against a sales
/// order.
///
/// Refusals arrive as results with server reasons; offline mutations are
/// queued in the outbox; idempotency is handled by the repository.
class CreateDeliveryButton extends ConsumerStatefulWidget {
  const CreateDeliveryButton({
    required this.salesOrder,
    required this.onDelivered,
    super.key,
  });

  final String salesOrder;

  /// Called after the server confirms delivery creation or when queued,
  /// so the order screen reloads its deliveries section.
  final Future<void> Function() onDelivered;

  @override
  ConsumerState<CreateDeliveryButton> createState() =>
      _CreateDeliveryButtonState();
}

class _CreateDeliveryButtonState extends ConsumerState<CreateDeliveryButton> {
  bool _isShipping = false;

  Future<void> _handleCreateDelivery() async {
    if (_isShipping) return;

    setState(() => _isShipping = true);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      final result = await ref
          .read(receivingRepositoryProvider)
          .ship(widget.salesOrder);

      if (!mounted) return;

      if (result.dispatched) {
        if (result.adjusted) {
          messenger.showDone(
            l10n.orderDeliveryAdjustedSuccess(result.deliveryNote!),
          );
        } else {
          messenger.showDone(l10n.orderDeliverySuccess(result.deliveryNote!));
        }
        await widget.onDelivered();
      } else if (result.status == 'already_delivered') {
        messenger.showDone(result.message ?? l10n.orderAlreadyDelivered);
        await widget.onDelivered();
      } else if (result.status == 'nothing_shippable' ||
          result.status == 'blocked') {
        messenger.showFailureMessage(
          result.message ?? l10n.orderNothingShippable,
        );

        if (result.message != null && result.message!.isNotEmpty) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.orderDeliveryBlockedTitle),
              content: Text(result.message!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.actionClose),
                ),
              ],
            ),
          );
        }
      } else {
        messenger.showDone(result.message ?? result.status);
      }
    } on MutationQueued {
      if (!mounted) return;
      messenger.showFailureMessage(l10n.outboxQueued);
      await widget.onDelivered();
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) {
        setState(() => _isShipping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: _isShipping ? null : _handleCreateDelivery,
      icon: _isShipping
          ? SizedBox(
              width: AppIconSize.dense,
              height: AppIconSize.dense,
              child: CircularProgressIndicator(
                strokeWidth: AppStroke.hairline + 1,
                color: theme.colorScheme.primary,
              ),
            )
          : const Icon(AppIcons.warehouse, size: AppIconSize.small),
      label: Text(l10n.ordersActionCreateDelivery),
    );
  }
}
