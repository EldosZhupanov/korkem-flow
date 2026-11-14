import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_print.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Счёт на оплату» for a sale (owner, 14.11.2026): whose requisites it
/// carries, the day to pay by, then the PDF to send. The first time, the
/// factory's requisites are filled in here — once, for every invoice after.
Future<void> showFilmInvoice(BuildContext context, FilmSale sale) =>
    showDialog<void>(
      context: context,
      builder: (_) => _InvoiceDialog(sale: sale),
    );

class _InvoiceDialog extends ConsumerStatefulWidget {
  const _InvoiceDialog({required this.sale});

  final FilmSale sale;

  @override
  ConsumerState<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<_InvoiceDialog> {
  Map<String, String>? _requisites;
  late DateTime _due;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _due = DateTime(now.year, now.month, now.day + 5);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final kept = await ref.read(filmDeptRepositoryProvider).requisites();
      if (mounted) setState(() => _requisites = kept);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _edit() async {
    final saved = await showFilmRequisites(context, _requisites ?? const {});
    if (saved != null && mounted) setState(() => _requisites = saved);
  }

  Future<void> _make(AppLocalizations l10n) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final locale = Localizations.localeOf(context).toString();
      final invoice = await ref
          .read(filmDeptRepositoryProvider)
          .invoice(widget.sale.entry, dueOn: mdfIso(_due));
      final bytes = await buildFilmInvoicePdf(widget.sale, invoice, (
        title: l10n.filmInvoiceTitle,
        beneficiary: l10n.filmInvoiceBeneficiary,
        bank: l10n.filmReqBank,
        bin: l10n.filmReqBin,
        iik: l10n.filmReqIik,
        bik: l10n.filmReqBik,
        kbe: l10n.filmReqKbe,
        supplier: l10n.filmInvoiceSupplier,
        buyer: l10n.filmInvoiceBuyer,
        phone: l10n.filmReceiptPhone,
        number: l10n.filmInvoiceNumber,
        item: l10n.filmInvoiceItem,
        qty: l10n.filmInvoiceQty,
        unit: l10n.filmInvoiceUnit,
        metreUnit: l10n.filmInvoiceMetre,
        price: l10n.filmReceiptPrice,
        amount: l10n.filmReceiptAmount,
        total: l10n.filmReceiptTotal,
        summary: l10n.filmInvoiceSummary,
        payBy: l10n.filmInvoicePayBy,
        signed: l10n.filmInvoiceSigned,
      ), locale: locale);
      await shareFilmInvoice(invoice, bytes);
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
    final r = _requisites;
    final ready = r != null && r['name']!.isNotEmpty;
    return AlertDialog(
      title: Text(l10n.filmInvoice),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r == null && _error == null)
              const LinearProgressIndicator()
            else if (!ready)
              Text(
                l10n.filmInvoiceNoRequisites,
                key: const ValueKey('filmInvoiceNoRequisites'),
              )
            else ...[
              Text(r['name']!, style: theme.textTheme.titleSmall),
              Text(
                [
                  if (r['bin']!.isNotEmpty) '${l10n.filmReqBin} ${r['bin']}',
                  if (r['bank']!.isNotEmpty) r['bank'],
                  if (r['iik']!.isNotEmpty) r['iik'],
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (r != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('filmInvoiceRequisites'),
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(AppIcons.edit),
                  label: Text(
                    ready ? l10n.filmReqEdit : l10n.filmReqFill,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('filmInvoiceDue'),
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.filmClose),
        ),
        FilledButton.icon(
          key: const ValueKey('filmInvoiceMake'),
          onPressed: _busy || !ready ? null : () => _make(l10n),
          icon: const Icon(AppIcons.share),
          label: Text(l10n.filmInvoiceMake),
        ),
      ],
    );
  }
}

/// The factory's requisites, kept once for every invoice: what is saved,
/// or null when left as it was.
Future<Map<String, String>?> showFilmRequisites(
  BuildContext context,
  Map<String, String> current,
) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => _RequisitesDialog(current: current),
);

class _RequisitesDialog extends ConsumerStatefulWidget {
  const _RequisitesDialog({required this.current});

  final Map<String, String> current;

  @override
  ConsumerState<_RequisitesDialog> createState() => _RequisitesDialogState();
}

class _RequisitesDialogState extends ConsumerState<_RequisitesDialog> {
  late final Map<String, TextEditingController> _fields = {
    for (final k in filmRequisiteKeys)
      k: TextEditingController(text: widget.current[k] ?? ''),
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(String key, AppLocalizations l10n) => switch (key) {
    'name' => l10n.filmReqName,
    'bin' => l10n.filmReqBin,
    'address' => l10n.filmReqAddress,
    'phone' => l10n.filmReqPhone,
    'bank' => l10n.filmReqBank,
    'iik' => l10n.filmReqIik,
    'bik' => l10n.filmReqBik,
    'kbe' => l10n.filmReqKbe,
    _ => l10n.filmReqDirector,
  };

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(filmDeptRepositoryProvider).setRequisites({
        for (final e in _fields.entries) e.key: e.value.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(saved);
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
    return AlertDialog(
      title: Text(l10n.filmReqTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in filmRequisiteKeys)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextField(
                    key: ValueKey('filmReq:$k'),
                    controller: _fields[k],
                    keyboardType: k == 'bin' || k == 'kbe'
                        ? TextInputType.number
                        : null,
                    decoration: InputDecoration(
                      labelText: _label(k, l10n),
                      isDense: true,
                    ),
                    onChanged: k == 'name' ? (_) => setState(() {}) : null,
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.filmClose),
        ),
        FilledButton(
          key: const ValueKey('filmReqSave'),
          onPressed: _busy || _fields['name']!.text.trim().isEmpty
              ? null
              : _save,
          child: Text(l10n.filmReqSave),
        ),
      ],
    );
  }
}
