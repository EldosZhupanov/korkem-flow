import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_invoice_dialog.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_print.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

/// An MDF order's «Счёт на оплату» as a PDF: the factory's requisites,
/// the payer, the lines as they were issued, VAT, the sum in words.
Future<Uint8List> buildMdfInvoicePdf(
  MdfOrder order,
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
      buyer: i.payer.isEmpty ? order.customerName : i.payer,
      buyerBin: i.bin,
      buyerPhone: order.phone ?? '',
      lines: i.lines,
      total: i.amount,
      vat: i.vat,
      basis: l10n.mdfInvoiceBasis(order.name),
    ),
    filmInvoiceWords(l10n),
    locale: l10n.localeName,
  );
}

/// How an invoice leaves the app: the system's share sheet — WhatsApp,
/// mail, a printer, a file. A test puts its own in.
typedef MdfInvoiceSend =
    Future<void> Function(
      MdfOrder order,
      MdfInvoicePrint paper,
      AppLocalizations l10n,
    );

final mdfInvoiceSendProvider = Provider<MdfInvoiceSend>(
  (ref) => (order, paper, l10n) async {
    final bytes = await buildMdfInvoicePdf(order, paper, l10n);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'schet-${paper.invoice.no}.pdf',
    );
  },
);

/// «Счёт на оплату» for an order (owner, 20.11.2026): how much — all that
/// is owed, half before the work, or a sum of one's own — who pays and his
/// БИН, VAT, the day to pay by; then the PDF to send. Gives the card after
/// it, or null when nothing was made.
Future<MdfOrder?> showMdfInvoice(BuildContext context, MdfOrder order) =>
    showDialog<MdfOrder>(
      context: context,
      builder: (_) => _InvoiceDialog(order: order),
    );

enum _Sum { whole, half, own }

class _InvoiceDialog extends ConsumerStatefulWidget {
  const _InvoiceDialog({required this.order});

  final MdfOrder order;

