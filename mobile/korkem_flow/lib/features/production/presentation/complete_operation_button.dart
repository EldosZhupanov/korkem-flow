import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/enquiry_flow/application/image_picker_service.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/crew.dart';
import 'package:korkem_flow/features/piece_work/presentation/crew_dialog.dart';
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

  /// Optional, and only offered once some scrap is entered.
  XFile? _defectPhoto;

  /// Who did the stage together; `null` — the person booking it.
  List<CrewShare>? _crew;

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
            crew: _crew,
          );

      if (!mounted) return;

      if (result.status == 'completed' ||
          result.status == 'partially_completed' ||
          result.status == 'ok') {
        Navigator.of(context).pop();
        messenger.showDone(l10n.completeOperationSuccess(opTitle));
        await _sendDefectPhoto(result.jobCard, scrapQty, messenger, l10n);
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
      messenger.showFailureMessage(
        _defectPhoto == null ? l10n.outboxQueued : l10n.defectPhotoNotSent,
      );
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

  /// The stage is already booked when this runs, so a failed photo must not
  /// read as a failed stage: it says so in its own words.
  Future<void> _sendDefectPhoto(
    String? jobCard,
    double scrapQty,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    final photo = _defectPhoto;
    if (photo == null || jobCard == null || scrapQty <= 0) return;
    try {
      await ref
          .read(productionCommandRepositoryProvider)
          .attachDefectPhoto(jobCard: jobCard, photo: photo);
    } on Object {
      messenger.showFailureMessage(l10n.defectPhotoNotSent);
    }
  }

  Future<void> _pickCrew(String operation) async {
    final crew = await pickCrew(context, operation: operation);
    if (crew != null && mounted) setState(() => _crew = crew);
  }

  Future<void> _pickDefectPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final photo = await ref
          .read(imagePickerServiceProvider)
          .pickImageFromCamera();
      if (photo != null && mounted) setState(() => _defectPhoto = photo);
    } on Object {
      messenger.showFailureMessage(l10n.defectPhotoCameraFailed);
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
              // The estimate is the operation's real rate from the server, and
              // only when it has one. It used to be a fixed 150 ₸ a piece —
              // a number nobody set, shown to people about their own pay.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _qtyController,
                builder: (context, val, _) {
                  final parsedQty = double.tryParse(val.text.trim()) ?? 0.0;
                  final rate = ref
                      .watch(pieceRatesProvider)
                      .value
                      ?.perPieceFor(opTitle);
                  if (parsedQty <= 0 || rate == null) {
                    return const SizedBox.shrink();
                  }
                  final estimate = NumberFormat.currency(
                    locale: Localizations.localeOf(context).toLanguageTag(),
                    symbol: '₸',
                    decimalDigits: 0,
                  ).format(parsedQty * rate);
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.quote,
                          size: AppIconSize.dense,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.pieceWorkEstimate(estimate),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _CrewRow(
                crew: _crew,
                enabled: !_isSubmitting,
                onPick: () => _pickCrew(opTitle),
                onClear: () => setState(() => _crew = null),
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
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _scrapController,
                builder: (context, val, _) {
                  final scrap = double.tryParse(val.text.trim()) ?? 0.0;
                  if (scrap <= 0) return const SizedBox.shrink();
                  final photo = _defectPhoto;
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: photo == null
                        ? OutlinedButton.icon(
                            key: const ValueKey('defectPhotoAdd'),
                            onPressed: _isSubmitting ? null : _pickDefectPhoto,
                            icon: const Icon(
                              AppIcons.camera,
                              size: AppIconSize.dense,
                            ),
                            label: Text(l10n.defectPhotoAdd),
                          )
                        : Row(
                            children: [
                              const Icon(
                                AppIcons.check,
                                size: AppIconSize.dense,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(child: Text(l10n.defectPhotoChosen)),
                              TextButton(
                                key: const ValueKey('defectPhotoRemove'),
                                onPressed: _isSubmitting
                                    ? null
                                    : () => setState(() => _defectPhoto = null),
                                child: Text(l10n.defectPhotoRemove),
                              ),
                            ],
                          ),
                  );
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

/// «Made together…», or the crew already chosen with a way to drop it.
class _CrewRow extends StatelessWidget {
  const _CrewRow({
    required this.crew,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final List<CrewShare>? crew;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chosen = crew;
    if (chosen == null) {
      return TextButton.icon(
        key: const ValueKey('stageCrewPick'),
        onPressed: enabled ? onPick : null,
        icon: const Icon(AppIcons.team, size: AppIconSize.dense),
        label: Text(l10n.crewMadeTogether),
      );
    }
    return Row(
      children: [
        const Icon(AppIcons.team, size: AppIconSize.dense),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(l10n.crewChosen(chosen.length))),
        TextButton(
          key: const ValueKey('stageCrewClear'),
          onPressed: enabled ? onClear : null,
          child: Text(l10n.crewClear),
        ),
      ],
    );
  }
}
