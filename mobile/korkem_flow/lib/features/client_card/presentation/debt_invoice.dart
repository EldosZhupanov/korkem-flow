import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_invoice_dialog.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_print.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_invoice.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_invoice_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

/// «Счёт на долг» as a PDF: the factory's requisites, the payer, a line per
/// order it covers, VAT, the sum in words.
Future<Uint8List> buildDebtInvoicePdf(
  ClientCard card,
  MdfInvoicePrint paper,
  AppLocalizations l10n,
) {
  final i = paper.invoice;
  return buildPayInvoicePdf(
    (
      no: i.no,
      on: i.on,
      dueOn: i.dueOn,
      requisites: filmRequisitesOf(paper.requisites),
      buyer: i.payer.isEmpty ? card.name : i.payer,
      buyerBin: i.bin,
      buyerPhone: card.phone ?? '',
      lines: i.lines,
      total: i.amount,
      vat: i.vat,
      basis: null,
    ),
    filmInvoiceWords(l10n),
    locale: l10n.localeName,
  );
}

/// How a debt invoice leaves the app: the system's share sheet. A test
/// puts its own in.
typedef DebtInvoiceSend =
    Future<void> Function(
      ClientCard card,
      MdfInvoicePrint paper,
      AppLocalizations l10n,
    );

final debtInvoiceSendProvider = Provider<DebtInvoiceSend>(
  (ref) => (card, paper, l10n) async {
    final bytes = await buildDebtInvoicePdf(card, paper, l10n);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'schet-${paper.invoice.no}.pdf',
    );
  },
);

/// His orders owing, the oldest first — how the server lays an invoice
/// and a payment on them.
List<ClientOrder> owingOldestFirst(ClientCard card) => [
  for (final o in card.orders ?? const <ClientOrder>[])
    if (o.debt > 0.5 && !o.draft) o,
]..sort((a, b) => (a.createdOn ?? '').compareTo(b.createdOn ?? ''));

/// [value] laid on his orders, the oldest first: each order and its part.
List<(ClientOrder, double)> splitOldestFirst(ClientCard card, double value) {
  var left = value;
  final split = <(ClientOrder, double)>[];
  for (final o in owingOldestFirst(card)) {
    if (left <= 0) break;
    final part = left < o.debt ? left : o.debt;
    split.add((o, part));
    left -= part;
  }
  return split;
}

/// «Счёт на весь долг» (owner, 25.11.2026): all he owes or a sum of one's
/// own, who pays and his БИН, VAT, the day to pay by; then the PDF to send.
/// True when one was made.
Future<bool?> showDebtInvoice(BuildContext context, ClientCard card) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _DebtInvoiceDialog(card: card),
    );

class _DebtInvoiceDialog extends ConsumerStatefulWidget {
  const _DebtInvoiceDialog({required this.card});

  final ClientCard card;

  @override
  ConsumerState<_DebtInvoiceDialog> createState() => _DebtInvoiceDialogState();
}

class _DebtInvoiceDialogState extends ConsumerState<_DebtInvoiceDialog> {
  late final TextEditingController _own = TextEditingController();
  late final TextEditingController _payer = TextEditingController(
    text: widget.card.payerName.isEmpty
        ? widget.card.name
        : widget.card.payerName,
  );
  late final TextEditingController _bin = TextEditingController(
    text: widget.card.payerBin,
  );
  late bool _vat = widget.card.vat > 0;
  bool _whole = true;
  late DateTime _due;
  Map<String, String>? _requisites;
  bool _busy = false;
  String? _error;

  double get _debt => widget.card.figures?.debt ?? 0;

  double get _amount => _whole
      ? _debt
      : double.tryParse(_own.text.replaceAll(' ', '')) ?? 0;

  bool get _binOk {
    final b = _bin.text.trim();
    return b.isEmpty || RegExp(r'^\d{12}$').hasMatch(b);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _due = DateTime(now.year, now.month, now.day + 5);
    unawaited(_load());
  }

  /// The factory's requisites, to say whether they are filled in.
  Future<void> _load() async {
    try {
      final kept = await ref.read(filmDeptRepositoryProvider).requisites();
      if (mounted) setState(() => _requisites = kept);
    } on Object {
      return;
    }
  }

  @override
  void dispose() {
    _own.dispose();
    _payer.dispose();
    _bin.dispose();
    super.dispose();
  }

