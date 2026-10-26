import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Piece-rate pay: my own work for everybody; approvals, rates and
/// coefficients for the administrator and the production manager.
class PieceWorkScreen extends ConsumerWidget {
  const PieceWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mine = ref.watch(myPieceWorkProvider);
    final rates = ref.watch(pieceRatesProvider).value;
    final canEdit = rates?.canEdit ?? false;

    Future<void> refresh() async {
      ref
        ..invalidate(myPieceWorkProvider)
        ..invalidate(pieceRatesProvider)
        ..invalidate(pendingPieceWorkProvider);
      await ref.read(myPieceWorkProvider.future);
    }

    return AppScreen(
      title: l10n.pieceWorkTitle,
      actions: [
        IconButton(
          tooltip: l10n.actionRefresh,
          icon: const Icon(AppIcons.refresh),
          onPressed: refresh,
        ),
      ],
      body: mine.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(error: error, onRetry: refresh),
        data: (work) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ReadableWidth(child: _Totals(work: work)),
              if (canEdit) ...[
                const SizedBox(height: AppSpacing.xl),
                const ReadableWidth(child: _Approvals()),
                const SizedBox(height: AppSpacing.xl),
                ReadableWidth(child: _Rates(rates: rates!)),
              ],
              const SizedBox(height: AppSpacing.xl),
              ReadableWidth(child: SectionLabel(l10n.pieceWorkMine)),
              if (work.entries.isEmpty)
                ReadableWidth(child: Text(l10n.pieceWorkNothingYet)),
              for (final entry in work.entries)
                ReadableWidth(child: _EntryTile(entry: entry)),
            ],
          ),
        ),
      ),
    );
  }
}

NumberFormat _money(BuildContext context) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol: '₸',
  decimalDigits: 0,
);

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _Totals extends StatelessWidget {
  const _Totals({required this.work});

  final MyPieceWork work;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    Widget row(String label, double value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            money.format(value),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
    return AppCard(
      key: const ValueKey('pieceWorkTotals'),
      child: Column(
        children: [
          row(l10n.pieceWorkPending, work.pending),
          row(l10n.pieceWorkApproved, work.approved),
          row(l10n.pieceWorkPaid, work.paid),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final PieceWorkEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final unit = entry.unit == 'm2' ? 'м²' : l10n.pieceWorkPcs;
    final factor = entry.factor > 1
        ? ' × ${_plain(entry.factor)} (${entry.shift})'
        : '';
    final (label, intent) = switch (entry.status) {
      PieceWorkEntry.pending => (l10n.pieceWorkPending, StatusIntent.warning),
      PieceWorkEntry.approved => (l10n.pieceWorkApproved, StatusIntent.success),
      PieceWorkEntry.paid => (l10n.pieceWorkPaid, StatusIntent.info),
      _ => (l10n.pieceWorkRejected, StatusIntent.neutral),
    };
    return Card(
      child: ListTile(
        title: Text('${entry.operation} · ${_plain(entry.quantity)} $unit'),
        subtitle: Text(
          [
            '${money.format(entry.rate)} / $unit$factor',
            if (entry.reason != null && entry.reason!.isNotEmpty) entry.reason!,
          ].join('\n'),
        ),
        isThreeLine: entry.reason != null && entry.reason!.isNotEmpty,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money.format(entry.amount)),
            StatusChip(label: label, intent: intent, compact: true),
          ],
        ),
      ),
    );
  }
}