  @override
  ConsumerState<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<_InvoiceDialog> {
  late final TextEditingController _own = TextEditingController();
  late final TextEditingController _payer = TextEditingController(
    text: widget.order.payerName.isEmpty
        ? widget.order.customerName
        : widget.order.payerName,
  );
  late final TextEditingController _bin = TextEditingController(
    text: widget.order.payerBin,
  );
  late bool _vat = widget.order.invoiceVat > 0;
  _Sum _sum = _Sum.whole;
  late DateTime _due;
  Map<String, String>? _requisites;
  bool _busy = false;
  String? _error;

  /// Before any payment, the half the work starts on.
  double? get _half {
    final o = widget.order;
    if (o.paid > 0.5 || o.debt <= 0) return null;
    final half = (o.total / 2).roundToDouble();
    return half < o.debt ? half : null;
  }

  double get _amount => switch (_sum) {
    _Sum.whole => widget.order.debt,
    _Sum.half => _half ?? 0,
    _Sum.own => double.tryParse(_own.text.replaceAll(' ', '')) ?? 0,
  };

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

  /// The factory's requisites, to say whether they are filled in; a
  /// manager who may not read them still makes the invoice — the server
  /// puts them on it.
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
          .read(mdfOrderRepositoryProvider)
          .issueInvoice(
            widget.order.name,
            amount: _amount,
            payer: _payer.text.trim(),
            bin: _bin.text.trim(),
            dueOn: mdfIso(_due),
            vat: _vat,
          );
      await ref.read(mdfInvoiceSendProvider)(made.order, made.print, l10n);
      if (mounted) Navigator.of(context).pop(made.order);
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
    final o = widget.order;
    final r = _requisites;
    final amount = _amount;
    final over = amount > o.debt + 0.5;
    final ready = !_busy && amount > 0 && !over && _binOk;
    final half = _half;
    return AlertDialog(
      key: const ValueKey('mdfInvoiceDialog'),
      title: Text('${l10n.mdfInvoiceButton} · ${o.name}'),
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
                    key: const ValueKey('mdfInvoiceSum:whole'),
                    label: Text(
                      '${l10n.mdfInvoiceWhole} · ${money.format(o.debt)}',
                    ),
                    selected: _sum == _Sum.whole,
                    onSelected: (_) => setState(() => _sum = _Sum.whole),
                  ),
                  if (half != null)
                    ChoiceChip(
                      key: const ValueKey('mdfInvoiceSum:half'),
                      label: Text(
                        '${l10n.mdfInvoiceHalf} · ${money.format(half)}',
                      ),
                      selected: _sum == _Sum.half,
                      onSelected: (_) => setState(() => _sum = _Sum.half),
                    ),
                  ChoiceChip(
                    key: const ValueKey('mdfInvoiceSum:own'),
                    label: Text(l10n.mdfInvoiceOwn),
                    selected: _sum == _Sum.own,
                    onSelected: (_) => setState(() => _sum = _Sum.own),
                  ),
                ],
              ),
              if (_sum == _Sum.own)
                TextField(
                  key: const ValueKey('mdfInvoiceOwn'),
                  controller: _own,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.mdfInvoiceSum,
                    errorText: over
                        ? l10n.mdfPayOver(money.format(amount - o.debt))
                        : null,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('mdfInvoicePayer'),
                controller: _payer,
                decoration: InputDecoration(
                  labelText: l10n.mdfInvoicePayer,
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('mdfInvoiceBin'),
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
                key: const ValueKey('mdfInvoiceVat'),
                contentPadding: EdgeInsets.zero,
                value: _vat,
                onChanged: (v) => setState(() => _vat = v),
                title: Text(l10n.mdfInvoiceVat('$mdfVatRate')),
              ),
              OutlinedButton.icon(
                key: const ValueKey('mdfInvoiceDue'),
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
              const SizedBox(height: AppSpacing.sm),
              // Whose invoice it is: the factory's requisites, filled in
              // once for every invoice — film sales' and orders' alike.
              if (r != null) ...[
                if (r['name']!.isEmpty)
                  Text(
                    l10n.filmInvoiceNoRequisites,
                    key: const ValueKey('mdfInvoiceNoRequisites'),
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else
                  Text(
                    [
                      r['name'],
                      if (r['bin']!.isNotEmpty) '${l10n.filmReqBin} ${r['bin']}',
                      if (r['iik']!.isNotEmpty) r['iik'],
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('mdfInvoiceRequisites'),
                    onPressed: _busy
                        ? null
                        : () async {
                            final saved = await showFilmRequisites(
                              context,
                              r,
                            );
                            if (saved != null && mounted) {
                              setState(() => _requisites = saved);
                            }
                          },
                    icon: const Icon(AppIcons.edit),
                    label: Text(
                      r['name']!.isEmpty ? l10n.filmReqFill : l10n.filmReqEdit,
                    ),
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
          key: const ValueKey('mdfInvoiceMake'),
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

/// An invoice's line on the order card: its number, day and sum, and where
/// it stands — waited for by its day, overdue, paid in part, paid.
String mdfInvoiceState(
  MdfInvoice i,
  AppLocalizations l10n,
  String Function(double) money, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final due = DateTime.tryParse(i.dueOn);
  return switch (i.state) {
    MdfInvoiceState.paid => l10n.mdfInvoicePaid,
    MdfInvoiceState.cancelled => l10n.mdfInvoiceCancelled,
    MdfInvoiceState.part => l10n.mdfInvoicePart(
      money(i.paid),
      money(i.amount),
    ),
    MdfInvoiceState.open =>
      due != null && due.isBefore(day)
          ? l10n.mdfInvoiceOverdue(mdfDay(i.dueOn))
          : l10n.mdfInvoiceWaiting(mdfDay(i.dueOn)),
  };
}
