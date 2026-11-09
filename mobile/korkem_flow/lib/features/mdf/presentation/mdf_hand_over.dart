import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A reason from a chip, words typed, or both — null when neither.
String? mdfReason(String? chip, String typed) {
  final text = [?chip, if (typed.trim().isNotEmpty) typed.trim()].join(' — ');
  return text.isEmpty ? null : text;
}

/// Why a payment is fixed or deleted — the usual reasons (owner, 09.11.2026).
List<String> mdfPaymentReasons(AppLocalizations l10n) => [
  l10n.mdfPayReasonAmount,
  l10n.mdfPayReasonMethod,
  l10n.mdfPayReasonBank,
  l10n.mdfPayReasonTwice,
];

/// Ready-made reasons as chips, and a field for anything else.
class MdfReasonPicker extends StatelessWidget {
  const MdfReasonPicker({
    required this.reasons,
    required this.chip,
    required this.controller,
    required this.label,
    required this.onChip,
    required this.onText,
    super.key,
  });

  final List<String> reasons;
  final String? chip;
  final TextEditingController controller;
  final String label;
  final ValueChanged<String?> onChip;
  final VoidCallback onText;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (i, r) in reasons.indexed)
            ChoiceChip(
              key: ValueKey('mdfPayReason:$i'),
              label: Text(r),
              selected: chip == r,
              onSelected: (on) => onChip(on ? r : null),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        key: const ValueKey('mdfPayReasonField'),
        controller: controller,
        onChanged: (_) => onText(),
        decoration: InputDecoration(labelText: label),
      ),
    ],
  );
}

/// «Удалить оплату»: which payment, and why.
Future<String?> showMdfPaymentDelete(
  BuildContext context,
  MdfPayment payment,
  String money,
) => showDialog<String>(
  context: context,
  builder: (_) => _DeleteDialog(payment: payment, money: money),
);

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.payment, required this.money});

  final MdfPayment payment;
  final String money;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _text = TextEditingController();
  String? _chip;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.payment;
    final why = mdfReason(_chip, _text.text);
    return AlertDialog(
      title: Text(l10n.mdfPaymentDelete),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                widget.money,
                mdfDay(p.date),
                p.method,
                p.bank,
              ].whereType<String>().join(' · '),
            ),
            const SizedBox(height: AppSpacing.md),
            MdfReasonPicker(
              reasons: mdfPaymentReasons(l10n),
              chip: _chip,
              controller: _text,
              label: l10n.mdfPaymentReason,
              onChip: (c) => setState(() => _chip = c),
              onText: () => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfPaymentDeleteYes'),
          onPressed: why == null ? null : () => Navigator.of(context).pop(why),
          child: Text(l10n.mdfPaymentDelete),
        ),
      ],
    );
  }
}

/// What the check before a hand-over gives back.
typedef MdfHandOver = ({String? comment, String? takenBy, String? takenPhone});

/// The check before a hand-over (owner, 09.11.2026): the stages, what is
/// paid and owed, the pieces counted, and who takes it — the customer or
/// someone else, with a phone. A debt needs the owner's words why.
Future<MdfHandOver?> showMdfHandOver(BuildContext context, MdfOrder order) =>
    showDialog<MdfHandOver>(
      context: context,
      builder: (_) => _HandOverDialog(order: order),
    );

class _HandOverDialog extends StatefulWidget {
  const _HandOverDialog({required this.order});

  final MdfOrder order;

  @override
  State<_HandOverDialog> createState() => _HandOverDialogState();
}

class _HandOverDialogState extends State<_HandOverDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _comment = TextEditingController();
  bool _counted = false;
  bool _other = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _comment.dispose();
    super.dispose();
  }

  bool get _ok =>
      _counted &&
      (!_other || _name.text.trim().isNotEmpty) &&
      (widget.order.debt <= 0 || _comment.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final o = widget.order;
    return AlertDialog(
      title: Text(l10n.mdfHandOverCheck),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${o.name} · ${o.customerName}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('✓ ${l10n.mdfHandOverStagesDone}'),
              Text(
                l10n.mdfPaidDebt(money.format(o.paid), money.format(o.debt)),
                key: const ValueKey('mdfHandOverMoney'),
                style: TextStyle(
                  color: o.debt > 0 ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (o.debt > 0)
                TextField(
                  key: const ValueKey('mdfHandOverDebtComment'),
                  controller: _comment,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.mdfHandOverComment,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                key: const ValueKey('mdfHandOverCounted'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _counted,
                onChanged: (v) => setState(() => _counted = v ?? false),
                title: Text(l10n.mdfHandOverCounted(o.pieces)),
              ),
              Text(l10n.mdfTakenByName, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const ValueKey('mdfTakenClient'),
                    label: Text('${l10n.mdfTakenByClient}: ${o.customerName}'),
                    selected: !_other,
                    onSelected: (_) => setState(() => _other = false),
                  ),
                  ChoiceChip(
                    key: const ValueKey('mdfTakenOther'),
                    label: Text(l10n.mdfTakenByOther),
                    selected: _other,
                    onSelected: (_) => setState(() => _other = true),
                  ),
                ],
              ),
              if (_other) ...[
                TextField(
                  key: const ValueKey('mdfTakenName'),
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l10n.mdfTakenByName),
                ),
                TextField(
                  key: const ValueKey('mdfTakenPhone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.mdfTakenByPhone,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfHandOverYes'),
          onPressed: !_ok
              ? null
              : () => Navigator.of(context).pop<MdfHandOver>((
                  comment: o.debt > 0 ? _comment.text.trim() : null,
                  takenBy: _other ? _name.text.trim() : null,
                  takenPhone: _other && _phone.text.trim().isNotEmpty
                      ? _phone.text.trim()
                      : null,
                )),
          child: Text(l10n.mdfHandOver),
        ),
      ],
    );
  }
}

/// «✓ Выдан 09.11.2026 · выдал Олжас · забрал Ерлан, 8701…» — and the debt
/// it went with, in red (owner, 09.11.2026).
class MdfHandedOverBanner extends StatelessWidget {
  const MdfHandedOverBanner({
    required this.order,
    required this.money,
    this.onReturn,
    super.key,
  });

  final MdfOrder order;
  final NumberFormat money;

  /// «Вернуть в работу»; null while busy.
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final o = order;
    final who = o.takenBy == null
        ? '${l10n.mdfTakenByClient.toLowerCase()} ${o.customerName}'
        : [o.takenBy, o.takenPhone].whereType<String>().join(', ');
    return Card(
      key: const ValueKey('mdfHandedOverBanner'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                '✓ ${l10n.mdfHandedOverOn(mdfDay(o.handedOverOn ?? ''))}',
                if (o.handedOverBy != null)
                  l10n.mdfHandedOverBy(o.handedOverBy!),
                l10n.mdfTakenBy(who),
              ].join(' · '),
              style: theme.textTheme.titleSmall,
            ),
            if (o.debt > 0)
              Text(
                l10n.mdfHandedWithDebt(money.format(o.debt)),
                key: const ValueKey('mdfHandedWithDebt'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('mdfReturnToWork'),
                onPressed: onReturn,
                icon: const Icon(AppIcons.undo),
                label: Text(l10n.mdfReturnToWork),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