  Future<void> _make(AppLocalizations l10n) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final made = await ref
          .read(clientCardRepositoryProvider)
          .issueInvoice(
            widget.card.customer,
            amount: _whole ? null : _amount,
            payer: _payer.text.trim(),
            bin: _bin.text.trim(),
            dueOn: mdfIso(_due),
            vat: _vat,
          );
      await ref.read(debtInvoiceSendProvider)(made.card, made.print, l10n);
      if (mounted) Navigator.of(context).pop(true);
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
    final money = mdfMoney(context);
    final r = _requisites;
    final amount = _amount;
    final over = amount > _debt + 0.5;
    final ready = !_busy && amount > 0 && !over && _binOk;
    final split = over ? const <(ClientOrder, double)>[] : splitOldestFirst(
      widget.card,
      amount,
    );
    return AlertDialog(
      key: const ValueKey('dinvDialog'),
      title: Text(l10n.dinvButton),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.mdfInvoiceSum, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    key: const ValueKey('dinvSum:whole'),
                    label: Text('${l10n.dinvWhole} · ${money.format(_debt)}'),
                    selected: _whole,
                    onSelected: (_) => setState(() => _whole = true),
                  ),
                  ChoiceChip(
                    key: const ValueKey('dinvSum:own'),
                    label: Text(l10n.mdfInvoiceOwn),
                    selected: !_whole,
                    onSelected: (_) => setState(() => _whole = false),
                  ),
                ],
              ),
              if (!_whole)
                TextField(
                  key: const ValueKey('dinvOwn'),
                  controller: _own,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.mdfInvoiceSum,
                    errorText: over
                        ? l10n.clcPayOver(money.format(_debt))
                        : null,
                  ),
                ),
              if (split.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.dinvOrders, style: theme.textTheme.labelLarge),
                for (final (o, part) in split)
                  Text(
                    [
                      '№ ${o.number ?? o.name} — ${money.format(part)}',
                      if (part + 0.5 < o.debt)
                        l10n.clcPayPart(money.format(o.debt)),
                    ].join(' '),
                    key: ValueKey('dinvLine:${o.name}'),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('dinvPayer'),
                controller: _payer,
                decoration: InputDecoration(
                  labelText: l10n.mdfInvoicePayer,
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('dinvBin'),
                controller: _bin,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.mdfInvoiceBin,
                  helperText: l10n.mdfInvoicePayerHint,
                  errorText: _binOk ? null : l10n.mdfInvoiceBinBad,
                  isDense: true,
                ),
              ),
              SwitchListTile(
                key: const ValueKey('dinvVat'),
                contentPadding: EdgeInsets.zero,
                value: _vat,
                onChanged: (v) => setState(() => _vat = v),
                title: Text(l10n.mdfInvoiceVat('$mdfVatRate')),
              ),
              OutlinedButton.icon(
                key: const ValueKey('dinvDue'),
                onPressed: _busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _due,
                          firstDate: DateTime(now.year, now.month, now.day),
                          lastDate: now.add(const Duration(days: 180)),
                          helpText: l10n.filmInvoiceDueHelp,
                        );
                        if (picked != null && mounted) {
                          setState(() => _due = picked);
                        }
                      },
                icon: const Icon(AppIcons.calendar),
                label: Text(l10n.filmInvoicePayBy(mdfDayOf(_due))),
              ),
              if (r != null && r['name']!.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.filmInvoiceNoRequisites,
                  key: const ValueKey('dinvNoRequisites'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final saved = await showFilmRequisites(context, r);
                            if (saved != null && mounted) {
                              setState(() => _requisites = saved);
                            }
                          },
                    icon: const Icon(AppIcons.edit),
                    label: Text(l10n.filmReqFill),
                  ),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton.icon(
          key: const ValueKey('dinvMake'),
          onPressed: ready ? () => _make(l10n) : null,
          icon: _busy
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.share),
          label: Text(l10n.mdfInvoiceMake),
        ),
      ],
    );
  }
}

/// His debt invoices on the card: each one's number, day and sum, where it
/// stands, and — sent again or struck out.
class DebtInvoices extends ConsumerWidget {
  const DebtInvoices({required this.card, super.key});

  final ClientCard card;

  /// Paid and struck-out ones shown, the latest of them.
  static const int _shownDone = 3;

  Future<void> _again(BuildContext context, WidgetRef ref, MdfInvoice i) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final paper = await ref
          .read(clientCardRepositoryProvider)
          .printInvoice(card.customer, i.no);
      await ref.read(debtInvoiceSendProvider)(card, paper, l10n);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    MdfInvoice i,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showReasonDialog(
      context,
      title: '${l10n.mdfInvoiceCancel} № ${i.no}',
      label: l10n.mdfInvoiceCancelWhy,
      confirm: l10n.mdfInvoiceCancel,
      cancel: l10n.mdfCancel,
      fieldKey: const ValueKey('dinvCancelWhy'),
    );
    if (reason == null) return;
    try {
      await ref
          .read(clientCardRepositoryProvider)
          .cancelInvoice(card.customer, no: i.no, reason: reason);
      ref
        ..invalidate(clientCardProvider(card.customer))
        ..invalidate(clientHistoryProvider(card.customer));
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final waited = card.waitedInvoices;
    final done = [
      for (final i in card.invoices.reversed)
        if (!i.waited) i,
    ].take(_shownDone);
    final shown = [...waited, ...done];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in shown)
          ListTile(
            key: ValueKey('dinv:${i.no}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              AppIcons.quote,
              color: switch (i.state) {
                MdfInvoiceState.paid => status.success,
                MdfInvoiceState.cancelled => theme.disabledColor,
                _ => status.warning,
              },
            ),
            title: Text(
              l10n.mdfInvoiceRow(i.no, mdfDay(i.on), money.format(i.amount)),
            ),
            subtitle: Text(
              mdfInvoiceState(i, l10n, money.format),
              key: ValueKey('dinvState:${i.no}'),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i.state != MdfInvoiceState.cancelled)
                  IconButton(
                    key: ValueKey('dinvAgain:${i.no}'),
                    tooltip: l10n.mdfInvoiceAgain,
                    onPressed: () => unawaited(_again(context, ref, i)),
                    icon: const Icon(AppIcons.share),
                  ),
                if (i.state == MdfInvoiceState.open)
                  IconButton(
                    key: ValueKey('dinvCancel:${i.no}'),
                    tooltip: l10n.mdfInvoiceCancel,
                    onPressed: () => unawaited(_cancel(context, ref, i)),
                    icon: const Icon(AppIcons.close),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
