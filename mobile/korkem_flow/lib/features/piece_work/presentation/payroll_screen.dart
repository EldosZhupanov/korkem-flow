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

NumberFormat _money(BuildContext context) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol: '₸',
  decimalDigits: 0,
);

/// The pay sheet for a month: piece pay, bonuses, fines, advances, to pay.
///
/// Every figure comes from the server (`services/payroll.py`); this screen
/// adds nothing up. Advances, fines and one-off bonuses are entered here and
/// approved by somebody else.
class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  late PayPeriod _period = monthOf(DateTime.now());

  void _shift(int months) => setState(
    () => _period = monthOf(
      DateTime(_period.from.year, _period.from.month + months),
    ),
  );

  Future<void> _copyCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final csv = await ref
          .read(pieceWorkRepositoryProvider)
          .statementCsv(_period);
      await Clipboard.setData(ClipboardData(text: csv));
      messenger.showDone(l10n.payrollCsvCopied);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  /// «Выплачено» for one worker, after the person handing the money over
  /// confirms the sum. Only offered for a period that has ended.
  Future<void> _markPaid(PayrollRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.payrollMarkPaid),
        content: Text(
          l10n.payrollMarkPaidConfirm(row.employeeName, money.format(row.left)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey('payrollPayConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.payrollMarkPaid),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref
          .read(pieceWorkRepositoryProvider)
          .markPaid(row.employee, _period);
      messenger.showDone(l10n.payrollMarkPaidDone);
      ref
        ..invalidate(payrollStatementProvider(_period))
        ..invalidate(payAdjustmentsProvider(_period));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final sheet = ref.watch(payrollStatementProvider(_period));
    final now = DateTime.now();
    final ended = !_period.to.isAfter(DateTime(now.year, now.month, now.day));
    final month = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_period.from);

    Future<void> refresh() async {
      ref
        ..invalidate(payrollStatementProvider(_period))
        ..invalidate(payAdjustmentsProvider(_period));
      await ref.read(payrollStatementProvider(_period).future);
    }

    return AppScreen(
      title: l10n.payrollTitle,
      actions: [
        IconButton(
          key: const ValueKey('payrollCsv'),
          tooltip: l10n.payrollCopyCsv,
          icon: const Icon(AppIcons.share),
          onPressed: _copyCsv,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ReadableWidth(
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('payrollPrev'),
                    tooltip: l10n.payrollPrevMonth,
                    icon: const Icon(AppIcons.back),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      month,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('payrollNext'),
                    tooltip: l10n.payrollNextMonth,
                    icon: const Icon(AppIcons.forward),
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            sheet.when(
              loading: () => const ListSkeleton(),
              error: (error, _) => ErrorView(error: error, onRetry: refresh),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.rows.isEmpty)
                    ReadableWidth(child: Text(l10n.payrollEmpty)),
                  for (final row in data.rows)
                    ReadableWidth(
                      child: _RowCard(
                        row: row,
                        onPay: data.canMarkPaid && ended && row.left > 0
                            ? () => _markPaid(row)
                            : null,
                      ),
                    ),
                  if (data.rows.isNotEmpty)
                    ReadableWidth(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.payrollTotal,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              money.format(data.totalToPay),
                              key: const ValueKey('payrollTotal'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (data.rows.isNotEmpty && data.totalLeft != data.totalToPay)
                    ReadableWidth(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(child: Text(l10n.payrollTotalLeft)),
                            Text(
                              money.format(data.totalLeft),
                              key: const ValueKey('payrollTotalLeft'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ReadableWidth(child: _Adjustments(period: _period)),
          ],
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, this.onPay});

  final PayrollRow row;

  /// «Отметить выплату», when this person may and the period has ended.
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final theme = Theme.of(context);
    Widget line(String label, double value, {bool minus = false}) => value == 0
        ? const SizedBox.shrink()
        : Row(
            children: [
              Expanded(child: Text(label)),
              Text('${minus ? '−' : ''}${money.format(value)}'),
            ],
          );
    return AppCard(
      key: ValueKey('payrollRow:${row.employee}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.employeeName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(money.format(row.toPay), style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          line(l10n.payrollPiece, row.piece),
          line(l10n.payrollDailyBonus, row.dailyBonus),
          line(l10n.payrollMonthlyBonus, row.monthlyBonus),
          line(l10n.payrollBonus, row.bonus),
          line(l10n.payrollFine, row.fine, minus: true),
          line(l10n.payrollAdvance, row.advance, minus: true),
          if (row.paid > 0) ...[
            line(l10n.payrollPaid, row.paid, minus: true),
            Row(
              children: [
                Expanded(child: Text(l10n.payrollLeft)),
                Text(
                  money.format(row.left),
                  key: ValueKey('payrollLeft:${row.employee}'),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ],
          if (row.pending > 0)
            Text(
              l10n.payrollPending(money.format(row.pending)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.statusColors.warning,
              ),
            ),
          if (onPay != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: ValueKey('payrollPay:${row.employee}'),
                onPressed: onPay,
                icon: const Icon(AppIcons.check, size: AppIconSize.dense),
                label: Text(l10n.payrollMarkPaid),
              ),
            ),
        ],
      ),
    );
  }
}

class _Adjustments extends ConsumerWidget {
  const _Adjustments({required this.period});

  final PayPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final items = ref.watch(payAdjustmentsProvider(period));

    Future<void> act(Future<void> Function() call) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await call();
        ref
          ..invalidate(payAdjustmentsProvider(period))
          ..invalidate(payrollStatementProvider(period));
      } on Object catch (error) {
        messenger.showFailure(error, l10n);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(l10n.payrollAdjustments)),
            IconButton(
              key: const ValueKey('payrollAddAdjustment'),
              tooltip: l10n.payrollAddAdjustment,
              icon: const Icon(AppIcons.add),
              onPressed: () async {
                final draft = await showDialog<_Draft>(
                  context: context,
                  builder: (_) => const _AdjustmentDialog(),
                );
                if (draft == null) return;
                await act(
                  () => ref
                      .read(pieceWorkRepositoryProvider)
                      .addAdjustment(
                        employee: draft.employee,
                        kind: draft.kind,
                        amount: draft.amount,
                        reason: draft.reason,
                      ),
                );
              },
            ),
          ],
        ),
        items.when(
          loading: () => const ListSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(payAdjustmentsProvider(period)),
          ),
          data: (rows) => Column(
            children: [
              if (rows.isEmpty) Text(l10n.payrollNoAdjustments),
              for (final a in rows)
                Card(
                  child: ListTile(
                    key: ValueKey('adjustment:${a.adjustment}'),
                    title: Text('${a.kind} · ${a.employeeName}'),
                    subtitle: Text('${a.onDate} · ${a.reason}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money.format(a.amount)),
                        StatusChip(
                          label: switch (a.status) {
                            'Approved' => l10n.pieceWorkApproved,
                            'Reversed' => l10n.pieceWorkRejected,
                            _ => l10n.pieceWorkPending,
                          },
                          intent: switch (a.status) {
                            'Approved' => StatusIntent.success,
                            'Reversed' => StatusIntent.neutral,
                            _ => StatusIntent.warning,
                          },
                          compact: true,
                        ),
                      ],
                    ),
                    onTap: a.status == 'Reversed'
                        ? null
                        : () async {
                            final approve = a.isPending;
                            final choice = await showModalBottomSheet<String>(
                              context: context,
                              builder: (sheet) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (approve)
                                      ListTile(
                                        key: const ValueKey(
                                          'adjustmentApprove',
                                        ),
                                        leading: const Icon(AppIcons.check),
                                        title: Text(l10n.pieceWorkApprove),
                                        onTap: () =>
                                            Navigator.of(sheet).pop('approve'),
                                      ),
                                    ListTile(
                                      key: const ValueKey('adjustmentReverse'),
                                      leading: const Icon(AppIcons.close),
                                      title: Text(l10n.payrollReverse),
                                      onTap: () =>
                                          Navigator.of(sheet).pop('reverse'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (!context.mounted) return;
                            if (choice == 'approve') {
                              await act(
                                () => ref
                                    .read(pieceWorkRepositoryProvider)
                                    .approveAdjustment(a.adjustment),
                              );
                            } else if (choice == 'reverse') {
                              final reason = await showReasonDialog(
                                context,
                                title: l10n.payrollReverse,
                                label: l10n.pieceWorkReason,
                                confirm: l10n.payrollReverse,
                                cancel: l10n.actionCancel,
                                fieldKey: const ValueKey(
                                  'adjustmentReverseReason',
                                ),
                              );
                              if (reason == null) return;
                              await act(
                                () => ref
                                    .read(pieceWorkRepositoryProvider)
                                    .reverseAdjustment(a.adjustment, reason),
                              );
                            }
                          },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _Draft = ({String employee, String kind, double amount, String reason});

class _AdjustmentDialog extends ConsumerStatefulWidget {
  const _AdjustmentDialog();

  @override
  ConsumerState<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends ConsumerState<_AdjustmentDialog> {
  String? _employee;
  String _kind = PayAdjustment.advance;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workers = ref.watch(workersProvider).value ?? const <Worker>[];
    return AlertDialog(
      title: Text(l10n.payrollAddAdjustment),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('adjustmentEmployee'),
              initialValue: _employee,
              isExpanded: true,
              items: [
                for (final w in workers)
                  DropdownMenuItem(value: w.user, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _employee = v),
              decoration: InputDecoration(labelText: l10n.payrollEmployee),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: [
                for (final kind in PayAdjustment.kinds)
                  ButtonSegment(value: kind, label: Text(kind)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            TextField(
              key: const ValueKey('adjustmentAmount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.payrollAmount,
                suffixText: '₸',
              ),
            ),
            TextField(
              key: const ValueKey('adjustmentReason'),
              controller: _reason,
              decoration: InputDecoration(labelText: l10n.payrollReason),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
          key: const ValueKey('adjustmentSave'),
          onPressed: () {
            final amount = double.tryParse(_amount.text);
            final employee = _employee;
            final reason = _reason.text.trim();
            if (employee == null ||
                amount == null ||
                amount <= 0 ||
                reason.isEmpty) {
              setState(() => _error = l10n.materialStockFillAll);
              return;
            }
            Navigator.of(context).pop((
              employee: employee,
              kind: _kind,
              amount: amount,
              reason: reason,
            ));
          },
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}

/// A worker's way to today's and this month's bonus — on their own screen
/// and on the tablet. Nothing shown when the company pays no such bonus.
class BonusProgressCard extends ConsumerWidget {
  const BonusProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bonusProgressProvider).value;
    if (progress == null || progress.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    Widget step(String label, BonusStep s, String key) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(key: ValueKey(key), value: s.fraction),
          const SizedBox(height: AppSpacing.xs),
          Text(
            s.reached
                ? l10n.bonusReached(money.format(s.bonus))
                : l10n.bonusLeft(money.format(s.left), money.format(s.bonus)),
          ),
        ],
      ),
    );
    return AppCard(
      key: const ValueKey('bonusProgress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.today case final today?)
            step(l10n.bonusToday, today, 'bonusToday'),
          if (progress.month case final month?)
            step(l10n.bonusMonth, month, 'bonusMonth'),
        ],
      ),
    );
  }
}
