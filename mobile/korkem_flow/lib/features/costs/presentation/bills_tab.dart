import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/costs/data/costs_repository.dart';
import 'package:korkem_flow/features/costs/domain/costs.dart';
import 'package:korkem_flow/features/costs/presentation/costs_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Счета за месяц»: свет, аренда, связь… — each with its sum, or last
/// month's beside it, so only what changed is typed.
class BillsTab extends ConsumerWidget {
  const BillsTab({required this.month, required this.header, super.key});

  final String month;
  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = costMoney(context);
    final bills = ref.watch(costBillsProvider(month));
    return Column(
      children: [
        header,
        Expanded(
          child: bills.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(costBillsProvider(month)),
            ),
            data: (b) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ReadableWidth(
                  child: Text(
                    l10n.cstBillsTotal(
                      b.filled,
                      b.bills.length,
                      money.format(b.total),
                    ),
                    key: const ValueKey('cst:billsTotal'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final row in b.bills)
                  ReadableWidth(
                    child: _BillLine(month: month, row: row),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BillLine extends ConsumerWidget {
  const _BillLine({required this.month, required this.row});

  final String month;
  final CostBillRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = costMoney(context);
    final amount = row.amount;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      key: ValueKey('cst:bill:${row.item}'),
      contentPadding: EdgeInsets.zero,
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _BillDialog(month: month, row: row),
      ),
      title: Text(row.title),
      subtitle: Text(
        [
          row.group,
          if (row.used case final used?)
            l10n.cstMeterUsed(costQty(used), row.unit),
          if (row.lastAmount case final last?)
            l10n.cstBillLast(money.format(last)),
        ].join(' · '),
        style: muted,
      ),
      trailing: amount == null
          ? Text(
              l10n.cstBillNotEntered,
              style: muted?.copyWith(color: context.statusColors.warning),
            )
          : Text(money.format(amount), style: theme.textTheme.titleSmall),
    );
  }
}

/// The month's sum, the meter's two readings, a note.
class _BillDialog extends ConsumerStatefulWidget {
  const _BillDialog({required this.month, required this.row});

  final String month;
  final CostBillRow row;

  @override
  ConsumerState<_BillDialog> createState() => _BillDialogState();
}

class _BillDialogState extends ConsumerState<_BillDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: _plain(widget.row.amount ?? widget.row.lastAmount),
  );
  late final TextEditingController _from = TextEditingController(
    text: _plain(widget.row.meterFrom ?? widget.row.meterStart),
  );
  late final TextEditingController _to = TextEditingController(
    text: _plain(widget.row.meterTo),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.row.note ?? '',
  );
  bool _busy = false;
  String? _error;

  static String _plain(double? v) => v == null ? '' : costQty(v);

  static double? _number(String s) =>
      double.tryParse(s.replaceAll(' ', '').replaceAll(',', '.'));

  @override
  void dispose() {
    _amount.dispose();
    _from.dispose();
    _to.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = _number(_amount.text);
    if (amount == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(costsRepositoryProvider)
          .putBill(
            widget.row.item,
            month: widget.month,
            amount: amount,
            meterFrom: _number(_from.text),
            meterTo: _number(_to.text),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref
        ..invalidate(costBillsProvider(widget.month))
        ..invalidate(moneyFlowProvider(widget.month));
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final from = _number(_from.text);
    final to = _number(_to.text);
    final numbers = [
      FilteringTextInputFormatter.allow(RegExp('[0-9 ,.]')),
    ];
    return AlertDialog(
      key: const ValueKey('cst:billDialog'),
      title: Text(widget.row.title),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('cst:billAmount'),
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: numbers,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.cstBillAmount),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('cst:meterFrom'),
                      controller: _from,
                      keyboardType: TextInputType.number,
                      inputFormatters: numbers,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.cstMeterFrom,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('cst:meterTo'),
                      controller: _to,
                      keyboardType: TextInputType.number,
                      inputFormatters: numbers,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.cstMeterTo,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              if (from != null && to != null && to >= from)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.cstMeterUsed(costQty(to - from), widget.row.unit),
                    key: const ValueKey('cst:meterUsed'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('cst:billNote'),
                controller: _note,
                decoration: InputDecoration(
                  labelText: l10n.cstNote,
                  isDense: true,
                ),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton.icon(
          key: const ValueKey('cst:billSave'),
          onPressed: !_busy && _number(_amount.text) != null ? _save : null,
          icon: const Icon(AppIcons.check),
          label: Text(l10n.cstSave),
        ),
      ],
    );
  }
}
