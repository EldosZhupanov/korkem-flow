import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_paint_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Asks what the customer brought of his own paint — «2 банки × 3 л» —
/// and records it as here. Null when the manager cancelled.
Future<String?> askClientPaint(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showReasonDialog(
    context,
    title: l10n.mdfClientPaintBrought,
    label: l10n.mdfClientPaintWhat,
    confirm: l10n.mdfPaintSave,
    cancel: l10n.actionCancel,
    fieldKey: const ValueKey('mdfClientPaintNote'),
  );
}

/// The order card's line for the customer's own paint (owner, 14.11.2026):
/// what he brought, and whether it is here — until it is, the painter sees
/// «ждём краску».
class MdfClientPaintView extends ConsumerStatefulWidget {
  const MdfClientPaintView({required this.order, super.key});

  final MdfOrder order;

  @override
  ConsumerState<MdfClientPaintView> createState() => _MdfClientPaintViewState();
}

class _MdfClientPaintViewState extends ConsumerState<MdfClientPaintView> {
  bool _busy = false;

  Future<void> _brought() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = await askClientPaint(context);
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(mdfOrderRepositoryProvider)
          .setClientPaint(widget.order.name, note: note, received: true);
      ref
        ..invalidate(mdfOrderProvider(widget.order.name))
        ..invalidate(mdfPaintBoardProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paint = widget.order.clientPaint;
    if (paint == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${l10n.mdfTagClientPaint}: ${paint.note ?? '—'}',
            key: const ValueKey('mdfClientPaint'),
          ),
          StatusChip(
            label: paint.received
                ? l10n.mdfClientPaintHere
                : l10n.mdfClientPaintWaiting,
            intent: paint.received
                ? StatusIntent.success
                : StatusIntent.warning,
          ),
          TextButton(
            key: const ValueKey('mdfClientPaintBrought'),
            onPressed: _busy ? null : _brought,
            child: Text(l10n.mdfClientPaintBrought),
          ),
        ],
      ),
    );
  }
}
