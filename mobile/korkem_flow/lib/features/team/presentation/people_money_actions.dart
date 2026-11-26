import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/features/team/presentation/people_period.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// Money for people, one tap each (owner, 26.11.2026: «всё проще,
// интуитивно»): «+ Аванс, штраф, премия», «Отдать», «Да» / «Нет». Every
// rule — who may, when, what is closed — stays on the server (`payroll`);
// these only ask and refresh.

void _reload(ProviderContainer c) => c
  ..invalidate(peopleReportProvider)
  ..invalidate(personCardProvider);

ProviderContainer _container(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false);

/// An advance, a fine or a bonus, for one of [people] — with a login or
/// without: the pay is the person's (owner, 26.11.2026). [employee] chosen
/// in advance from a card. True when written.
Future<bool> showPayEntryDialog(
  BuildContext context, {
  required List<PersonRow> people,
  String? employee,
  PersonAdjustmentKind kind = PersonAdjustmentKind.advance,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PayEntryDialog(people: people, employee: employee, kind: kind),
    ) ??
    false;

/// «Отдать {name} {sum}?» — then the month is his paid.
Future<void> giveMonthPay(
  BuildContext context, {
  required String employee,
  required String name,
  required double amount,
  required DateTime day,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final c = _container(context);
  final sum = peopleMoney(context).format(amount);
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.pplGive),
      content: Text(l10n.pplGiveConfirm(name, sum)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('ppl:giveConfirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.pplGive),
        ),
      ],
    ),
  );
  if (sure != true) return;
  try {
    await c.read(pieceWorkRepositoryProvider).markPaid(employee, monthOf(day));
    _reload(c);
    messenger.showDone(l10n.pplGiveDone);
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// «Да» to an advance, a fine or a bonus somebody else entered.
Future<void> approvePay(BuildContext context, String adjustment) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final c = _container(context);
  try {
    await c.read(pieceWorkRepositoryProvider).approveAdjustment(adjustment);
    _reload(c);
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// «Нет» to one waiting, or «Отменить» one already counted — with the
/// reason the worker will read.
Future<void> cancelPay(
  BuildContext context,
  String adjustment, {
  bool waiting = true,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final c = _container(context);
  final reason = await showReasonDialog(
    context,
    title: waiting ? l10n.pplNo : l10n.pplCancelEntry,
    label: waiting ? l10n.pplWhyNo : l10n.pplCancelWhy,
    confirm: waiting ? l10n.pplNo : l10n.pplCancelEntry,
    cancel: l10n.actionCancel,
    fieldKey: const ValueKey('ppl:cancelWhy'),
  );
  if (reason == null) return;
  try {
    await c
        .read(pieceWorkRepositoryProvider)
        .reverseAdjustment(adjustment, reason);
    _reload(c);
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// The month's money as text Excel takes in, on the clipboard.
Future<void> copyMonthForExcel(BuildContext context, DateTime day) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final c = _container(context);
  try {
    final csv = await c
        .read(pieceWorkRepositoryProvider)
        .statementCsv(monthOf(day));
    await Clipboard.setData(ClipboardData(text: csv));
    messenger.showDone(l10n.pplCopied);
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

class _PayEntryDialog extends StatefulWidget {
  const _PayEntryDialog({
    required this.people,
    required this.kind,
    this.employee,
  });

  final List<PersonRow> people;
  final String? employee;
  final PersonAdjustmentKind kind;

  @override
  State<_PayEntryDialog> createState() => _PayEntryDialogState();
}

class _PayEntryDialogState extends State<_PayEntryDialog> {
  late String? _employee = widget.employee;
  late PersonAdjustmentKind _kind = widget.kind;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final amount = double.tryParse(
      _amount.text.replaceAll(' ', '').replaceAll(',', '.'),
    );
    final employee = _employee;
    if (employee == null ||
        amount == null ||
        amount <= 0 ||
        _reason.text.trim().isEmpty) {
      setState(() => _error = l10n.pplFillAll);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final c = _container(context);
    setState(() => _busy = true);
    try {
      final saved = await c
          .read(pieceWorkRepositoryProvider)
          .addAdjustment(
            employee: employee,
            kind: payKindName(_kind),
            amount: amount,
            reason: _reason.text.trim(),
          );
      _reload(c);
      messenger.showDone(
        saved.status == 'Approved' ? l10n.pplRecorded : l10n.pplRecordedWaiting,
      );
      navigator.pop(true);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.pplMoneyTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<PersonAdjustmentKind>(
                key: const ValueKey('ppl:entryKind'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PersonAdjustmentKind.advance,
                    label: Text(l10n.pplAdvance),
                  ),
                  ButtonSegment(
                    value: PersonAdjustmentKind.fine,
                    label: Text(l10n.pplFineOne),
                  ),
                  ButtonSegment(
                    value: PersonAdjustmentKind.bonus,
                    label: Text(l10n.pplBonusOne),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: const ValueKey('ppl:entryWho'),
                initialValue: _employee,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.pplWho),
                items: [
                  for (final p in widget.people)
                    DropdownMenuItem(value: p.employee, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() {
                  _employee = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('ppl:entryAmount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.pplHowMuch),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('ppl:entryWhy'),
                controller: _reason,
                decoration: InputDecoration(labelText: l10n.pplWhy),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error case final e?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  e,
                  key: const ValueKey('ppl:entryError'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('ppl:entrySave'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.pplRecord),
        ),
      ],
    );
  }
}
