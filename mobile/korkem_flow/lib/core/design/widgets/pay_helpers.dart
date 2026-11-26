import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// What every window that takes money in shares (owner, 26.11.2026: «такую
// надо внедрить не только на эту, а на всём, что есть … нужно просто
// дополнить с улучшением»): one-tap amounts under the sum, the change for
// cash, and what is owed after. Each window keeps its own layout, methods
// and checks; these only sit beside its amount field.

/// One amount offered in one tap: «Весь остаток · 62 210 ₸».
typedef PayOption = ({String key, String label, double amount});

/// Chips under a payment's sum; the one matching [current] is selected.
class PayQuickAmounts extends StatelessWidget {
  const PayQuickAmounts({
    required this.options,
    required this.current,
    required this.format,
    required this.onPick,
    super.key,
  });

  final List<PayOption> options;
  final double current;
  final String Function(double) format;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final o in options)
        if (o.amount > 0) o,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final o in shown)
          ChoiceChip(
            key: ValueKey('payQuick:${o.key}'),
            label: Text('${o.label} · ${format(o.amount)}'),
            selected: (current - o.amount).abs() < 0.5,
            onSelected: (_) => onPick(o.amount),
          ),
      ],
    );
  }
}

/// «Клиент дал …» and the change, for a payment in cash of [amount].
class PayCashChange extends StatefulWidget {
  const PayCashChange({required this.amount, required this.format, super.key});

  final double amount;
  final String Function(double) format;

  @override
  State<PayCashChange> createState() => _PayCashChangeState();
}

class _PayCashChangeState extends State<PayCashChange> {
  final _given = TextEditingController();

  @override
  void dispose() {
    _given.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final given = double.tryParse(_given.text.replaceAll(' ', '')) ?? 0;
    final change = given - widget.amount;
    return Row(
      children: [
        SizedBox(
          width: AppSpacing.xxxl * 4,
          child: TextField(
            key: const ValueKey('payCashGiven'),
            controller: _given,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.payCashGiven,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (given > 0)
          Expanded(
            child: Text(
              change >= 0
                  ? l10n.payCashChange(widget.format(change))
                  : l10n.payCashShort(widget.format(-change)),
              key: const ValueKey('payCashChange'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: change >= 0 ? null : context.statusColors.warning,
              ),
            ),
          ),
      ],
    );
  }
}

/// «Долг после оплаты: …» or «Оплачено полностью»; more than is owed, red.
class PayAfter extends StatelessWidget {
  const PayAfter({
    required this.owed,
    required this.paying,
    required this.format,
    super.key,
  });

  final double owed;
  final double paying;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final after = owed - paying;
    final (text, color) = switch (after) {
      < -0.5 => (l10n.payOver(format(-after)), status.danger),
      <= 0.5 => (l10n.payAll, status.success),
      _ => (l10n.payDebtAfter(format(after)), null),
    };
    return Text(
      text,
      key: const ValueKey('payAfter'),
      style: theme.textTheme.bodyMedium?.copyWith(color: color),
    );
  }
}
