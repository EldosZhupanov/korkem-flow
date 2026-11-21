import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// «Акт сверки» as an A4 page (owner, 21.11.2026): the two parties, the
/// period, the balance it opens with, each sale and payment, the turnover,
/// the balance it closes with in words a ТОО's accountant expects, and a
/// place for both signatures.
Future<Uint8List> buildReconciliationPdf(
  Reconciliation act,
  AppLocalizations l10n,
) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
  );
  final money = NumberFormat.currency(
    locale: l10n.localeName,
    symbol: '₸',
    decimalDigits: 0,
  );
  String day(String iso) => mdfDay(iso);
  String sum(double v) => v.abs() < 0.5 ? '' : money.format(v);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: font,
      italic: font,
      boldItalic: font,
    ),
  );
  const bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  const small = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);
  pw.Widget cell(String text, {bool right = false, pw.TextStyle? style}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Align(
          alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(text, style: style),
        ),
      );
  final bin = act.requisites['bin'] ?? '';
  final ours = [
    act.company,
    if (bin.isNotEmpty) '${l10n.filmReqBin} $bin',
  ].join(', ');
  final theirs = [
    act.payer,
    if (act.payerBin.isNotEmpty) '${l10n.filmReqBin} ${act.payerBin}',
  ].join(', ');
  final closing = act.closing;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Text(
          l10n.actTitle,
          style: const pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(l10n.actPeriod(day(act.since), day(act.until))),
        pw.SizedBox(height: 4),
        pw.Text(l10n.actBetween(ours, theirs), style: small),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(64),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(86),
            3: pw.FixedColumnWidth(86),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                cell(l10n.actDate, style: bold),
                cell(l10n.actDocument, style: bold),
                cell(l10n.actDebit, style: bold, right: true),
                cell(l10n.actCredit, style: bold, right: true),
              ],
            ),
            pw.TableRow(
              children: [
                cell(day(act.since)),
                cell(l10n.actOpening, style: bold),
                cell(
                  act.opening > 0 ? sum(act.opening) : '',
                  right: true,
                  style: bold,
                ),
                cell(
                  act.opening < 0 ? sum(act.opening) : '',
                  right: true,
                  style: bold,
                ),
              ],
            ),
            for (final r in act.rows)
              pw.TableRow(
                children: [
                  cell(day(r.date)),
                  cell(r.text),
                  cell(sum(r.debit), right: true),
                  cell(sum(r.credit), right: true),
                ],
              ),
            pw.TableRow(
              children: [
                cell(''),
                cell(l10n.actTurnover, style: bold),
                cell(sum(act.debit), right: true, style: bold),
                cell(sum(act.credit), right: true, style: bold),
              ],
            ),
            pw.TableRow(
              children: [
                cell(day(act.until)),
                cell(l10n.actClosing, style: bold),
                cell(closing > 0 ? sum(closing) : '', right: true, style: bold),
                cell(closing < 0 ? sum(closing) : '', right: true, style: bold),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          closing.abs() < 0.5
              ? l10n.actNoDebt(act.company, day(act.until))
              : closing > 0
              ? l10n.actTheyOwe(
                  act.company,
                  day(act.until),
                  act.payer,
                  money.format(closing),
                )
              : l10n.actWeOwe(
                  act.company,
                  day(act.until),
                  act.payer,
                  money.format(-closing),
                ),
          style: bold,
        ),
        pw.SizedBox(height: 36),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(act.company, style: bold),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    '________________ ${act.requisites['director'] ?? ''}',
                  ),
                  pw.Text(l10n.actStamp, style: small),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(act.payer, style: bold),
                  pw.SizedBox(height: 24),
                  pw.Text('________________'),
                  pw.Text(l10n.actStamp, style: small),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// How an act leaves the app: the system's share sheet — WhatsApp, mail, a
/// printer, a file. A test puts its own in.
typedef ActSend =
    Future<void> Function(Reconciliation act, AppLocalizations l10n);

final actSendProvider = Provider<ActSend>(
  (ref) => (act, l10n) async {
    final bytes = await buildReconciliationPdf(act, l10n);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'akt-sverki-${act.until}.pdf',
    );
  },
);

enum _Period { all, month, lastMonth, year }

/// «Акт сверки» for a period — all his time, this month, last month, this
/// year — then the PDF to send.
Future<void> showReconciliation(BuildContext context, String customer) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ActDialog(customer: customer),
    );

class _ActDialog extends ConsumerStatefulWidget {
  const _ActDialog({required this.customer});

  final String customer;

  @override
  ConsumerState<_ActDialog> createState() => _ActDialogState();
}

class _ActDialogState extends ConsumerState<_ActDialog> {
  _Period _period = _Period.all;
  bool _busy = false;
  String? _error;

  (String?, String?) _range() {
    final now = DateTime.now();
    return switch (_period) {
      _Period.all => (null, null),
      _Period.month => (mdfIso(DateTime(now.year, now.month)), mdfIso(now)),
      _Period.lastMonth => (
        mdfIso(DateTime(now.year, now.month - 1)),
        mdfIso(DateTime(now.year, now.month, 0)),
      ),
      _Period.year => (mdfIso(DateTime(now.year)), mdfIso(now)),
    };
  }

  Future<void> _make(AppLocalizations l10n) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (since, until) = _range();
      final act = await ref
          .read(clientCardRepositoryProvider)
          .reconciliation(widget.customer, since: since, until: until);
      await ref.read(actSendProvider)(act, l10n);
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
    return AlertDialog(
      key: const ValueKey('clc:actDialog'),
      title: Text(l10n.actTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in _Period.values)
                ChoiceChip(
                  key: ValueKey('clc:actPeriod:${p.name}'),
                  label: Text(switch (p) {
                    _Period.all => l10n.actAllTime,
                    _Period.month => l10n.actThisMonth,
                    _Period.lastMonth => l10n.actLastMonth,
                    _Period.year => l10n.actThisYear,
                  }),
                  selected: _period == p,
                  onSelected: (_) => setState(() => _period = p),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton.icon(
          key: const ValueKey('clc:actMake'),
          onPressed: _busy ? null : () => _make(l10n),
          icon: _busy
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.share),
          label: Text(l10n.actMake),
        ),
      ],
    );
  }
}