class _Approvals extends ConsumerWidget {
  const _Approvals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(pendingPieceWorkProvider);
    final money = _money(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.pieceWorkToApprove),
        pending.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('$error'),
          data: (rows) => rows.isEmpty
              ? Text(l10n.pieceWorkNothingToApprove)
              : Column(
                  children: [
                    for (final entry in rows)
                      Card(
                        key: ValueKey('pending:${entry.entry}'),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.employeeName} · ${entry.operation} · '
                                '${_plain(entry.quantity)}',
                              ),
                              Text(
                                money.format(entry.amount),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    key: ValueKey('reject:${entry.entry}'),
                                    onPressed: () =>
                                        _reject(context, ref, entry),
                                    child: Text(l10n.pieceWorkReject),
                                  ),
                                  FilledButton(
                                    key: ValueKey('approve:${entry.entry}'),
                                    onPressed: () =>
                                        _approve(context, ref, entry),
                                    child: Text(l10n.pieceWorkApprove),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    PieceWorkEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(pieceWorkRepositoryProvider).approve(entry.entry);
      ref.invalidate(pendingPieceWorkProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    PieceWorkEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final reason = await showReasonDialog(
      context,
      title: l10n.pieceWorkReject,
      label: l10n.pieceWorkReason,
      confirm: l10n.pieceWorkReject,
      cancel: l10n.actionCancel,
      fieldKey: const ValueKey('rejectReason'),
    );
    if (reason == null) return;
    try {
      await ref.read(pieceWorkRepositoryProvider).reject(entry.entry, reason);
      ref.invalidate(pendingPieceWorkProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

class _Rates extends ConsumerWidget {
  const _Rates({required this.rates});

  final PieceRates rates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final off = l10n.pieceWorkNoCoefficient;
    final overtimeFactor = rates.overtimeFactor;
    final weekendFactor = rates.weekendFactor;
    final shiftEnd = (rates.shiftEnd ?? '').split(':').take(2).join(':');
    final overtime = overtimeFactor == null
        ? off
        : '×${_plain(overtimeFactor)} ${l10n.pieceWorkAfter} $shiftEnd';
    final weekend = weekendFactor == null ? off : '×${_plain(weekendFactor)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(l10n.pieceWorkRates)),
            IconButton(
              key: const ValueKey('pieceRateAdd'),
              tooltip: l10n.pieceWorkAddRate,
              icon: const Icon(AppIcons.add),
              onPressed: () => _editRate(context, ref, null),
            ),
          ],
        ),
        for (final rate in rates.rates)
          Card(
            child: ListTile(
              key: ValueKey('pieceRate:${rate.operation}'),
              title: Text(rate.operation),
              subtitle: rate.enabled ? null : Text(l10n.pieceWorkDisabled),
              trailing: Text(
                '${money.format(rate.rate)} / ${_unitOf(rate, l10n)}',
              ),
              onTap: () => _editRate(context, ref, rate),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: ListTile(
            key: const ValueKey('pieceRulesEdit'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.pieceWorkCoefficients),
            subtitle: Text(
              '${l10n.pieceWorkOvertime}: $overtime\n'
              '${l10n.pieceWorkWeekend}: $weekend',
            ),
            trailing: const Icon(AppIcons.edit),
            onTap: () => _editRules(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _editRate(
    BuildContext context,
    WidgetRef ref,
    PieceRate? rate,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<PieceRate>(
      context: context,
      builder: (_) => _RateDialog(rate: rate),
    );
    if (result == null) return;
    try {
      await ref
          .read(pieceWorkRepositoryProvider)
          .setRate(
            operation: result.operation,
            rateType: result.rateType,
            rate: result.rate,
            enabled: result.enabled,
          );
      ref.invalidate(pieceRatesProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<void> _editRules(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<PieceRates>(
      context: context,
      builder: (_) => _RulesDialog(rates: rates),
    );
    if (result == null) return;
    try {
      await ref
          .read(pieceWorkRepositoryProvider)
          .saveRules(
            shiftEnd: result.shiftEnd,
            overtimeFactor: result.overtimeFactor,
            weekendFactor: result.weekendFactor,
            saturdayIsWeekend: result.saturdayIsWeekend,
            sundayIsWeekend: result.sundayIsWeekend,
          );
      ref.invalidate(pieceRatesProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

class _RateDialog extends StatefulWidget {
  const _RateDialog({this.rate});

  final PieceRate? rate;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final _operation = TextEditingController(
    text: widget.rate?.operation ?? '',
  );
  late final _value = TextEditingController(
    text: widget.rate == null ? '' : _plain(widget.rate!.rate),
  );
  late String _type = widget.rate?.rateType ?? PieceRate.perPart;
  late bool _enabled = widget.rate?.enabled ?? true;

  @override
  void dispose() {
    _operation.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.rate?.operation ?? l10n.pieceWorkAddRate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.rate == null)
            TextField(
              key: const ValueKey('pieceRateOperation'),
              controller: _operation,
              decoration: InputDecoration(
                labelText: l10n.pieceWorkOperation,
                helperText: l10n.pieceWorkOperationHint,
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: [
              DropdownMenuItem(
                value: PieceRate.perPart,
                child: Text(l10n.pieceWorkPerPiece),
              ),
              const DropdownMenuItem(value: PieceRate.perM2, child: Text('м²')),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          TextField(
            key: const ValueKey('pieceRateValue'),
            controller: _value,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.pieceWorkRate,
              suffixText: '₸',
            ),
          ),
          if (widget.rate != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pieceWorkEnabled),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('pieceRateSave'),
          onPressed: () {
            final value = double.tryParse(_value.text);
            final operation = _operation.text.trim();
            if (value == null || value <= 0 || operation.isEmpty) return;
            Navigator.of(context).pop(
              PieceRate(
                operation: operation,
                rateType: _type,
                rate: value,
                enabled: _enabled,
              ),
            );
          },
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}

class _RulesDialog extends StatefulWidget {
  const _RulesDialog({required this.rates});

  final PieceRates rates;

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  late final _shiftEnd = TextEditingController(
    text: (widget.rates.shiftEnd ?? '').split(':').take(2).join(':'),
  );
  late final _overtime = TextEditingController(
    text: widget.rates.overtimeFactor == null
        ? ''
        : _plain(widget.rates.overtimeFactor!),
  );
  late final _weekend = TextEditingController(
    text: widget.rates.weekendFactor == null
        ? ''
        : _plain(widget.rates.weekendFactor!),
  );
  late bool _saturday = widget.rates.saturdayIsWeekend;
  late bool _sunday = widget.rates.sundayIsWeekend;

  @override
  void dispose() {
    _shiftEnd.dispose();
    _overtime.dispose();
    _weekend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final number = [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))];
    return AlertDialog(
      title: Text(l10n.pieceWorkCoefficients),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('pieceRulesShiftEnd'),
              controller: _shiftEnd,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: l10n.pieceWorkShiftEnd,
                hintText: '18:00',
              ),
            ),
            TextField(
              key: const ValueKey('pieceRulesOvertime'),
              controller: _overtime,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: number,
              decoration: InputDecoration(
                labelText: '${l10n.pieceWorkOvertime} (×)',
                helperText: l10n.facadeRulesEmptyMeansOff,
              ),
            ),
            TextField(
              key: const ValueKey('pieceRulesWeekend'),
              controller: _weekend,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: number,
              decoration: InputDecoration(
                labelText: '${l10n.pieceWorkWeekend} (×)',
                helperText: l10n.facadeRulesEmptyMeansOff,
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pieceWorkSaturdayOff),
              value: _saturday,
              onChanged: (v) => setState(() => _saturday = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.pieceWorkSundayOff),
              value: _sunday,
              onChanged: (v) => setState(() => _sunday = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('pieceRulesSave'),
          onPressed: () {
            final shift = _shiftEnd.text.trim();
            Navigator.of(context).pop(
              PieceRates(
                rates: widget.rates.rates,
                canEdit: true,
                shiftEnd: shift.isEmpty ? null : '$shift:00',
                overtimeFactor: double.tryParse(_overtime.text),
                weekendFactor: double.tryParse(_weekend.text),
                saturdayIsWeekend: _saturday,
                sundayIsWeekend: _sunday,
              ),
            );
          },
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}

/// What one rate is paid per: a square metre or a piece.
String _unitOf(PieceRate rate, AppLocalizations l10n) =>
    rate.rateType == PieceRate.perM2 ? 'м²' : l10n.pieceWorkPcs;
