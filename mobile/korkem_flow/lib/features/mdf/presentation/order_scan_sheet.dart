import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/my_work_repository.dart';
import 'package:korkem_flow/features/mdf/domain/order_scan.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A sticker read (or a number typed): the order and its stages, with
/// «Сделал» on the one that is the scanner's now (owner, 18.11.2026:
/// «рабочий сканирует телефоном и отмечает свой этап»).
Future<void> showOrderScan(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      builder: (_) => _OrderScanDialog(code: code.trim()),
    );

/// «Номер заказа» — for a sticker that will not read, or no scanner.
Future<void> showScanEntry(BuildContext context) async {
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _ScanEntryDialog(),
  );
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  await showOrderScan(context, code);
}

class _ScanEntryDialog extends StatefulWidget {
  const _ScanEntryDialog();

  @override
  State<_ScanEntryDialog> createState() => _ScanEntryDialogState();
}

class _ScanEntryDialogState extends State<_ScanEntryDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.scanEntryTitle),
      content: TextField(
        key: const ValueKey('scanEntryField'),
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.scanEntryHint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('scanEntryOpen'),
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(l10n.scanEntryOpen),
        ),
      ],
    );
  }
}

class _OrderScanDialog extends ConsumerStatefulWidget {
  const _OrderScanDialog({required this.code});

  final String code;

  @override
  ConsumerState<_OrderScanDialog> createState() => _OrderScanDialogState();
}

class _OrderScanDialogState extends ConsumerState<_OrderScanDialog> {
  OrderScan? _scan;
  Object? _error;
  String? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final scan = await ref.read(myWorkRepositoryProvider).scan(widget.code);
      if (mounted) setState(() => _scan = scan);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _tick(ScanStage stage, {bool undo = false}) async {
    final scan = _scan;
    if (scan == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = stage.stage.name);
    try {
      final next = await ref
          .read(myWorkRepositoryProvider)
          .tick(scan.order, stage.stage, undo: undo);
      ref.invalidate(myWorkProvider);
      if (mounted) setState(() => _scan = next);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scan = _scan;
    final Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (scan == null) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [
              '${scan.areaM2.toStringAsFixed(2)} м²',
              ?scan.decor,
              if (scan.deliveryDate != null)
                l10n.myWorkDue(mdfDay(scan.deliveryDate, year: false)),
            ].join(' · '),
            style: theme.textTheme.bodyMedium,
          ),
          if (scan.handedOver || scan.onHold)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                scan.handedOver ? l10n.scanHandedOver : l10n.scanOnHold,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          for (final s in scan.stages)
            _StageRow(
              stage: s,
              manager: scan.manager,
              busy: _busy == s.stage.name,
              onTick: _busy == null && !scan.handedOver
                  ? ({bool undo = false}) => _tick(s, undo: undo)
                  : null,
            ),
        ],
      );
    }
    return AlertDialog(
      key: const ValueKey('orderScan'),
      title: Text(
        scan == null
            ? widget.code
            : l10n.scanTitle(scan.number, scan.customer),
      ),
      content: SizedBox(
        width: AppBreakpoints.listPaneWidth,
        child: SingleChildScrollView(child: body),
      ),
      actions: [
        if (scan != null && scan.manager)
          TextButton.icon(
            key: const ValueKey('orderScanOpen'),
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(context.push(Routes.mdfOrder(scan.order)));
            },
            icon: const Icon(AppIcons.forward),
            label: Text(l10n.scanOpenOrder),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.manager,
    required this.busy,
    this.onTick,
  });

  final ScanStage stage;
  final bool manager;
  final bool busy;
  final void Function({bool undo})? onTick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final status = context.statusColors;
    final String note;
    if (stage.done) {
      note = l10n.scanDoneOn(mdfDay(stage.doneOn, year: false));
    } else if (stage.waitingFor.isNotEmpty) {
      note = l10n.myWorkWaiting(
        stage.waitingFor.map((s) => mdfStageLabel(s, l10n)).join(', '),
      );
    } else {
      note = stage.mine ? l10n.scanYours : l10n.scanNotYours;
    }
    final mayUndo = stage.done && (stage.byMe || manager);
    return Padding(
      key: ValueKey('orderScan:${stage.stage.name}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            stage.done ? AppIcons.check : AppIcons.schedule,
            size: AppIconSize.small,
            color: stage.done ? status.success : muted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mdfStageLabel(stage.stage, l10n),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          if (stage.canDo)
            FilledButton.icon(
              key: ValueKey('orderScanDone:${stage.stage.name}'),
              onPressed: busy || onTick == null ? null : () => onTick!(),
              icon: const Icon(AppIcons.check),
              label: Text(l10n.myWorkDoneButton),
            )
          else if (mayUndo)
            TextButton.icon(
              key: ValueKey('orderScanUndo:${stage.stage.name}'),
              onPressed: busy || onTick == null
                  ? null
                  : () => onTick!(undo: true),
              icon: const Icon(AppIcons.undo),
              label: Text(l10n.myWorkUndo),
            ),
        ],
      ),
    );
  }
}
