import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The one place that asks the server to start production.
///
/// Extracted when the order screen needed the same action the order list
/// already had. Two copies of this would not have stayed the same for long:
/// the interesting part is not the call but everything after it — a refusal
/// arrives as a *result*, carrying the materials the shelf is short of, and a
/// second copy would sooner or later show "Ошибка" instead of that list.
///
/// Readiness is never judged here. The client does not count stock and does
/// not decide the button should be hidden; it sends the intent and shows what
/// the server answered. The server is the source of truth — `PLAN.md`.
class StartProductionButton extends ConsumerStatefulWidget {
  const StartProductionButton({
    required this.salesOrder,
    required this.onStarted,
    super.key,
  });

  final String salesOrder;

  /// Called after the server confirms a start, so the caller can reload
  /// whatever it shows. Awaited: the refresh is part of the action, and
  /// leaving it unawaited would re-enable the button before the new state
  /// arrived.
  final Future<void> Function() onStarted;

  @override
  ConsumerState<StartProductionButton> createState() =>
      _StartProductionButtonState();
}

class _StartProductionButtonState extends ConsumerState<StartProductionButton> {
  bool _isStarting = false;

  Future<void> _handleStartProduction() async {
    if (_isStarting) return;

    setState(() => _isStarting = true);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);

    try {
      final result = await ref
          .read(productionCommandRepositoryProvider)
          .start(widget.salesOrder);

      if (!mounted) return;

      if (result.started) {
        if (result.toppedUp) {
          messenger.showDone(l10n.ordersTopUpSuccess(widget.salesOrder));
        } else {
          messenger.showDone(l10n.ordersStartSuccess(widget.salesOrder));
        }
        await widget.onStarted();
      } else if (result.blocked) {
        messenger.showFailureMessage(
          l10n.ordersBlockedSummary(widget.salesOrder),
        );

        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.ordersBlockedTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message ?? l10n.ordersBlockedBody),
                if (result.blockingMaterials.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (final m in result.blockingMaterials)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        '• ${m.itemCode}: '
                        '${quantity.format(m.shortageQty)}'
                        '${m.uom != null ? ' ${m.uom}' : ''}',
                        style: Theme.of(dialogContext).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.actionClose),
              ),
            ],
          ),
        );
      } else if (result.status == 'already_started') {
        messenger.showDone(l10n.ordersAlreadyStarted(widget.salesOrder));
      } else if (result.status == 'nothing_to_start') {
        messenger.showDone(l10n.ordersNothingToStart(widget.salesOrder));
      } else {
        messenger.showDone(result.message ?? result.status);
      }
    } on MutationQueued {
      if (!mounted) return;
      messenger.showFailureMessage(l10n.outboxQueued);
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return FilledButton.icon(
      onPressed: _isStarting ? null : _handleStartProduction,
      icon: _isStarting
          ? SizedBox(
              width: AppIconSize.dense,
              height: AppIconSize.dense,
              child: CircularProgressIndicator(
                strokeWidth: AppStroke.hairline + 1,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : const Icon(AppIcons.workOrder, size: AppIconSize.small),
      label: Text(l10n.ordersActionStartProduction),
    );
  }
}
