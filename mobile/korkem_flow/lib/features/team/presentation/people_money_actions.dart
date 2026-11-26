import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
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
/// in advance from a card. [atOnce]: the one asking is the owner, whose
/// entry needs no second «Да». [showBalance]: the people's money is this
/// month's, so «к выплате сейчас → станет» is true of it. True when written.
Future<bool> showPayEntryDialog(
  BuildContext context, {
  required List<PersonRow> people,
  String? employee,
  PersonAdjustmentKind kind = PersonAdjustmentKind.advance,
  bool atOnce = false,
  bool showBalance = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _PayEntryDialog(
        people: people,
        employee: employee,
        kind: kind,
        atOnce: atOnce,
        showBalance: showBalance,
      ),
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

/// Amounts a manager types most — one tap each.
const _quickAmounts = [10000, 20000, 50000, 100000];

List<String> _reasons(PersonAdjustmentKind kind, AppLocalizations l10n) =>
    switch (kind) {
      PersonAdjustmentKind.advance => [
        l10n.pplReasonAsked,
        l10n.pplReasonTravel,
        l10n.pplReasonTillPay,
      ],
      PersonAdjustmentKind.fine => [
        l10n.pplReasonDefect,
        l10n.pplReasonLate,
        l10n.pplReasonAbsent,
        l10n.pplReasonMaterial,
      ],
      PersonAdjustmentKind.bonus => [
        l10n.pplReasonPlan,
        l10n.pplReasonRush,
        l10n.pplReasonWeekend,
      ],
    };

String _kindHint(PersonAdjustmentKind kind, AppLocalizations l10n) =>
    switch (kind) {
      PersonAdjustmentKind.advance => l10n.pplKindAdvanceHint,
      PersonAdjustmentKind.fine => l10n.pplKindFineHint,
      PersonAdjustmentKind.bonus => l10n.pplKindBonusHint,
    };

/// «Аванс, штраф или премия» (owner, 26.11.2026: «при разных нажатиях
/// ценник стоит один и тот же»): the kind says which way the money goes —
/// minus for an advance and a fine, plus for a bonus — and, for this
/// month, what the person is owed before and after. An advance needs no
/// reason; a fine and a bonus do, the worker reads it.
class _PayEntryDialog extends StatefulWidget {
  const _PayEntryDialog({
    required this.people,
    required this.kind,
    required this.atOnce,
    required this.showBalance,
    this.employee,
  });

  final List<PersonRow> people;
  final String? employee;
  final PersonAdjustmentKind kind;
  final bool atOnce;
  final bool showBalance;

  @override
  State<_PayEntryDialog> createState() => _PayEntryDialogState();
}

class _PayEntryDialogState extends State<_PayEntryDialog> {
  late String? _employee = widget.employee;
  late PersonAdjustmentKind _kind = widget.kind;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _tried = false;
  bool _busy = false;

  /// Chosen on a card: the person is the title, not a list of one.
  bool get _fixed => widget.employee != null && widget.people.length == 1;

  double? get _value {
    final v = double.tryParse(
      _amount.text.replaceAll(' ', '').replaceAll(',', '.'),
    );
    return v != null && v > 0 ? v : null;
  }

  bool get _needsReason => _kind != PersonAdjustmentKind.advance;

  PersonRow? get _person {
    for (final p in widget.people) {
      if (p.employee == _employee) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final employee = _employee;
    final amount = _value;
    final reason = _reason.text.trim();
    if (employee == null || amount == null || (_needsReason && reason.isEmpty)) {
      setState(() => _tried = true);
      return;
    }
    final l10n = AppLocalizations.of(context);
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
            reason: reason,
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
    final status = context.statusColors;
    final money = peopleMoney(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final plus = _kind == PersonAdjustmentKind.bonus;
    final signColor = plus ? status.success : status.danger;
    final person = _person;
    final balance = widget.showBalance ? person?.money?.left : null;
    final value = _value;
    return AlertDialog(
      title: Text(_fixed ? person?.name ?? l10n.pplMoneyTitle : l10n.pplMoneyTitle),
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
                  for (final k in PersonAdjustmentKind.values)
                    ButtonSegment(value: k, label: Text(payKindLabel(k, l10n))),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _kindHint(_kind, l10n),
                key: const ValueKey('ppl:entryHint'),
                style: muted,
              ),
              const SizedBox(height: AppSpacing.md),
              if (!_fixed) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('ppl:entryWho'),
                  initialValue: _employee,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.pplWho,
                    errorText: _tried && _employee == null
                        ? l10n.pplWhoMissing
                        : null,
                  ),
                  items: [
                    for (final p in widget.people)
                      DropdownMenuItem(
                        value: p.employee,
                        child: Text(p.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _employee = v),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                key: const ValueKey('ppl:entryAmount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  labelText: l10n.pplHowMuch,
                  prefixText: plus ? '+ ' : '− ',
                  prefixStyle: theme.textTheme.titleLarge?.copyWith(
                    color: signColor,
                  ),
                  errorText: _tried && value == null
                      ? l10n.pplAmountMissing
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final v in _quickAmounts)
                    ActionChip(
                      key: ValueKey('ppl:quick:$v'),
                      label: Text(money.format(v)),
                      onPressed: () => setState(() => _amount.text = '$v'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('ppl:entryWhy'),
                controller: _reason,
                decoration: InputDecoration(
                  labelText: _needsReason ? l10n.pplWhy : l10n.pplWhyOptional,
                  errorText: _tried && _needsReason && _reason.text.trim().isEmpty
                      ? l10n.pplWhyMissing
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final r in _reasons(_kind, l10n))
                    ActionChip(
                      label: Text(r),
                      onPressed: () => setState(() => _reason.text = r),
                    ),
                ],
              ),
              if (balance != null) ...[
                const SizedBox(height: AppSpacing.md),
                _Balance(
                  now: balance,
                  after: balance + (plus ? 1 : -1) * (value ?? 0),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.atOnce ? l10n.pplAtOnce : l10n.pplNeedsYes,
                key: const ValueKey('ppl:entryWhen'),
                style: muted,
              ),
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

/// «К выплате сейчас → станет»: what the entry does to the person's month.
class _Balance extends StatelessWidget {
  const _Balance({required this.now, required this.after});

  final double now;
  final double after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = peopleMoney(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final strong = theme.textTheme.titleSmall;
    return DecoratedBox(
      key: const ValueKey('ppl:entryBalance'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.pplBalanceNow, style: muted)),
                Text(money.format(now), style: muted),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(child: Text(l10n.pplBalanceAfter, style: strong)),
                Text(
                  money.format(after),
                  key: const ValueKey('ppl:entryAfter'),
                  style: strong?.copyWith(
                    color: after < 0 ? context.statusColors.danger : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
